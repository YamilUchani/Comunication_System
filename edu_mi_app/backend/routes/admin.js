const express = require('express');
const router = express.Router();
const { authenticateUser, requireAdmin } = require('../middleware/auth');
const supabase = require('../config/supabase');

/**
 * GET /api/admin/users
 * Obtiene lista de usuarios con filtros
 */
router.get('/users', authenticateUser, requireAdmin, async (req, res) => {
    try {
        const { role, group_name, search } = req.query;

        let query = supabase
            .from('profiles')
            .select('user_id, email, full_name, role, group_name, avatar_url, can_create_meetings, created_at');

        if (role) {
            query = query.eq('role', role);
        }

        if (group_name) {
            query = query.eq('group_name', group_name);
        }

        if (search) {
            query = query.or(`full_name.ilike.%${search}%,email.ilike.%${search}%`);
        }

        const { data: users, error } = await query.order('created_at', { ascending: false });

        if (error) {
            console.error('Error obteniendo usuarios:', error);
            return res.status(500).json({ error: { message: 'Error al obtener usuarios' } });
        }

        res.json({ users });
    } catch (error) {
        console.error('Error en /admin/users:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

/**
 * PUT /api/admin/users/:userId/role
 * Asigna rol y grupo a un usuario
 */
router.put('/users/:userId/role', authenticateUser, requireAdmin, async (req, res) => {
    try {
        const { userId } = req.params;
        const { role, group_name } = req.body;

        if (!role || !['student', 'teacher', 'administrator'].includes(role)) {
            return res.status(400).json({
                error: { message: 'Rol inválido. Debe ser: student, teacher o administrator' }
            });
        }

        const { data, error } = await supabase
            .from('profiles')
            .update({ role, group_name })
            .eq('user_id', userId)
            .select()
            .single();

        if (error) {
            console.error('Error actualizando rol:', error);
            return res.status(500).json({ error: { message: 'Error al actualizar rol' } });
        }

        res.json({
            message: 'Rol actualizado exitosamente',
            user: data
        });
    } catch (error) {
        console.error('Error en /admin/users/role:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

/**
 * GET /api/admin/groups
 * Obtiene lista de grupos
 */
router.get('/groups', authenticateUser, requireAdmin, async (req, res) => {
    try {
        const { data: groups, error } = await supabase
            .from('groups')
            .select('*')
            .eq('is_active', true)
            .order('created_at', { ascending: true });

        if (error) {
            console.error('Error obteniendo grupos:', error);
            return res.status(500).json({ error: { message: 'Error al obtener grupos' } });
        }

        res.json({ groups });
    } catch (error) {
        console.error('Error en /admin/groups:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

/**
 * POST /api/admin/groups
 * Crea un nuevo grupo
 */
router.post('/groups', authenticateUser, requireAdmin, async (req, res) => {
    try {
        const { name, display_name, description, color, icon } = req.body;

        if (!name || !display_name) {
            return res.status(400).json({
                error: { message: 'name y display_name son requeridos' }
            });
        }

        const { data: group, error } = await supabase
            .from('groups')
            .insert({
                name,
                display_name,
                description,
                color: color || '#3B82F6',
                icon: icon || '📚',
                created_by: req.user.id
            })
            .select()
            .single();

        if (error) {
            if (error.message.includes('Maximum 5 groups')) {
                return res.status(400).json({
                    error: { message: 'Máximo 5 grupos permitidos' }
                });
            }
            console.error('Error creando grupo:', error);
            return res.status(500).json({ error: { message: 'Error al crear grupo' } });
        }

        res.status(201).json({ group });
    } catch (error) {
        console.error('Error en /admin/groups POST:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

/**
 * GET /api/admin/stats
 * Obtiene estadísticas generales del sistema
 */
router.get('/stats', authenticateUser, requireAdmin, async (req, res) => {
    try {
        // Contar usuarios por rol
        const { data: userStats } = await supabase
            .rpc('count_users_by_role');

        // Contar reuniones activas
        const { count: activeMeetings } = await supabase
            .from('meetings')
            .select('*', { count: 'exact', head: true })
            .eq('is_active', true);

        // Asistencia del último mes
        const lastMonth = new Date();
        lastMonth.setMonth(lastMonth.getMonth() - 1);

        const { count: attendanceCount } = await supabase
            .from('attendance')
            .select('*', { count: 'exact', head: true })
            .gte('meeting_date', lastMonth.toISOString().split('T')[0]);

        res.json({
            stats: {
                users: userStats || [],
                active_meetings: activeMeetings || 0,
                attendance_last_month: attendanceCount || 0
            }
        });
    } catch (error) {
        console.error('Error en /admin/stats:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

module.exports = router;
