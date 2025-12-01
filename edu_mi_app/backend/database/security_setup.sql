-- Configuración de Row Level Security (RLS) para Supabase
-- Ejecuta esto en Supabase SQL Editor

-- ==============================================
-- HABILITAR RLS EN TABLAS
-- ==============================================

-- Ya deberías tener RLS habilitado de antes, pero verificamos:
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE meeting_participants ENABLE ROW LEVEL SECURITY;

-- ==============================================
-- POLÍTICAS PARA PROFILES
-- ==============================================

-- Los usuarios solo pueden ver su propio perfil
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT
    USING (auth.uid() = user_id);

-- Los usuarios pueden actualizar su propio perfil
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE
    USING (auth.uid() = user_id);

-- ==============================================
-- POLÍTICAS PARA MEETINGS
-- ==============================================

-- Todos pueden ver reuniones activas (para unirse)
DROP POLICY IF EXISTS "Anyone can view active meetings" ON meetings;
CREATE POLICY "Anyone can view active meetings" ON meetings
    FOR SELECT
    USING (is_active = true);

-- Solo usuarios autenticados pueden crear reuniones
DROP POLICY IF EXISTS "Authenticated users can create meetings" ON meetings;
CREATE POLICY "Authenticated users can create meetings" ON meetings
    FOR INSERT
    WITH CHECK (
        auth.uid() = creator_id 
        AND is_active = true
    );

-- Solo el creador puede actualizar su reunión
DROP POLICY IF EXISTS "Creators can update meetings" ON meetings;
CREATE POLICY "Creators can update meetings" ON meetings
    FOR UPDATE
    USING (auth.uid() = creator_id);

-- Solo el creador puede eliminar su reunión
DROP POLICY IF EXISTS "Creators can delete meetings" ON meetings;
CREATE POLICY "Creators can delete meetings" ON meetings
    FOR DELETE
    USING (auth.uid() = creator_id);

-- ==============================================
-- POLÍTICAS PARA MEETING_PARTICIPANTS
-- ==============================================

-- Los usuarios pueden ver participantes de reuniones activas
DROP POLICY IF EXISTS "Users can view participants" ON meeting_participants;
CREATE POLICY "Users can view participants" ON meeting_participants
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM meetings 
            WHERE meetings.id = meeting_participants.meeting_id 
            AND meetings.is_active = true
        )
    );

-- Los usuarios pueden registrarse como participantes
DROP POLICY IF EXISTS "Users can join meetings" ON meeting_participants;
CREATE POLICY "Users can join meetings" ON meeting_participants
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- ==============================================
-- PREVENCIÓN DE ABUSO: LÍMITES
-- ==============================================

-- Función para verificar límite de reuniones por usuario
CREATE OR REPLACE FUNCTION check_meeting_limit()
RETURNS TRIGGER AS $$
DECLARE
    active_meetings_count INTEGER;
    user_limit INTEGER;
BEGIN
    -- Obtener el límite del usuario (si existe)
    SELECT meeting_limit INTO user_limit
    FROM profiles
    WHERE user_id = NEW.creator_id;

    -- Si no hay límite configurado, permitir
    IF user_limit IS NULL THEN
        RETURN NEW;
    END IF;

    -- Contar reuniones activas del usuario
    SELECT COUNT(*) INTO active_meetings_count
    FROM meetings
    WHERE creator_id = NEW.creator_id
      AND is_active = true;

    -- Verificar si excede el límite
    IF active_meetings_count >= user_limit THEN
        RAISE EXCEPTION 'Meeting limit exceeded: % meetings allowed', user_limit;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para aplicar límite al crear reunión
DROP TRIGGER IF EXISTS enforce_meeting_limit ON meetings;
CREATE TRIGGER enforce_meeting_limit
    BEFORE INSERT ON meetings
    FOR EACH ROW
    EXECUTE FUNCTION check_meeting_limit();

-- ==============================================
-- LOGS DE AUDITORÍA
-- ==============================================

-- Tabla para logs de auditoría
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id UUID,
    old_data JSONB,
    new_data JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);

-- RLS para audit_logs (solo admins o el propio usuario pueden ver sus logs)
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own audit logs" ON audit_logs;
CREATE POLICY "Users can view own audit logs" ON audit_logs
    FOR SELECT
    USING (auth.uid() = user_id);

-- Función genérica para registrar auditoría
CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (user_id, action, table_name, record_id, new_data)
        VALUES (auth.uid(), 'INSERT', TG_TABLE_NAME, NEW.id, row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (user_id, action, table_name, record_id, old_data, new_data)
        VALUES (auth.uid(), 'UPDATE', TG_TABLE_NAME, NEW.id, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (user_id, action, table_name, record_id, old_data)
        VALUES (auth.uid(), 'DELETE', TG_TABLE_NAME, OLD.id, row_to_json(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Aplicar auditoría a meetings
DROP TRIGGER IF EXISTS audit_meetings_changes ON meetings;
CREATE TRIGGER audit_meetings_changes
    AFTER INSERT OR UPDATE OR DELETE ON meetings
    FOR EACH ROW
    EXECUTE FUNCTION log_audit();

-- Aplicar auditoría a profiles (solo updates importantes)
DROP TRIGGER IF EXISTS audit_profile_changes ON profiles;
CREATE TRIGGER audit_profile_changes
    AFTER UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION log_audit();

-- ==============================================
-- LIMPIEZA AUTOMÁTICA DE DATOS ANTIGUOS
-- ==============================================

-- Función para limpiar reuniones antiguas
CREATE OR REPLACE FUNCTION cleanup_old_meetings()
RETURNS void AS $$
BEGIN
    -- Marcar como inactivas reuniones expiradas
    UPDATE meetings
    SET is_active = false
    WHERE is_active = true
      AND expires_at < NOW();

    -- Eliminar reuniones muy antiguas (más de 30 días inactivas)
    DELETE FROM meetings
    WHERE is_active = false
      AND ended_at < NOW() - INTERVAL '30 days';

    -- Eliminar logs de auditoría antiguos (más de 90 días)
    DELETE FROM audit_logs
    WHERE created_at < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- ==============================================
-- CONFIGURACIÓN ADICIONAL DE SEGURIDAD
-- ==============================================

-- Establecer límites por defecto para nuevos usuarios
ALTER TABLE profiles 
    ALTER COLUMN can_create_meetings SET DEFAULT true,
    ALTER COLUMN meeting_limit SET DEFAULT 5;  -- Máximo 5 reuniones activas por usuario

-- Comentarios para documentación
COMMENT ON TABLE audit_logs IS 'Registro de todas las acciones importantes del sistema';
COMMENT ON FUNCTION check_meeting_limit() IS 'Previene que usuarios excedan su límite de reuniones';
COMMENT ON FUNCTION log_audit() IS 'Registra automáticamente cambios en tablas importantes';
COMMENT ON FUNCTION cleanup_old_meetings() IS 'Limpia datos antiguos para mantener la BD eficiente';
