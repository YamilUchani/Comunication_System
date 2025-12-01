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
        const { channelName, title, description } = req.body;
        const userId = req.user.id;

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
                created_at: new Date().toISOString(),
                expires_at: new Date(Date.now() + expirationTime * 1000).toISOString()
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
 * Obtiene la lista de reuniones activas
 */
router.get('/active', authenticateUser, async (req, res) => {
    try {
        const { data: meetings, error } = await supabase
            .from('meetings')
            .select(`
        id,
        channel_name,
        title,
        description,
        creator_id,
        created_at,
        expires_at,
        profiles:creator_id (
          full_name,
          avatar_url
        )
      `)
            .eq('is_active', true)
            .gt('expires_at', new Date().toISOString())
            .order('created_at', { ascending: false });

        if (error) {
            console.error('Error obteniendo reuniones:', error);
            return res.status(500).json({
                error: {
                    message: 'Error al obtener las reuniones'
                }
            });
        }

        res.json({
            meetings: meetings.map(meeting => ({
                id: meeting.id,
                channelName: meeting.channel_name,
                title: meeting.title,
                description: meeting.description,
                creatorName: meeting.profiles?.full_name || 'Usuario',
                creatorAvatar: meeting.profiles?.avatar_url,
                createdAt: meeting.created_at,
                expiresAt: meeting.expires_at
            }))
        });
    } catch (error) {
        console.error('Error en /active:', error);
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

        // Verificar que el usuario sea el creador de la reunión
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

        if (meeting.creator_id !== userId) {
            return res.status(403).json({
                error: {
                    message: 'Solo el creador puede finalizar la reunión'
                }
            });
        }

        // Marcar la reunión como inactiva
        const { error: updateError } = await supabase
            .from('meetings')
            .update({ is_active: false, ended_at: new Date().toISOString() })
            .eq('id', meetingId);

        if (updateError) {
            console.error('Error finalizando reunión:', updateError);
            return res.status(500).json({
                error: {
                    message: 'Error al finalizar la reunión'
                }
            });
        }

        res.json({
            message: 'Reunión finalizada exitosamente'
        });
    } catch (error) {
        console.error('Error en /end:', error);
        res.status(500).json({
            error: {
                message: 'Error interno al finalizar la reunión'
            }
        });
    }
});

module.exports = router;
