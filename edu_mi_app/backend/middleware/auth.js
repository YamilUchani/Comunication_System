const supabase = require('../config/supabase');

/**
 * Middleware de autenticación
 * Valida el token JWT de Supabase y adjunta la información del usuario a req.user
 */
async function authenticateUser(req, res, next) {
    try {
        // Obtener el token del header Authorization
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                error: {
                    message: 'Token de autenticación no proporcionado'
                }
            });
        }

        const token = authHeader.replace('Bearer ', '');

        // Verificar el token con Supabase
        const { data: { user }, error } = await supabase.auth.getUser(token);

        if (error || !user) {
            return res.status(401).json({
                error: {
                    message: 'Token inválido o expirado'
                }
            });
        }

        // Obtener el perfil del usuario desde la base de datos
        const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('*')
            .eq('user_id', user.id)
            .single();

        if (profileError) {
            console.error('Error obteniendo perfil:', profileError);
            return res.status(500).json({
                error: {
                    message: 'Error al obtener información del usuario'
                }
            });
        }

        // Adjuntar información del usuario a la petición
        req.user = {
            id: user.id,
            email: user.email,
            profile: profile
        };

        next();
    } catch (error) {
        console.error('Error en autenticación:', error);
        res.status(500).json({
            error: {
                message: 'Error interno en el proceso de autenticación'
            }
        });
    }
}

/**
 * Middleware para verificar si el usuario puede crear reuniones
 */
async function canCreateMeeting(req, res, next) {
    try {
        const userId = req.user.id;

        // Aquí puedes agregar lógica adicional de permisos
        // Por ejemplo, verificar un campo en el perfil del usuario
        const { data: profile } = await supabase
            .from('profiles')
            .select('can_create_meetings, meeting_limit')
            .eq('user_id', userId)
            .single();

        // Si tienes un campo específico de permisos
        if (profile && profile.can_create_meetings === false) {
            return res.status(403).json({
                error: {
                    message: 'No tienes permisos para crear reuniones'
                }
            });
        }

        // Verificar si hay un límite de reuniones activas
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
            error: {
                message: 'Error al verificar permisos del usuario'
            }
        });
    }
}

module.exports = {
    authenticateUser,
    canCreateMeeting
};
