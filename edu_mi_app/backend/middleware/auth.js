const supabase = require('../config/supabase');

/**
 * Middleware para autenticar usuarios con Supabase
 */
async function authenticateUser(req, res, next) {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                error: { message: 'Token de autenticación no proporcionado' }
            });
        }

        const token = authHeader.replace('Bearer ', '');

        // Verificar token con Supabase
        const { data: { user }, error } = await supabase.auth.getUser(token);

        if (error || !user) {
            return res.status(401).json({
                error: { message: 'Token inválido o expirado' }
            });
        }

        // Obtener perfil completo con rol y grupo
        const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('*')
            .eq('user_id', user.id)
            .single();

        if (profileError) {
            console.error('Error obteniendo perfil:', profileError);
        }

        // Adjuntar info del usuario a la petición
        req.user = {
            id: user.id,
            email: user.email,
            role: profile?.role || 'student',
            group_name: profile?.group_name,
            profile: profile
        };

        next();
    } catch (error) {
        console.error('Error en autenticación:', error);
        return res.status(401).json({
            error: { message: 'Error en la autenticación' }
        });
    }
}

/**
 * Middleware para verificar que el usuario puede crear reuniones
 */
async function canCreateMeeting(req, res, next) {
    try {
        const { role, profile } = req.user;

        // Solo teachers y administrators pueden crear
        if (role !== 'teacher' && role !== 'administrator') {
            return res.status(403).json({
                error: { message: 'Solo maestros y administradores pueden crear reuniones' }
            });
        }

        // Verificar permiso específico
        if (profile?.can_create_meetings === false) {
            return res.status(403).json({
                error: { message: 'No tienes permisos para crear reuniones' }
            });
        }

        // Verificar límite de reuniones (si aplica)
        if (profile?.meeting_limit) {
            const { count } = await supabase
                .from('meetings')
                .select('*', { count: 'exact', head: true })
                .eq('creator_id', req.user.id)
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

/**
 * Middleware para verificar rol de administrador
 */
function requireAdmin(req, res, next) {
    if (req.user.role !== 'administrator') {
        return res.status(403).json({
            error: { message: 'Acceso denegado. Se requiere rol de administrador' }
        });
    }
    next();
}

/**
 * Middleware para verificar rol de teacher o admin
 */
function requireTeacherOrAdmin(req, res, next) {
    if (req.user.role !== 'teacher' && req.user.role !== 'administrator') {
        return res.status(403).json({
            error: { message: 'Acceso denegado. Se requiere rol de maestro o administrador' }
        });
    }
    next();
}

module.exports = {
    authenticateUser,
    canCreateMeeting,
    requireAdmin,
    requireTeacherOrAdmin
};
