import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import express from 'express';
import cors from 'cors';
import { createClient } from '@supabase/supabase-js';
import { RtcTokenBuilder, RtcRole } from 'agora-access-token';
import dotenv from 'dotenv';

// Cargar variables de entorno desde .env
dotenv.config();

// Inicializar Firebase Admin
admin.initializeApp();

// Configurar Supabase usando variables de entorno
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error('SUPABASE_URL y SUPABASE_SERVICE_KEY son requeridas en el archivo .env');
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Configurar Agora usando variables de entorno
const agoraAppId = process.env.AGORA_APP_ID;
const agoraAppCertificate = process.env.AGORA_APP_CERTIFICATE;

if (!agoraAppId || !agoraAppCertificate) {
    throw new Error('AGORA_APP_ID y AGORA_APP_CERTIFICATE son requeridas en el archivo .env');
}

// Crear app Express
const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// ============================================
// MIDDLEWARE DE AUTENTICACIÓN
// ============================================

async function authenticateUser(req, res, next) {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                error: { message: 'Token de autenticación no proporcionado' }
            });
        }

        const token = authHeader.replace('Bearer ', '');

        // Verificar token con Firebase Admin
        const decodedToken = await admin.auth().verifyIdToken(token);

        // Obtener perfil del usuario desde Supabase
        const { data: profile, error } = await supabase
            .from('profiles')
            .select('*')
            .eq('user_id', decodedToken.uid)
            .single();

        if (error && error.code !== 'PGRST116') {
            console.error('Error obteniendo perfil:', error);
        }

        req.user = {
            uid: decodedToken.uid,
            email: decodedToken.email,
            profile: profile || null
        };

        next();
    } catch (error) {
        console.error('Error en autenticación:', error);
        return res.status(401).json({
            error: { message: 'Token inválido o expirado' }
        });
    }
}

async function canCreateMeeting(req, res, next) {
    try {
        const userId = req.user.uid;

        const { data: profile } = await supabase
            .from('profiles')
            .select('can_create_meetings, meeting_limit')
            .eq('user_id', userId)
            .single();

        if (profile && profile.can_create_meetings === false) {
            return res.status(403).json({
                error: { message: 'No tienes permisos para crear reuniones' }
            });
        }

        if (profile && profile.meeting_limit) {
            const { count } = await supabase
                .from('meetings')
                .select('*', { count: 'exact', head: true })
                .eq('creator_id', userId)
                .eq('is_active', true);

            if (count >= profile.meeting_limit) {
                return res.status(403).json({
                    error: {
                        message: `Has alcanzado el límite de reuniones activas (${profile.meeting_limit})`
                    }
                });
            }
        }

        next();
    } catch (error) {
        console.error('Error verificando permisos:', error);
        res.status(500).json({
            error: { message: 'Error al verificar permisos' }
        });
    }
}

// ============================================
// SERVICIOS
// ============================================

function generateAgoraToken(channelName, uid = 0, role = 'publisher', expirationTime = 3600) {
    const agoraRole = role === 'publisher' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTime;

    return RtcTokenBuilder.buildTokenWithUid(
        agoraAppId,
        agoraAppCertificate,
        channelName,
        uid,
        agoraRole,
        privilegeExpiredTs
    );
}

function isValidChannelName(channelName) {
    const channelNameRegex = /^[a-zA-Z0-9_-]{1,64}$/;
    return channelNameRegex.test(channelName);
}

// ============================================
// RUTAS DE API
// ============================================

app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        service: 'Firebase Cloud Functions',
        version: '2.0.0 (dotenv)'
    });
});

app.post('/meetings/create', authenticateUser, canCreateMeeting, async (req, res) => {
    try {
        const { channelName, title, description } = req.body;
        const userId = req.user.uid;

        if (!channelName || !isValidChannelName(channelName)) {
            return res.status(400).json({
                error: {
                    message: 'Nombre de canal inválido. Debe tener entre 1-64 caracteres (letras, números, - y _)'
                }
            });
        }

        const { data: existingMeeting } = await supabase
            .from('meetings')
            .select('id')
            .eq('channel_name', channelName)
            .eq('is_active', true)
            .single();

        if (existingMeeting) {
            return res.status(409).json({
                error: { message: 'Ya existe una reunión activa con ese nombre de canal' }
            });
        }

        const expirationTime = 3600;
        const token = generateAgoraToken(channelName, 0, 'publisher', expirationTime);

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
                error: { message: 'Error al crear la reunión' }
            });
        }

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
            error: { message: 'Error interno al crear la reunión' }
        });
    }
});

app.post('/meetings/join', authenticateUser, async (req, res) => {
    try {
        const { channelName } = req.body;
        const userId = req.user.uid;

        if (!channelName || !isValidChannelName(channelName)) {
            return res.status(400).json({
                error: { message: 'Nombre de canal inválido' }
            });
        }

        const { data: meeting, error: meetingError } = await supabase
            .from('meetings')
            .select('*')
            .eq('channel_name', channelName)
            .eq('is_active', true)
            .single();

        if (meetingError || !meeting) {
            return res.status(404).json({
                error: { message: 'Reunión no encontrada o ya finalizada' }
            });
        }

        const now = new Date();
        const expiresAt = new Date(meeting.expires_at);

        if (now > expiresAt) {
            await supabase
                .from('meetings')
                .update({ is_active: false })
                .eq('id', meeting.id);

            return res.status(410).json({
                error: { message: 'La reunión ha expirado' }
            });
        }

        const remainingTime = Math.floor((expiresAt - now) / 1000);
        const token = generateAgoraToken(channelName, 0, 'publisher', remainingTime);

        await supabase
            .from('meeting_participants')
            .upsert({
                meeting_id: meeting.id,
                user_id: userId,
                joined_at: new Date().toISOString()
            }, {
                onConflict: 'meeting_id,user_id'
            });

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
            error: { message: 'Error interno al unirse a la reunión' }
        });
    }
});

app.get('/meetings/active', authenticateUser, async (req, res) => {
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
                error: { message: 'Error al obtener las reuniones' }
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
            error: { message: 'Error interno' }
        });
    }
});

app.post('/meetings/:meetingId/end', authenticateUser, async (req, res) => {
    try {
        const { meetingId } = req.params;
        const userId = req.user.uid;

        const { data: meeting, error: meetingError } = await supabase
            .from('meetings')
            .select('*')
            .eq('id', meetingId)
            .single();

        if (meetingError || !meeting) {
            return res.status(404).json({
                error: { message: 'Reunión no encontrada' }
            });
        }

        if (meeting.creator_id !== userId) {
            return res.status(403).json({
                error: { message: 'Solo el creador puede finalizar la reunión' }
            });
        }

        const { error: updateError } = await supabase
            .from('meetings')
            .update({ is_active: false, ended_at: new Date().toISOString() })
            .eq('id', meetingId);

        if (updateError) {
            console.error('Error finalizando reunión:', updateError);
            return res.status(500).json({
                error: { message: 'Error al finalizar la reunión' }
            });
        }

        res.json({ message: 'Reunión finalizada exitosamente' });
    } catch (error) {
        console.error('Error en /end:', error);
        res.status(500).json({
            error: { message: 'Error interno' }
        });
    }
});

// ============================================
// CLOUD FUNCTION
// ============================================

export const api = functions.https.onRequest(app);

// ============================================
// TRIGGERS
// ============================================

export const syncUserToSupabase = functions.auth.user().onCreate(async (user) => {
    try {
        const { error } = await supabase
            .from('profiles')
            .insert({
                user_id: user.uid,
                email: user.email,
                full_name: user.displayName || '',
                avatar_url: user.photoURL || '',
                can_create_meetings: true,
                created_at: new Date().toISOString()
            });

        if (error && error.code !== '23505') {
            console.error('Error creando perfil en Supabase:', error);
        } else {
            console.log(`Perfil creado para usuario ${user.uid}`);
        }
    } catch (error) {
        console.error('Error en syncUserToSupabase:', error);
    }
});

export const cleanupUserFromSupabase = functions.auth.user().onDelete(async (user) => {
    try {
        await supabase
            .from('profiles')
            .delete()
            .eq('user_id', user.uid);

        console.log(`Perfil eliminado para usuario ${user.uid}`);
    } catch (error) {
        console.error('Error en cleanupUserFromSupabase:', error);
    }
});
