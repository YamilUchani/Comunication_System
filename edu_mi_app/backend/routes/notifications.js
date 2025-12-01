const express = require('express');
const router = express.Router();
const { authenticateUser } = require('../middleware/auth');
const supabase = require('../config/supabase');

/**
 * GET /api/notifications
 * Obtiene notificaciones del usuario
 */
router.get('/', authenticateUser, async (req, res) => {
    try {
        const { is_read } = req.query;

        let query = supabase
            .from('notifications')
            .select('*')
            .eq('user_id', req.user.id)
            .order('created_at', { ascending: false });

        if (is_read !== undefined) {
            query = query.eq('is_read', is_read === 'true');
        }

        const { data: notifications, error } = await query.limit(50);

        if (error) {
            console.error('Error obteniendo notificaciones:', error);
            return res.status(500).json({ error: { message: 'Error al obtener notificaciones' } });
        }

        res.json({ notifications });
    } catch (error) {
        console.error('Error en /notifications:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

/**
 * PUT /api/notifications/:id/read
 * Marca una notificación como leída
 */
router.put('/:id/read', authenticateUser, async (req, res) => {
    try {
        const { id } = req.params;

        const { data, error } = await supabase
            .from('notifications')
            .update({
                is_read: true,
                read_at: new Date().toISOString()
            })
            .eq('id', id)
            .eq('user_id', req.user.id)
            .select()
            .single();

        if (error) {
            console.error('Error marcando notificación:', error);
            return res.status(500).json({ error: { message: 'Error al marcar notificación' } });
        }

        res.json({ notification: data });
    } catch (error) {
        console.error('Error en /notifications/read:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

/**
 * PUT /api/notifications/read-all
 * Marca todas las notificaciones como leídas
 */
router.put('/read-all', authenticateUser, async (req, res) => {
    try {
        const { error } = await supabase
            .from('notifications')
            .update({
                is_read: true,
                read_at: new Date().toISOString()
            })
            .eq('user_id', req.user.id)
            .eq('is_read', false);

        if (error) {
            console.error('Error marcando todas las notificaciones:', error);
            return res.status(500).json({ error: { message: 'Error al marcar notificaciones' } });
        }

        res.json({ message: 'Todas las notificaciones marcadas como leídas' });
    } catch (error) {
        console.error('Error en /notifications/read-all:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

/**
 * GET /api/notifications/unread-count
 * Obtiene el conteo de notificaciones no leídas
 */
router.get('/unread-count', authenticateUser, async (req, res) => {
    try {
        const { count } = await supabase
            .from('notifications')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', req.user.id)
            .eq('is_read', false);

        res.json({ unread_count: count || 0 });
    } catch (error) {
        console.error('Error en /notifications/unread-count:', error);
        res.status(500).json({ error: { message: 'Error interno' } });
    }
});

module.exports = router;
