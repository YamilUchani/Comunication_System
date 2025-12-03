const express = require('express');
const router = express.Router();
const { authenticateUser, canCreateMeeting } = require('../middleware/auth');
const { generateRtcToken, isValidChannelName } = require('../services/agoraToken');
const supabase = require('../config/supabase');

/**
 * POST /api/meetings/create
 * Crea una nueva reunión y genera el token de Agora
 */
router.post('/create', authenticateUser, canCreateMeeting, async (req, res) => {
    try {
        const { channelName, title, description, allowed_groups, allowed_users } = req.body;
        const userId = req.user.id;

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
                    return res.status(403).json({
                        error: {
                            message: 'Los teachers solo pueden crear reuniones para su propio grupo'
                        }
                    });
                }
            } else {
                // Si no especifica grupos, asignar automáticamente su grupo
                req.body.allowed_groups = [profile.group_name];
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
            .select('id')
            .eq('channel_name', channelName)
            .eq('is_active', true)
            .single();

        if (existingMeeting) {
            return res.status(409).json({
                error: {
                    message: 'Ya existe una reunión activa con ese nombre de canal'
                }
            });
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
                allowed_users: allowed_users || []
            })
            .select()
            .single();

        if (meetingError) {
            console.error('Error creando reunión:', meetingError);
            return res.status(500).json({
                error: {
                    message: 'Error al crear la reunión en la base de datos'
                }
            });
        }

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
        console.error('Error en /create:', error);
        res.status(500).json({
            error: {
                message: 'Error interno al crear la reunión'
            }
        });
    }
});

/**
 * POST /api/meetings/join
 * Genera un token para unirse a una reunión existente
 */
router.post('/join', authenticateUser, async (req, res) => {
    try {
        const { channelName } = req.body;
        const userId = req.user.id;

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
            // Marcar la reunión como inactiva
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
        console.error('Error en /join:', error);
        res.status(500).json({
            error: {
                message: 'Error interno al unirse a la reunión'
            }
        });
    }
});


/**
 * GET /api/meetings/active
 * Obtiene la lista de reuniones activas filtradas por rol y grupo del usuario
 */
router.get('/active', authenticateUser, async (req, res) => {
    try {
        const userId = req.user.id;
        console.log(`📥 GET /api/meetings/active - User: ${userId}`);

        // Obtener perfil del usuario para determinar rol y grupo
        const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('role, group_name')
            .eq('user_id', userId)
            .single();

        if (profileError || !profile) {
            console.error('❌ Error obteniendo perfil:', profileError);
            return res.status(500).json({
                error: { message: 'Error al obtener perfil de usuario' }
            });
        }

        console.log(`👤 User role: ${profile.role}, group: ${profile.group_name}`);

        // Query base de reuniones activas
        let query = supabase
            .from('meetings')
            .select('id, channel_name, title, description, creator_id, created_at, expires_at, allowed_groups')
            .eq('is_active', true)
            .gt('expires_at', new Date().toISOString())
            .order('created_at', { ascending: false });

        const { data: allMeetings, error } = await query;

        if (error) {
            console.error('❌ Error obteniendo reuniones:', error);
            return res.status(500).json({
                error: {
                    message: 'Error al obtener las reuniones',
                    details: error.message
                }
            });
        }

        // Filtrar reuniones según el rol
        let filteredMeetings = allMeetings || [];

        if (profile.role === 'administrator') {
            // Admin ve TODAS las reuniones
            console.log('🔓 Admin: mostrando todas las reuniones');
        } else if (profile.role === 'teacher') {
            // Teacher ve reuniones de su grupo o las que creó
            filteredMeetings = filteredMeetings.filter(meeting => {
                const isCreator = meeting.creator_id === userId;
                // Verificar si el grupo del teacher está en los grupos permitidos
                // IMPORTANTE: Esto permite ver reuniones creadas por Admin para este grupo
                const isInAllowedGroups = meeting.allowed_groups &&
                    meeting.allowed_groups.includes(profile.group_name);

                // Si no hay restricciones, todos pueden verla (opcional, depende de reglas de negocio)
                const hasNoRestrictions = !meeting.allowed_groups || meeting.allowed_groups.length === 0;

                return isCreator || isInAllowedGroups || hasNoRestrictions;
            });
            console.log(`👨‍🏫 Teacher: ${filteredMeetings.length} reuniones visibles (Propio grupo o Creador)`);
        } else if (profile.role === 'student') {
            // Student solo ve reuniones de su grupo
            filteredMeetings = filteredMeetings.filter(meeting => {
                const isInAllowedGroups = meeting.allowed_groups &&
                    meeting.allowed_groups.includes(profile.group_name);
                const hasNoRestrictions = !meeting.allowed_groups || meeting.allowed_groups.length === 0;

                return isInAllowedGroups || hasNoRestrictions;
            });
            console.log(`👨‍🎓 Student: ${filteredMeetings.length} reuniones de su grupo`);
        }

        // Obtener nombres de los creadores
        const creatorIds = [...new Set(filteredMeetings.map(m => m.creator_id))];
        const { data: creators } = await supabase
            .from('profiles')
            .select('user_id, full_name')
            .in('user_id', creatorIds);

        const creatorMap = {};
        if (creators) {
            creators.forEach(c => {
                creatorMap[c.user_id] = c.full_name;
            });
        }

        console.log(`📊 Returning ${filteredMeetings.length} meetings`);

        res.json({
            meetings: filteredMeetings.map(meeting => ({
                id: meeting.id,
                channelName: meeting.channel_name,
                title: meeting.title,
                description: meeting.description,
                creatorId: meeting.creator_id,
                creatorName: creatorMap[meeting.creator_id] || 'Desconocido',
                createdAt: meeting.created_at,
                expiresAt: meeting.expires_at
            }))
        });
    } catch (error) {
        console.error('💥 Error en /active:', error);
        res.status(500).json({
            error: {
                message: 'Error interno al obtener las reuniones'
            }
        });
    }
});

/**
 * POST /api/meetings/:meetingId/end
 * Finaliza una reunión
 */
router.post('/:meetingId/end', authenticateUser, async (req, res) => {
    try {
        const { meetingId } = req.params;
        const userId = req.user.id;

        console.log(`📥 POST /api/meetings/${meetingId}/end - User: ${userId}`);

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
            return res.status(403).json({
                error: {
                    message: 'Solo el creador o un administrador puede finalizar la reunión'
                }
            });
        }

        // Marcar la reunión como inactiva
        const { error: updateError } = await supabase
            .from('meetings')
            .update({ is_active: false, ended_at: new Date().toISOString() })
            .eq('id', meetingId);

        if (updateError) {
            console.error('❌ Error finalizando reunión:', updateError);
            return res.status(500).json({
                error: {
                    message: 'Error al finalizar la reunión'
                }
            });
        }

        console.log(`✅ Reunión ${meetingId} finalizada por ${isAdmin ? 'admin' : 'creador'}`);

        res.json({
            message: 'Reunión finalizada exitosamente'
        });
    } catch (error) {
        console.error('💥 Error en /end:', error);
        res.status(500).json({
            error: {
                message: 'Error interno al finalizar la reunión'
            }
        });
    }
});

module.exports = router;
