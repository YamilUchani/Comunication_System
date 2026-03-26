-- ============================================================
-- FIX: Corregir trigger de notificaciones de logros
-- El trigger antiguo intentaba usar una columna "data" que no existe
-- Ejecutar en Supabase SQL Editor
-- ============================================================

-- Paso 1: Eliminar el trigger defectuoso
DROP TRIGGER IF EXISTS trigger_notify_achievement_unlock ON student_achievements;

-- Paso 2: Eliminar la función defectuosa del trigger
DROP FUNCTION IF EXISTS notify_achievement_unlock();

-- Paso 3: Verificar la estructura actual de la tabla notifications
-- (Solo para inspección, comentar si no se necesita)
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_name = 'notifications' ORDER BY ordinal_position;

-- Paso 4: Recrear la función correctamente (sin la columna "data")
-- La tabla notifications tiene: id, user_id, title, body, type, related_id, is_read, created_at, read_at
CREATE OR REPLACE FUNCTION notify_achievement_unlock()
RETURNS TRIGGER AS $$
DECLARE
    v_achievement_name VARCHAR;
    v_achievement_icon VARCHAR;
BEGIN
    -- Obtener datos del logro
    SELECT name, icon 
    INTO v_achievement_name, v_achievement_icon
    FROM achievements 
    WHERE id = NEW.achievement_id;
    
    -- Insertar notificación usando solo las columnas que existen
    INSERT INTO notifications (user_id, title, body, type, related_id)
    VALUES (
        NEW.student_id,
        '¡Logro desbloqueado! ' || COALESCE(v_achievement_icon, '🏆'),
        'Has desbloqueado: ' || COALESCE(v_achievement_name, 'Nuevo logro'),
        'achievement_unlocked',
        NEW.achievement_id
    );
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Si algo falla en la notificación, NO bloquear la inserción del logro
    RAISE WARNING 'Error creating achievement notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Paso 5: Recrear el trigger correctamente
CREATE TRIGGER trigger_notify_achievement_unlock
    AFTER INSERT ON student_achievements
    FOR EACH ROW
    EXECUTE FUNCTION notify_achievement_unlock();

-- Paso 6: Verificar que el trigger fue creado correctamente
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE event_object_table = 'student_achievements';
