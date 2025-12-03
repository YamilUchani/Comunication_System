const express = require('express');
const router = express.Router();
const { authenticateUser, requireAdmin } = require('../middleware/auth');
const supabase = require('../config/supabase');

/**
 * GET /api/admin/users
 * Obtiene lista de usuarios
 */
router.get('/users', authenticateUser, requireAdmin, async (req, res) => {
    try {
        console.log('📥 GET /api/admin/users - Fetching all users from profiles table');

        // Consultar con las columnas que REALMENTE existen en profiles
        const { data: users, error } = await supabase
            .from('profiles')
            .select('user_id, id, full_name, email, age, group_name, role, avatar_url, can_create_meetings, created_at, is_verified')
            .order('created_at', { ascending: false });

        console.log('📊 Query result:', {
            count: users?.length,
            hasError: !!error,
            errorMessage: error?.message
        });

        if (error) {
            console.error('❌ Error obteniendo usuarios:', error);
            return res.status(500).json({ error: { message: 'Error al obtener usuarios', details: error.message } });
        }

        if (!users || users.length === 0) {
            console.warn('⚠️ No se encontraron usuarios en la tabla profiles');
        } else {
            console.log(`✅ ${users.length} usuarios encontrados`);
        }

        res.json({ users: users || [] });
    } catch (error) {
        console.error('💥 Error en /admin/users:', error);
        res.status(500).json({ error: { message: 'Error interno', details: error.message } });
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
 * GET /api/admin/groups/with-members
 * Obtiene grupos con sus integrantes
 */
router.get('/groups/with-members', authenticateUser, requireAdmin, async (req, res) => {
    try {
        console.log('📥 GET /api/admin/groups/with-members');

        // 1. Obtener todos los grupos activos
        const { data: groups, error: groupsError } = await supabase
            .from('groups')
            .select('*')
            .eq('is_active', true)
            .order('created_at', { ascending: true });

        if (groupsError) {
            console.error('❌ Error obteniendo grupos:', groupsError);
            return res.status(500).json({ error: { message: 'Error al obtener grupos' } });
        }

        // 2. Por cada grupo, obtener sus miembros
        const groupsWithMembers = [];
        for (const group of groups) {
            // Buscar usuarios que tengan el 'name' (id) O el 'display_name' (nombre visible)
            // Esto soluciona el problema de inconsistencia en la BD
            const { data: members, error: membersError } = await supabase
                .from('profiles')
                .select('user_id, full_name, role, avatar_url, group_name')
                .or(`group_name.eq.${group.name},group_name.eq.${group.display_name}`)
                .order('full_name', { ascending: true });

            if (!membersError) {
                groupsWithMembers.push({
                    ...group,
                    members: members || []
                });
            }
        }

        // 3. Obtener usuarios sin grupo (solo students y teachers)
        const { data: unassigned, error: unassignedError } = await supabase
            .from('profiles')
            .select('user_id, full_name, role, avatar_url')
            .is('group_name', null)
            .in('role', ['student', 'teacher'])
            .order('full_name', { ascending: true });

        if (unassignedError) {
            console.error('❌ Error obteniendo no asignados:', unassignedError);
        }

        console.log(`✅ ${groupsWithMembers.length} grupos, ${unassigned?.length || 0} sin asignar`);

        res.json({
            groups: groupsWithMembers,
            unassigned: unassigned || []
        });
    } catch (error) {
        console.error('💥 Error en /admin/groups/with-members:', error);
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

/**
 * DELETE /api/admin/groups/:groupName
 * Elimina un grupo y mueve sus miembros a null
 */
router.delete('/groups/:groupName', authenticateUser, requireAdmin, async (req, res) => {
    try {
        const { groupName } = req.params;
        const { confirmName } = req.body;

        if (confirmName !== groupName) {
            return res.status(400).json({ error: { message: 'El nombre de confirmación no coincide' } });
        }

        console.log(`🗑️ Eliminando grupo: ${groupName}`);

        // 1. Mover usuarios a null (No Asignado)
        const { error: updateUsersError } = await supabase
            .from('profiles')
            .update({ group_name: null })
            .eq('group_name', groupName);

        if (updateUsersError) {
            console.error('❌ Error moviendo usuarios:', updateUsersError);
            return res.status(500).json({ error: { message: 'Error al mover usuarios' } });
        }

        // 2. Eliminar grupo físicamente (Hard Delete)
        const { error: deleteGroupError } = await supabase
            .from('groups')
            .delete()
            .eq('name', groupName);

        if (deleteGroupError) {
            console.error('❌ Error eliminando grupo:', deleteGroupError);
            return res.status(500).json({ error: { message: 'Error al eliminar grupo' } });
        }

        res.json({ message: 'Grupo eliminado correctamente' });
    } catch (error) {
        console.error('💥 Error en DELETE /groups:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

module.exports = router;
