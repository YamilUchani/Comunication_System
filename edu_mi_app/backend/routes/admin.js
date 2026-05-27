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

        if (!role || !['student', 'teacher', 'parent', 'administrator'].includes(role)) {
            return res.status(400).json({
                error: { message: 'Rol inválido. Debe ser: student, teacher, parent o administrator' }
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

/**
 * GET /api/admin/parents
 * Obtiene lista de padres con sus estudiantes vinculados
 */
router.get('/parents', authenticateUser, requireAdmin, async (req, res) => {
    try {
        console.log('📥 GET /api/admin/parents');

        // 1. Obtener todos los vínculos de parent_students
        const { data: links, error: linksError } = await supabase
            .from('parent_students')
            .select('parent_id, student_id, created_at');

        if (linksError) {
            console.error('❌ Error obteniendo parent_students:', linksError);
            // No es fatal, solo significa que la tabla no existe o está vacía
        }

        // 2. Obtener todos los perfiles que son padres (role='parent' O están en parent_students)
        const parentIds = [...new Set([
            ...(links || []).map(l => l.parent_id),
        ])];

        let parents = [];
        if (parentIds.length > 0) {
            const { data: parentProfiles } = await supabase
                .from('profiles')
                .select('user_id, full_name, email, role, created_at')
                .in('user_id', parentIds);
            parents = parentProfiles || [];

            // Agregar también padres con role='parent' que quizás no tengan links aún
            const { data: roleParents } = await supabase
                .from('profiles')
                .select('user_id, full_name, email, role, created_at')
                .eq('role', 'parent');
            if (roleParents) {
                const existingIds = new Set(parents.map(p => p.user_id));
                roleParents.forEach(rp => {
                    if (!existingIds.has(rp.user_id)) {
                        parents.push(rp);
                        existingIds.add(rp.user_id);
                    }
                });
            }
        } else {
            // No hay links aún, buscar por role='parent'
            const { data: roleParents } = await supabase
                .from('profiles')
                .select('user_id, full_name, email, role, created_at')
                .eq('role', 'parent');
            parents = roleParents || [];
        }

        // 3. Armar el mapa de estudiantes por padre
        const linkMap = {};
        (links || []).forEach(l => {
            if (!linkMap[l.parent_id]) linkMap[l.parent_id] = [];
            linkMap[l.parent_id].push(l.student_id);
        });

        // 4. Obtener perfiles de los estudiantes vinculados
        const allStudentIds = [...new Set((links || []).map(l => l.student_id))];
        const studentMap = {};
        if (allStudentIds.length > 0) {
            const { data: studentProfiles } = await supabase
                .from('profiles')
                .select('user_id, full_name, email, group_name')
                .in('user_id', allStudentIds);
            if (studentProfiles) {
                studentProfiles.forEach(sp => {
                    studentMap[sp.user_id] = sp;
                });
            }
        }

        // 5. Armar respuesta
        const result = parents.map(p => ({
            id: p.user_id,
            name: p.full_name || 'Sin nombre',
            email: p.email || '',
            role: p.role || 'parent',
            createdAt: p.created_at,
            children: (linkMap[p.user_id] || []).map(sid => ({
                id: sid,
                name: studentMap[sid]?.full_name || 'Desconocido',
                email: studentMap[sid]?.email || '',
                group: studentMap[sid]?.group_name || ''
            }))
        }));

        console.log(`✅ ${result.length} padres encontrados`);
        res.json({ parents: result });
    } catch (error) {
        console.error('💥 Error en /admin/parents:', error);
        res.status(500).json({ error: { message: 'Error interno', details: error.message } });
    }
});

/**
 * POST /api/admin/parents/:parentId/students
 * Vincula un estudiante a un padre
 */
router.post('/parents/:parentId/students', authenticateUser, requireAdmin, async (req, res) => {
    try {
        const { parentId } = req.params;
        const { student_id } = req.body;

        if (!student_id) {
            return res.status(400).json({ error: { message: 'student_id es requerido' } });
        }

        console.log(`🔗 Vinculando padre ${parentId} → estudiante ${student_id}`);

        const { data, error } = await supabase
            .from('parent_students')
            .insert({
                parent_id: parentId,
                student_id: student_id
            })
            .select()
            .single();

        if (error) {
            if (error.code === '23505') {
                return res.status(409).json({ error: { message: 'El estudiante ya está vinculado a este padre' } });
            }
            console.error('❌ Error vinculando:', error);
            return res.status(500).json({ error: { message: 'Error al vincular' } });
        }

        // Asegurar que el padre tenga role='parent'
        await supabase
            .from('profiles')
            .update({ role: 'parent' })
            .eq('user_id', parentId)
            .is('role', null);

        console.log(`✅ Padre ${parentId} vinculado al estudiante ${student_id}`);
        res.status(201).json({ link: data });
    } catch (error) {
        console.error('💥 Error en POST /parents/students:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

/**
 * DELETE /api/admin/parents/:parentId/students/:studentId
 * Desvincula un estudiante de un padre
 */
router.delete('/parents/:parentId/students/:studentId', authenticateUser, requireAdmin, async (req, res) => {
    try {
        const { parentId, studentId } = req.params;

        console.log(`🔓 Desvinculando padre ${parentId} → estudiante ${studentId}`);

        const { error } = await supabase
            .from('parent_students')
            .delete()
            .eq('parent_id', parentId)
            .eq('student_id', studentId);

        if (error) {
            console.error('❌ Error desvinculando:', error);
            return res.status(500).json({ error: { message: 'Error al desvincular' } });
        }

        console.log(`✅ Padre ${parentId} desvinculado del estudiante ${studentId}`);
        res.json({ success: true });
    } catch (error) {
        console.error('💥 Error en DELETE /parents/students:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

/**
 * GET /api/admin/students/search
 * Busca estudiantes para vincular a padres
 */
router.get('/students/search', authenticateUser, requireAdmin, async (req, res) => {
    try {
        const { q } = req.query;
        
        let query = supabase
            .from('profiles')
            .select('user_id, full_name, email, group_name')
            .eq('role', 'student');

        if (q && q.trim().length > 0) {
            query = query.or(`full_name.ilike.%${q}%,email.ilike.%${q}%`);
        }

        const { data: students, error } = await query
            .order('full_name', { ascending: true })
            .limit(20);

        if (error) throw error;

        res.json({ students: students || [] });
    } catch (error) {
        console.error('💥 Error en /students/search:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

module.exports = router;
