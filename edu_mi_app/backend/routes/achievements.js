const express = require('express');
const router = express.Router();
const { authenticateUser, requireTeacherOrAdmin } = require('../middleware/auth');
const supabase = require('../config/supabase');

/**
 * GET /api/achievements
 * Obtiene lista de logros disponibles
 */
router.get('/', authenticateUser, async (req, res) => {
    try {
        const { data: achievements, error } = await supabase
            .from('achievements')
            .select('*')
            .eq('is_global', true)
            .order('created_at', { ascending: true });

        if (error) {
            console.error('Error obteniendo logros:', error);
            return res.status(500).json({ error: { message: 'Error al obtener logros' } });
        }

        res.json({ achievements });
    } catch (error) {
        console.error('Error en /achievements:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

/**
 * GET /api/achievements/student/:studentId
 * Obtiene logros de un estudiante específico
 */
router.get('/student/:studentId', authenticateUser, async (req, res) => {
    try {
        const { studentId } = req.params;

        // Verificar permisos: el estudiante mismo, su teacher, o admin
        if (req.user.id !== studentId &&
            req.user.role !== 'teacher' &&
            req.user.role !== 'administrator') {
            return res.status(403).json({
                error: { message: 'Acceso denegado' }
            });
        }

        const { data: studentAchievements, error } = await supabase
            .from('student_achievements')
            .select(`
                *,
                achievements (*),
                unlocked_by_profile:unlocked_by (full_name)
            `)
            .eq('student_id', studentId)
            .order('unlocked_at', { ascending: false });

        if (error) {
            console.error('Error obteniendo logros del estudiante:', error);
            return res.status(500).json({ error: { message: 'Error al obtener logros' } });
        }

        res.json({ achievements: studentAchievements });
    } catch (error) {
        console.error('Error en /achievements/student:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

/**
 * POST /api/achievements/unlock
 * Desbloquea un logro para un estudiante
 */
router.post('/unlock', authenticateUser, requireTeacherOrAdmin, async (req, res) => {
    try {
        const { student_id, achievement_id } = req.body;

        if (!student_id || !achievement_id) {
            return res.status(400).json({
                error: { message: 'student_id y achievement_id son requeridos' }
            });
        }

        const { data, error } = await supabase
            .from('student_achievements')
            .insert({
                student_id,
                achievement_id,
                unlocked_by: req.user.id
            })
            .select(`
                *,
                achievements (*)
            `)
            .single();

        if (error) {
            if (error.code === '23505') {
                return res.status(409).json({
                    error: { message: 'El estudiante ya tiene este logro' }
                });
            }
            console.error('Error desbloqueando logro:', error);
            return res.status(500).json({ error: { message: 'Error al desbloquear logro' } });
        }

        res.status(201).json({
            message: 'Logro desbloqueado exitosamente',
            achievement: data
        });
    } catch (error) {
        console.error('Error en /achievements/unlock:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

module.exports = router;
