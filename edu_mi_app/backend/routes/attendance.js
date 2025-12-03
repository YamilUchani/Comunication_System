const express = require('express');
const router = express.Router();
const { authenticateUser } = require('../middleware/auth');
const supabase = require('../config/supabase');

/**
 * POST /api/attendance/record
 * Registra asistencia de estudiantes para una fecha específica
 * Solo Teachers y Admins pueden usar este endpoint
 */
router.post('/record', authenticateUser, async (req, res) => {
    try {
        const { meeting_date, student_ids, meeting_id, notes } = req.body;
        const teacherId = req.user.id;

        console.log(`📥 POST /api/attendance/record - Teacher: ${teacherId}, Date: ${meeting_date}`);

        // Validar que el usuario sea teacher o admin
        const { data: profile } = await supabase
            .from('profiles')
            .select('role, group_name')
            .eq('user_id', teacherId)
            .single();

        if (!profile || !['teacher', 'administrator'].includes(profile.role)) {
            return res.status(403).json({
                error: { message: 'Solo teachers y administradores pueden registrar asistencia' }
            });
        }

        // Validar datos requeridos
        if (!meeting_date || !student_ids || !Array.isArray(student_ids) || student_ids.length === 0) {
            return res.status(400).json({
                error: { message: 'meeting_date y student_ids (array) son requeridos' }
            });
        }

        // Crear o actualizar registros de asistencia para cada estudiante
        // Usar upsert para evitar duplicados por fecha
        const attendanceRecords = student_ids.map(studentId => ({
            user_id: studentId,
            meeting_date: meeting_date,
            meeting_id: meeting_id || null,
            joined_at: new Date().toISOString(),
            was_on_time: true
        }));

        const { data: attendance, error } = await supabase
            .from('attendance')
            .upsert(attendanceRecords, {
                onConflict: 'user_id,meeting_date',
                ignoreDuplicates: false  // Actualizar si ya existe
            })
            .select();

        if (error) {
            console.error('❌ Error registrando asistencia:', error);
            return res.status(500).json({
                error: { message: 'Error al registrar asistencia', details: error.message }
            });
        }

        console.log(`✅ Asistencia registrada: ${attendance.length} estudiantes`);

        res.status(201).json({
            message: 'Asistencia registrada exitosamente',
            attendance: attendance
        });
    } catch (error) {
        console.error('💥 Error en /attendance/record:', error);
        res.status(500).json({
            error: { message: 'Error interno al registrar asistencia' }
        });
    }
});

/**
 * GET /api/attendance/teacher/:teacherId
 * Obtiene historial de asistencias registradas por un teacher
 * Query params: ?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
 */
router.get('/teacher/:teacherId', authenticateUser, async (req, res) => {
    try {
        const { teacherId } = req.params;
        const { start_date, end_date } = req.query;
        const requesterId = req.user.id;

        console.log(`📥 GET /api/attendance/teacher/${teacherId}`);

        // Validar que el usuario pueda ver esta información
        const { data: requesterProfile } = await supabase
            .from('profiles')
            .select('role')
            .eq('user_id', requesterId)
            .single();

        const isAdmin = requesterProfile?.role === 'administrator';
        const isOwnData = teacherId === requesterId;

        if (!isAdmin && !isOwnData) {
            return res.status(403).json({
                error: { message: 'No tienes permiso para ver esta información' }
            });
        }

        // Construir query - attendance table solo tiene user_id, no teacher_id
        let query = supabase
            .from('attendance')
            .select(`
                id,
                meeting_date,
                joined_at,
                left_at,
                duration_minutes,
                user_id,
                meeting:meetings(id, title)
            `)
            .order('meeting_date', { ascending: false });

        // Aplicar filtros de fecha si existen
        if (start_date) {
            query = query.gte('meeting_date', start_date);
        }
        if (end_date) {
            query = query.lte('meeting_date', end_date);
        }

        const { data: attendance, error } = await query;

        if (error) {
            console.error('❌ Error obteniendo asistencias:', error);
            return res.status(500).json({
                error: { message: 'Error al obtener asistencias', details: error.message }
            });
        }

        console.log(`✅ ${attendance?.length || 0} registros de asistencia encontrados`);

        res.json({ attendance: attendance || [] });
    } catch (error) {
        console.error('💥 Error en /attendance/teacher:', error);
        res.status(500).json({
            error: { message: 'Error interno al obtener asistencias' }
        });
    }
});

/**
 * GET /api/attendance/student/:studentId
 * Obtiene historial de asistencias de un estudiante
 */
router.get('/student/:studentId', authenticateUser, async (req, res) => {
    try {
        const { studentId } = req.params;
        const requesterId = req.user.id;

        console.log(`📥 GET /api/attendance/student/${studentId}`);

        // Validar que el usuario pueda ver esta información
        const { data: requesterProfile } = await supabase
            .from('profiles')
            .select('role')
            .eq('user_id', requesterId)
            .single();

        const isAdmin = requesterProfile?.role === 'administrator';
        const isTeacher = requesterProfile?.role === 'teacher';
        const isOwnData = studentId === requesterId;

        if (!isAdmin && !isTeacher && !isOwnData) {
            return res.status(403).json({
                error: { message: 'No tienes permiso para ver esta información' }
            });
        }

        const { data: attendance, error } = await supabase
            .from('attendance')
            .select(`
                id,
                meeting_date,
                joined_at,
                left_at,
                duration_minutes
            `)
            .eq('user_id', studentId)
            .order('meeting_date', { ascending: false });

        if (error) {
            console.error('❌ Error obteniendo asistencias del estudiante:', error);
            return res.status(500).json({
                error: { message: 'Error al obtener asistencias', details: error.message }
            });
        }

        console.log(`✅ ${attendance?.length || 0} asistencias del estudiante`);

        res.json({ attendance: attendance || [] });
    } catch (error) {
        console.error('💥 Error en /attendance/student:', error);
        res.status(500).json({
            error: { message: 'Error interno al obtener asistencias' }
        });
    }
});

/**
 * GET /api/attendance/date/:date
 * Obtiene asistencias de una fecha específica para el teacher actual
 */
router.get('/date/:date', authenticateUser, async (req, res) => {
    try {
        const { date } = req.params;
        const teacherId = req.user.id;

        console.log(`📥 GET /api/attendance/date/${date} - Teacher: ${teacherId}`);

        const { data: attendance, error } = await supabase
            .from('attendance')
            .select(`
                id,
                user_id,
                joined_at,
                meeting_date
            `)
            .eq('meeting_date', date);

        if (error) {
            console.error('❌ Error obteniendo asistencias por fecha:', error);
            return res.status(500).json({
                error: { message: 'Error al obtener asistencias', details: error.message }
            });
        }

        res.json({ attendance: attendance || [] });
    } catch (error) {
        console.error('💥 Error en /attendance/date:', error);
        res.status(500).json({
            error: { message: 'Error interno' }
        });
    }
});

/**
 * PUT /api/attendance/:attendanceId/achievements
 * Asigna logros a estudiantes de una sesión de asistencia
 */
router.put('/:attendanceId/achievements', authenticateUser, async (req, res) => {
    try {
        const { attendanceId } = req.params;
        const { achievement_ids } = req.body;
        const teacherId = req.user.id;

        console.log(`📥 PUT /api/attendance/${attendanceId}/achievements`);

        if (!achievement_ids || !Array.isArray(achievement_ids)) {
            return res.status(400).json({
                error: { message: 'achievement_ids (array) es requerido' }
            });
        }

        // Verificar que la asistencia existe
        const { data: attendance, error: attendanceError } = await supabase
            .from('attendance')
            .select('user_id')
            .eq('id', attendanceId)
            .single();

        if (attendanceError || !attendance) {
            return res.status(404).json({
                error: { message: 'Registro de asistencia no encontrado' }
            });
        }

        // Crear registros de logros vinculados a esta asistencia
        const achievementRecords = achievement_ids.map(achievementId => ({
            student_id: attendance.user_id,
            achievement_id: achievementId,
            attendance_id: attendanceId,
            unlocked_at: new Date().toISOString(),
            unlocked_by: teacherId
        }));

        const { data: achievements, error: achievementsError } = await supabase
            .from('student_achievements')
            .upsert(achievementRecords, {
                onConflict: 'student_id,achievement_id,attendance_id',
                ignoreDuplicates: true
            })
            .select();

        if (achievementsError) {
            console.error('❌ Error asignando logros:', achievementsError);
            return res.status(500).json({
                error: { message: 'Error al asignar logros', details: achievementsError.message }
            });
        }

        console.log(`✅ ${achievements?.length || 0} logros asignados`);

        res.json({
            message: 'Logros asignados exitosamente',
            achievements: achievements
        });
    } catch (error) {
        console.error('💥 Error en /attendance/achievements:', error);
        res.status(500).json({
            error: { message: 'Error interno' }
        });
    }
});

module.exports = router;
