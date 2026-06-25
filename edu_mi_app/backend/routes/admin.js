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
 * GET /api/admin/parents/debug
 * Diagnóstico detallado del sistema de padres
 */
router.get('/parents/debug', authenticateUser, requireAdmin, async (req, res) => {
    try {
        console.log('🔍 DEBUG /api/admin/parents/debug');
        
        const results = {};

        // 1. Info del admin autenticado
        results.admin = {
            user_id: req.user.id,
            email: req.user.email,
            role: req.user.role,
            profile: req.user.profile
        };
        console.log('1️⃣ Admin info:', results.admin);

        // 2. Verificar si existe la tabla parent_profiles
        const { data: tableCheck, error: tableError } = await supabase
            .from('parent_profiles')
            .select('count(*)', { count: 'exact', head: true });
        results.tableExists = { exists: !tableError, error: tableError };
        console.log('2️⃣ Table check:', results.tableExists);

        // 3. Contar registros en parent_profiles
        const { data: parentCount, error: countError } = await supabase
            .from('parent_profiles')
            .select('id, full_name, email', { count: 'exact' });
        results.parentCount = { 
            count: parentCount?.length || 0, 
            error: countError,
            firstFew: parentCount?.slice(0, 5) || []
        };
        console.log('3️⃣ Parent profiles count:', results.parentCount);

        // 4. Contar registros en parent_students
        const { data: linkCount, error: linkCountError } = await supabase
            .from('parent_students')
            .select('parent_id, student_id');
        results.linkCount = { 
            count: linkCount?.length || 0, 
            error: linkCountError 
        };
        console.log('4️⃣ Parent_students count:', results.linkCount);

        // 5. Buscar el perfil del admin en profiles
        const { data: adminProfile, error: adminProfileError } = await supabase
            .from('profiles')
            .select('user_id, role, email, full_name')
            .eq('user_id', req.user.id)
            .maybeSingle();
        results.adminProfile = { profile: adminProfile, error: adminProfileError };
        console.log('5️⃣ Admin profile check:', results.adminProfile);

        // 6. Simular la consulta ORIGINAL del endpoint (para ver si falla)
        const { data: directQuery, error: directError } = await supabase
            .from('parent_profiles')
            .select('id, full_name, email, parent_age, relationship_to_student, created_at')
            .order('created_at', { ascending: false });
        results.directQuery = { 
            rowsReturned: directQuery?.length || 0, 
            error: directError,
            data: directQuery?.slice(0, 3) || []
        };
        console.log('6️⃣ Direct parent_profiles query:', results.directQuery);

        return res.json(results);
    } catch (error) {
        console.error('💥 DEBUG error:', error);
        return res.status(500).json({ error: { message: 'Error en debug', details: error.message, stack: error.stack } });
    }
});

/**
 * GET /api/admin/parents
 * Obtiene lista de padres con sus estudiantes vinculados
 */
router.get('/parents', authenticateUser, requireAdmin, async (req, res, next) => {
    try {
        console.log('📥 GET /api/admin/parents - parent_profiles');
        console.log('👤 Admin user:', { id: req.user.id, role: req.user.role });

        // Paso 1: Obtener parent_students
        const { data: links, error: linksError } = await supabase
            .from('parent_students')
            .select('parent_id, student_id, created_at');

        console.log('1️⃣ parent_students query:', { 
            linksCount: links?.length, 
            error: linksError?.message 
        });

        if (linksError) {
            console.error('❌ Error obteniendo parent_students:', linksError);
        }

        // Paso 2: Obtener parent_profiles
        const { data: parentProfiles, error: parentsError } = await supabase
            .from('parent_profiles')
            .select('id, full_name, email, parent_age, relationship_to_student, created_at')
            .order('created_at', { ascending: false });

        console.log('2️⃣ parent_profiles query:', { 
            profilesCount: parentProfiles?.length, 
            error: parentsError?.message 
        });

        if (parentsError) {
            console.error('❌ Error obteniendo parent_profiles:', parentsError);
            return res.status(500).json({
                error: {
                    message: 'Error al obtener padres/tutores',
                    details: parentsError.message,
                    hint: 'Ejecuta App_Supervisor/supabase/guardian_profile_fields.sql en Supabase.'
                }
            });
        }

        // Paso 3: Construir mapa de estudiantes por padre
        const linkMap = {};
        (links || []).forEach((link) => {
            if (!linkMap[link.parent_id]) linkMap[link.parent_id] = [];
            linkMap[link.parent_id].push(link.student_id);
        });
        console.log('3️⃣ Link map built:', Object.keys(linkMap).length, 'parents have links');

        // Paso 4: Obtener datos de estudiantes vinculados
        const allStudentIds = [...new Set((links || []).map((link) => link.student_id))];
        const studentMap = {};
        if (allStudentIds.length > 0) {
            console.log('4️⃣ Fetching', allStudentIds.length, 'students profiles');
            const { data: studentProfiles, error: studentsError } = await supabase
                .from('profiles')
                .select('user_id, full_name, email, group_name')
                .in('user_id', allStudentIds);

            if (studentsError) {
                console.error('❌ Error obteniendo estudiantes vinculados:', studentsError);
            }

            (studentProfiles || []).forEach((student) => {
                studentMap[student.user_id] = student;
            });
        }
        // Paso 6: Construir respuesta final
        const parents = (parentProfiles || []).map((parent) => ({
            id: parent.id,
            name: parent.full_name || 'Sin nombre',
            email: parent.email || '',
            role: 'parent',
            age: parent.parent_age || null,
            relationship: parent.relationship_to_student || '',
            createdAt: parent.created_at,
            children: (linkMap[parent.id] || []).map((studentId) => ({
                id: studentId,
                name: studentMap[studentId]?.full_name || 'Desconocido',
                email: studentMap[studentId]?.email || '',
                group: studentMap[studentId]?.group_name || ''
            }))
        }));

        console.log(`✅ ${parents.length} padres/tutores encontrados en parent_profiles`);
        return res.json({ parents });
    } catch (error) {
        console.error('💥 Error en /admin/parents parent_profiles:', error);
        return res.status(500).json({ error: { message: 'Error interno', details: error.message } });
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
