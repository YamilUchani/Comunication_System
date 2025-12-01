-- ============================================
-- Configuración Adicional: Grupos y Logros
-- ============================================

-- ============================================
-- 1. TABLA DE GRUPOS (Máximo 5)
-- ============================================

CREATE TABLE IF NOT EXISTS groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    color VARCHAR(7), -- Color hex ej: #FF5733
    icon VARCHAR(10), -- Emoji ej: 🍎
    created_by UUID NOT NULL REFERENCES profiles(user_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Límite de 5 grupos máximo
CREATE OR REPLACE FUNCTION check_max_groups()
RETURNS TRIGGER AS $$
DECLARE
    groups_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO groups_count FROM groups WHERE is_active = true;
    
    IF groups_count >= 5 THEN
        RAISE EXCEPTION 'Maximum 5 groups allowed';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_max_groups
    BEFORE INSERT ON groups
    FOR EACH ROW
    EXECUTE FUNCTION check_max_groups();

-- Datos iniciales: 3 grupos de ejemplo
INSERT INTO groups (name, display_name, description, color, icon, created_by) 
VALUES 
    ('general', 'General', 'Grupo general para todos', '#3B82F6', '🌐', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1)),
    ('manzanas', 'Grupo Manzanas', 'Primer grupo de estudiantes', '#EF4444', '🍎', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1)),
    ('peras', 'Grupo Peras', 'Segundo grupo de estudiantes', '#10B981', '🍐', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1))
ON CONFLICT (name) DO NOTHING;

-- RLS para groups
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Everyone can view groups" ON groups
    FOR SELECT
    USING (is_active = true);

CREATE POLICY "Only admins can manage groups" ON groups
    FOR ALL
    USING ((SELECT role FROM profiles WHERE user_id = auth.uid()) = 'administrator');

-- ============================================
-- 2. LOGROS GLOBALES PREDEFINIDOS
-- ============================================

-- Insertar logros globales del sistema
INSERT INTO achievements (name, description, icon, created_by, is_global) 
VALUES 
    -- Logros de asistencia
    ('Primera Clase', 'Asistió a su primera clase', '🎓', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1), true),
    ('Puntualidad', 'Llegó a tiempo a 5 clases consecutivas', '⏰', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1), true),
    ('Asistencia Perfecta', 'Asistió a todas las clases del mes', '⭐', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1), true),
    
    -- Logros de participación
    ('Participante Activo', 'Participó en 10 reuniones', '🙋', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1), true),
    ('Colaborador', 'Trabajó en equipo en 5 proyectos', '🤝', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1), true),
    
    -- Logros de progreso
    ('Aprendiz Destacado', 'Completó todas las actividades', '🏆', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1), true),
    ('Superación', 'Mejoró su rendimiento consecutivamente', '📈', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1), true),
    
    -- Logros especiales
    ('Ayudante', 'Ayudó a otros estudiantes', '❤️', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1), true),
    ('Creatividad', 'Presentó un trabajo creativo excepcional', '🎨', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1), true),
    ('Esfuerzo', 'Demostró dedicación y esfuerzo constante', '💪', (SELECT user_id FROM profiles WHERE role = 'administrator' LIMIT 1), true)
ON CONFLICT DO NOTHING;

-- ============================================
-- 3. TABLA DE NOTIFICACIONES
-- ============================================

CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    title VARCHAR(100) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL, -- meeting_assigned, achievement_unlocked, etc.
    related_id UUID, -- ID de reunión, logro, etc.
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;

-- RLS para notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view own notifications" ON notifications
    FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users update own notifications" ON notifications
    FOR UPDATE
    USING (user_id = auth.uid());

-- ============================================
-- 4. FUNCIONES PARA NOTIFICACIONES
-- ============================================

-- Crear notificación
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_title VARCHAR,
    p_body TEXT,
    p_type VARCHAR,
    p_related_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_notification_id UUID;
BEGIN
    INSERT INTO notifications (user_id, title, body, type, related_id)
    VALUES (p_user_id, p_title, p_body, p_type, p_related_id)
    RETURNING id INTO v_notification_id;
    
    RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Notificar cuando se asigna una reunión
CREATE OR REPLACE FUNCTION notify_meeting_assignment()
RETURNS TRIGGER AS $$
DECLARE
    v_meeting_title VARCHAR;
BEGIN
    SELECT title INTO v_meeting_title FROM meetings WHERE id = NEW.meeting_id;
    
    PERFORM create_notification(
        NEW.student_id,
        'Nueva reunión asignada',
        'Se te ha asignado a: ' || v_meeting_title,
        'meeting_assigned',
        NEW.meeting_id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_meeting_assignment
    AFTER INSERT ON meeting_assignments
    FOR EACH ROW
    EXECUTE FUNCTION notify_meeting_assignment();

-- Trigger: Notificar cuando se desbloquea un logro
CREATE OR REPLACE FUNCTION notify_achievement_unlock()
RETURNS TRIGGER AS $$
DECLARE
    v_achievement_name VARCHAR;
BEGIN
    SELECT name INTO v_achievement_name FROM achievements WHERE id = NEW.achievement_id;
    
    PERFORM create_notification(
        NEW.student_id,
        '¡Logro desbloqueado!',
        'Has desbloqueado: ' || v_achievement_name,
        'achievement_unlocked',
        NEW.achievement_id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_achievement_unlock
    AFTER INSERT ON student_achievements
    FOR EACH ROW
    EXECUTE FUNCTION notify_achievement_unlock();

-- ============================================
-- 5. VISTA ÚTIL: Estadísticas de Estudiante
-- ============================================

CREATE OR REPLACE VIEW student_stats AS
SELECT 
    p.user_id,
    p.full_name,
    p.group_name,
    COUNT(DISTINCT a.meeting_id) as total_classes_attended,
    COUNT(DISTINCT CASE WHEN a.was_on_time THEN a.meeting_id END) as on_time_count,
    COUNT(DISTINCT sa.achievement_id) as achievements_unlocked,
    AVG(a.duration_minutes) as avg_duration_minutes
FROM profiles p
LEFT JOIN attendance a ON p.user_id = a.user_id
LEFT JOIN student_achievements sa ON p.user_id = sa.student_id
WHERE p.role = 'student'
GROUP BY p.user_id, p.full_name, p.group_name;

-- Comentarios
COMMENT ON TABLE groups IS 'Grupos de clase (máximo 5)';
COMMENT ON TABLE notifications IS 'Notificaciones push para usuarios';
COMMENT ON VIEW student_stats IS 'Estadísticas agregadas de cada estudiante';
