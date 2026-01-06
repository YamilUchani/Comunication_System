const express = require('express');
const router = express.Router();
const { authenticateUser, canCreateMeeting } = require('../middleware/auth');
const { generateRtcToken, isValidChannelName } = require('../services/agoraToken');
const supabase = require('../config/supabase');
const logger = require('../utils/logger');

/**
 * POST /api/meetings/create
 * Crea una nueva reunión y genera el token de Agora
 */
router.post('/create', authenticateUser, canCreateMeeting, async (req, res, next) => {
    try {
        let { channelName, title, description, allowed_groups, allowed_users } = req.body;
        const userId = req.user.id;

        logger.info(`📝 Creando reunión - Usuario: ${userId}, Channel: ${channelName}`);

        // Obtener perfil del usuario para validar grupo
        const { data: profile } = await supabase
            .from('profiles')
            .select('role, group_name')
            .eq('user_id', userId)
            .single();

        // Si es teacher, validar que solo cree reuniones para su grupo
        if (profile?.role === 'teacher') {
            if (allowed_groups && allowed_groups.length > 0) {
                // Verificar que solo incluya su propio grupo
                const hasOtherGroups = allowed_groups.some(g => g !== profile.group_name);
                if (hasOtherGroups) {
                    logger.warn(`⛔ Teacher ${userId} intentó crear reunión para otros grupos: ${allowed_groups}`);
                    return res.status(403).json({
                        error: {
                            message: 'Los teachers solo pueden crear reuniones para su propio grupo'
                        }
                    });
                }
            } else {
                // Si no especifica grupos, asignar automáticamente su grupo
                allowed_groups = [profile.group_name];
            }
        }

        // Validar nombre del canal
        if (!channelName || !isValidChannelName(channelName)) {
            return res.status(400).json({
                error: {
                    message: 'Nombre de canal inválido. Debe tener entre 1-64 caracteres (letras, números, - y _)'
                }
            });
        }

        // Verificar si ya existe una reunión con ese nombre de canal
        const { data: existingMeeting } = await supabase
            .from('meetings')
            .select('id, expires_at')
            .eq('channel_name', channelName)
            .eq('is_active', true)
            .single();

        if (existingMeeting) {
            // Verificar si expiró (aunque siga marcada como activa)
            const now = new Date();
            const expiresAt = new Date(existingMeeting.expires_at);

            if (now > expiresAt) {
                logger.info(`♻️ Cerrando reunión expirada para permitir una nueva: ${existingMeeting.id}`);
                await supabase
                    .from('meetings')
                    .update({ is_active: false })
                    .eq('id', existingMeeting.id);
            } else {
                // Si la reunión es vigente, verificar si el usuario tiene permiso para verla/reutilizarla
                const { data: fullMeeting } = await supabase
                    .from('meetings')
                    .select('*')
                    .eq('id', existingMeeting.id)
                    .single();

                const isCreator = fullMeeting.creator_id === userId;
                const isInAllowedGroups = profile.group_name && fullMeeting.allowed_groups && fullMeeting.allowed_groups.includes(profile.group_name);
                const isInvited = fullMeeting.allowed_users && fullMeeting.allowed_users.includes(userId);
                const isAdmin = profile.role === 'administrator';

                if (isCreator || isInAllowedGroups || isInvited || isAdmin) {
                    logger.info(`✅ Reutilizando reunión existente para el usuario: ${fullMeeting.id}`);
                    // Generar un nuevo token vigente
                    const remainingTime = Math.floor((expiresAt - now) / 1000);
                    const token = generateRtcToken(channelName, 0, 'publisher', remainingTime);

                    return res.status(200).json({
                        meeting: {
                            id: fullMeeting.id,
                            channelName: fullMeeting.channel_name,
                            title: fullMeeting.title,
                            description: fullMeeting.description,
                            token: token,
                            expiresAt: fullMeeting.expires_at,
                            joinUrl: `stemforall://meeting?channel=${encodeURIComponent(channelName)}&token=${encodeURIComponent(token)}`
                        }
                    });
                }

                logger.warn(`⚠️ Intento de duplicar canal ajeno activo y vigente: ${channelName}`);
                return res.status(409).json({
                    error: {
                        message: 'Ya existe una reunión activa con ese nombre de canal protegida'
                    }
                });
            }
        }

        // Generar token de Agora
        const expirationTime = parseInt(process.env.TOKEN_EXPIRATION_TIME) || 3600;
        const token = generateRtcToken(channelName, 0, 'publisher', expirationTime);

        // Guardar la reunión en la base de datos
        const { data: meeting, error: meetingError } = await supabase
            .from('meetings')
            .insert({
                channel_name: channelName,
                title: title || channelName,
                description: description || '',
                creator_id: userId,
                is_active: true,
                allowed_groups: allowed_groups || [],
                allowed_users: allowed_users || [],
                expires_at: new Date(Date.now() + expirationTime * 1000).toISOString()
            })
            .select()
            .single();

        if (meetingError) {
            logger.error('Error insertando reunión en DB', meetingError);
            return res.status(500).json({
                error: {
                    message: 'Error al crear la reunión en la base de datos'
                }
            });
        }

        logger.info(`✅ Reunión creada: ${meeting.id}`);

        // Responder con la información de la reunión y el token
        res.status(201).json({
            meeting: {
                id: meeting.id,
                channelName: meeting.channel_name,
                title: meeting.title,
                description: meeting.description,
                token: token,
                expiresAt: meeting.expires_at,
                joinUrl: `stemforall://meeting?channel=${encodeURIComponent(channelName)}&token=${encodeURIComponent(token)}`
            }
        });
    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/meetings/join
 * Genera un token para unirse a una reunión existente
 */
router.post('/join', authenticateUser, async (req, res, next) => {
    try {
        const { channelName } = req.body;
        const userId = req.user.id;

        logger.info(`👋 Usuario ${userId} intentando unirse a: ${channelName}`);

        // Validar nombre del canal
        if (!channelName || !isValidChannelName(channelName)) {
            return res.status(400).json({
                error: {
                    message: 'Nombre de canal inválido'
                }
            });
        }

        // Verificar si la reunión existe y está activa
        const { data: meeting, error: meetingError } = await supabase
            .from('meetings')
            .select('*')
            .eq('channel_name', channelName)
            .eq('is_active', true)
            .single();

        if (meetingError || !meeting) {
            logger.warn(`Reunión no encontrada/activa para join: ${channelName}`);
            return res.status(404).json({
                error: {
                    message: 'Reunión no encontrada o ya finalizada'
                }
            });
        }

        // Verificar si la reunión no ha expirado
        const now = new Date();
        const expiresAt = new Date(meeting.expires_at);

        if (now > expiresAt) {
            logger.info(`Reunión expirada detectada en join: ${meeting.id}`);
            // Marcar la reunión como inactiva (Soft Close)
            await supabase
                .from('meetings')
                .update({ is_active: false })
                .eq('id', meeting.id);

            return res.status(410).json({
                error: {
                    message: 'La reunión ha expirado'
                }
            });
        }

        // Generar token de Agora
        const remainingTime = Math.floor((expiresAt - now) / 1000);
        const token = generateRtcToken(channelName, 0, 'publisher', remainingTime);

        // Registrar la participación del usuario
        await supabase
            .from('meeting_participants')
            .upsert({
                meeting_id: meeting.id,
                user_id: userId,
                joined_at: new Date().toISOString()
            }, {
                onConflict: 'meeting_id,user_id'
            });

        // Responder con el token
        res.json({
            meeting: {
                id: meeting.id,
                channelName: meeting.channel_name,
                title: meeting.title,
                description: meeting.description,
                token: token,
                expiresAt: meeting.expires_at
            }
        });
    } catch (error) {
        console.error('Error FATAL en /join:', error);
        res.status(500).json({
            error: {
                message: 'Error interno al unirse a la reunión (RENDER)',
                originalError: error.message,
                code: error.code,
                stack: error.stack
            }
        });
    }
});


/**
 * GET /api/meetings/active
 * Obtiene la lista de reuniones activas filtradas por rol y grupo del usuario
 */
router.get('/active', authenticateUser, async (req, res, next) => {
    try {
        const userId = req.user.id;
        // logger.debug(`Listando reuniones para: ${userId}`); // Debug levels can be noisy

        // Obtener perfil del usuario para determinar rol y grupo
        const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('role, group_name')
            .eq('user_id', userId)
            .single();

        if (profileError || !profile) {
            logger.error(`Error perfil usuario ${userId}`, profileError);
            return res.status(500).json({
                error: { message: 'Error al obtener perfil de usuario' }
            });
        }

        // Query base de reuniones activas (ahora sin filtro de tiempo global para que el dashboard vea zombies)
        let query = supabase
            .from('meetings')
            .select('*, creator:profiles!creator_id(role, full_name)')
            .eq('is_active', true)
            .order('created_at', { ascending: false });

        const { data: allMeetings, error } = await query;

        if (error) {
            logger.error('Error fetching active meetings', error);
            return res.status(500).json({
                error: {
                    message: 'Error al obtener las reuniones',
                    details: error.message
                }
            });
        }

        // Filtrar reuniones según el rol
        let filteredMeetings = allMeetings || [];
        const now = new Date();

        if (profile.role === 'administrator') {
            // Admin ve TODAS las reuniones activas
        } else if (profile.role === 'teacher') {
            // Teacher ve reuniones de su grupo o las que creó (incluyendo zombies activos)
            filteredMeetings = filteredMeetings.filter(meeting => {
                const isCreator = meeting.creator_id === userId;
                const teacherGroup = (profile.group_name || '').trim();

                // 1. Siempre ve sus propias reuniones
                if (isCreator) return true;

                // 2. Si no es el creador, verificar si el grupo coincide
                const isInAllowedGroups = teacherGroup && meeting.allowed_groups &&
                    meeting.allowed_groups.some(g => (g || '').trim() === teacherGroup);

                // 3. Ver reuniones de Admins si no tienen restricciones o coinciden con el grupo
                const creatorRole = meeting.creator?.role;
                const isFromAdmin = creatorRole === 'administrator';

                if (isFromAdmin) {
                    const hasNoGroupRestrictions = (!meeting.allowed_groups || meeting.allowed_groups.length === 0);
                    return isInAllowedGroups || hasNoGroupRestrictions;
                }

                // 4. Ver reuniones de otros maestros SOLO si pertenecen al mismo grupo
                return isInAllowedGroups;
            });
        } else if (profile.role === 'student') {
            // Student ve reuniones de su grupo O donde está invitado específicamente
            // IMPORTANTE: Student NO ve zombies (reuniones expiradas)
            filteredMeetings = filteredMeetings.filter(meeting => {
                const expiresAt = new Date(meeting.expires_at);
                if (now > expiresAt) return false;

                const studentGroup = (profile.group_name || '').trim();

                // 1. Invitación individual específica (Prioridad)
                const isPersonallyInvited = meeting.allowed_users &&
                    meeting.allowed_users.includes(userId);

                if (isPersonallyInvited) return true;

                // 2. Si la reunión es privada para ciertos usuarios y NO está invitado, ocultar
                if (meeting.allowed_users && meeting.allowed_users.length > 0) return false;

                // 3. Reunión de su grupo
                const isInAllowedGroups = studentGroup && meeting.allowed_groups &&
                    meeting.allowed_groups.some(g => (g || '').trim() === studentGroup);

                // 4. Sin restricciones
                const hasNoRestrictions = (!meeting.allowed_groups || meeting.allowed_groups.length === 0);

                return isInAllowedGroups || hasNoRestrictions;
            });
        }

        // No necesitamos fetch adicional para nombres/roles ya que los trajimos en el query principal
        const finalMeetings = filteredMeetings.map(meeting => ({
            id: meeting.id,
            channelName: meeting.channel_name,
            title: meeting.title,
            description: meeting.description,
            creatorId: meeting.creator_id,
            creatorName: meeting.creator?.full_name || 'Desconocido',
            creatorRole: meeting.creator?.role || 'student',
            createdAt: meeting.created_at,
            expiresAt: meeting.expires_at,
            allowedUsers: meeting.allowed_users || [],
            allowedGroups: meeting.allowed_groups || [],
            isExpired: new Date() > new Date(meeting.expires_at)
        }));

        res.json({
            meetings: finalMeetings
        });
    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/meetings/:meetingId/end
 * Finaliza una reunión (SOFT DELETE)
 */
router.post('/:meetingId/end', authenticateUser, async (req, res, next) => {
    try {
        const { meetingId } = req.params;
        const userId = req.user.id;

        logger.info(`🛑 Solicitud de fin de reunión: ${meetingId} por ${userId}`);

        // Obtener información del usuario y la reunión
        const { data: userProfile } = await supabase
            .from('profiles')
            .select('role')
            .eq('user_id', userId)
            .single();

        const { data: meeting, error: meetingError } = await supabase
            .from('meetings')
            .select('*')
            .eq('id', meetingId)
            .single();

        if (meetingError || !meeting) {
            return res.status(404).json({
                error: {
                    message: 'Reunión no encontrada'
                }
            });
        }

        // Permitir finalizar si es el creador O es administrador
        const isCreator = meeting.creator_id === userId;
        const isAdmin = userProfile?.role === 'administrator';

        if (!isCreator && !isAdmin) {
            logger.warn(`⛔ Acceso denegado ending meeting ${meetingId}. User: ${userId}`);
            return res.status(403).json({
                error: {
                    message: 'Solo el creador o un administrador puede finalizar la reunión'
                }
            });
        }

        // SOFT DELETE: Marcar como inactiva y setear fecha de fin
        const { error: updateError } = await supabase
            .from('meetings')
            .update({
                is_active: false,
                ended_at: new Date().toISOString() // Asegurarse de tener esta columna o quitar si no existe en la migración
            })
            .eq('id', meetingId);

        // NOTA: Si `ended_at` no existe en tu esquema original, asegúrate de agregarlo o usa solo is_active: false.
        // Dado que no vi el schema completo de 'meetings' (solo los policies), asumo standard.
        // Si falla, revertiremos a solo is_active.

        if (updateError) {
            // Si el error es por columna inexistente, intentar solo soft-delete basico
            logger.error('Error soft-deleting meeting', updateError);

            if (updateError.code === '42703') { // Undefined column
                logger.info('Columna ended_at no existe, actualizando solo is_active');
                await supabase.from('meetings').update({ is_active: false }).eq('id', meetingId);
            } else {
                return res.status(500).json({
                    error: {
                        message: 'Error al finalizar la reunión'
                    }
                });
            }
        }

        logger.info(`✅ Reunión ${meetingId} finalizada correctamente.`);

        res.json({
            message: 'Reunión finalizada exitosamente'
        });
    } catch (error) {
        next(error);
    }
});

module.exports = router;
