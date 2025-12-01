-- ============================================
-- FASE 1: Sistema de Roles y Grupos Educativos
-- ============================================
-- Ejecutar DESPUÉS de schema.sql y security_setup.sql

-- ============================================
-- 1. AGREGAR COLUMNAS A PROFILES
-- ============================================

-- Agregar rol (student, teacher, administrator)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'administrator'));

-- Agregar nombre del grupo (ej: 'manzanas', 'peras')
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS group_name VARCHAR(50);

-- Agregar referencia al maestro (si es estudiante)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES profiles(user_id) ON DELETE SET NULL;

-- Índices para mejorar rendimiento
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_group ON profiles(group_name);
CREATE INDEX IF NOT EXISTS idx_profiles_teacher ON profiles(teacher_id);

-- ============================================
-- 2. AGREGAR COLUMNAS A MEETINGS
-- ============================================

-- Grupo al que pertenece la reunión
ALTER TABLE meetings 
ADD COLUMN IF NOT EXISTS group_name VARCHAR(50);

-- Reunión general (creada por admin)
ALTER TABLE meetings 
ADD COLUMN IF NOT EXISTS is_general BOOLEAN DEFAULT false;

-- Roles permitidos (JSON array)
ALTER TABLE meetings 
ADD COLUMN IF NOT EXISTS allowed_roles JSONB DEFAULT '[]'::jsonb;

-- Grupos permitidos (JSON array)
ALTER TABLE meetings 
ADD COLUMN IF NOT EXISTS allowed_groups JSONB DEFAULT '[]'::jsonb;

-- Usuarios específicos permitidos (JSON array)
ALTER TABLE meetings 
ADD COLUMN IF NOT EXISTS allowed_users JSONB DEFAULT '[]'::jsonb;

-- Requiere asignación explícita para estudiantes
ALTER TABLE meetings 
ADD COLUMN IF NOT EXISTS require_assignment BOOLEAN DEFAULT false;

-- ============================================
-- 3. TABLA DE ASIGNACIONES
-- ============================================

CREATE TABLE IF NOT EXISTS meeting_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_required BOOLEAN DEFAULT true,
    
    UNIQUE(meeting_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_assignments_meeting ON meeting_assignments(meeting_id);
CREATE INDEX IF NOT EXISTS idx_assignments_student ON meeting_assignments(student_id);

-- ============================================
-- 4. TABLA DE ASISTENCIA
-- ============================================

CREATE TABLE IF NOT EXISTS attendance (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE NOT NULL,
    left_at TIMESTAMP WITH TIME ZONE,
    duration_minutes INTEGER,
    was_on_time BOOLEAN DEFAULT true,
    meeting_date DATE NOT NULL,
    
    UNIQUE(meeting_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_attendance_meeting ON attendance(meeting_id);
CREATE INDEX IF NOT EXISTS idx_attendance_user ON attendance(user_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(meeting_date);

-- ============================================
-- 5. SISTEMA DE LOGROS
-- ============================================

CREATE TABLE IF NOT EXISTS achievements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50) DEFAULT '🏆',
    created_by UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    group_name VARCHAR(50),
    is_global BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS student_achievements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    unlocked_by UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    
    UNIQUE(student_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_achievements_group ON achievements(group_name);
CREATE INDEX IF NOT EXISTS idx_student_achievements_student ON student_achievements(student_id);

-- ============================================
-- 6. POLÍTICAS RLS ACTUALIZADAS
-- ============================================

-- Eliminar políticas antiguas de meetings
DROP POLICY IF EXISTS "Reuniones activas son públicas" ON meetings;
DROP POLICY IF EXISTS "Usuarios autenticados pueden crear reuniones" ON meetings;
DROP POLICY IF EXISTS "Creadores pueden actualizar sus reuniones" ON meetings;
DROP POLICY IF EXISTS "Creadores pueden eliminar sus reuniones" ON meetings;

-- NUEVA: Administradores ven TODO
CREATE POLICY "Admins can view all meetings" ON meetings
    FOR SELECT
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'administrator'
    );

-- NUEVA: Maestros ven reuniones de su grupo
CREATE POLICY "Teachers view own group meetings" ON meetings
    FOR SELECT
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'teacher'
        AND
        (
            group_name = (SELECT group_name FROM profiles WHERE user_id = auth.uid())
            OR creator_id = auth.uid()
        )
    );

-- NUEVA: Estudiantes ven reuniones asignadas o de su grupo
CREATE POLICY "Students view assigned meetings" ON meetings
    FOR SELECT
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'student'
        AND
        is_active = true
        AND
        (
            -- Reunión de su grupo
            group_name = (SELECT group_name FROM profiles WHERE user_id = auth.uid())
            OR
            -- Está específicamente asignado
            EXISTS (
                SELECT 1 FROM meeting_assignments
                WHERE meeting_id = meetings.id
                  AND student_id = auth.uid()
            )
        )
    );

-- NUEVA: Solo maestros y admins pueden crear
CREATE POLICY "Teachers and admins create meetings" ON meetings
    FOR INSERT
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('teacher', 'administrator')
        AND
        (
            -- Admins pueden crear cualquiera
            (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'administrator'
            OR
            -- Maestros solo de su grupo
            (
                (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'teacher'
                AND group_name = (SELECT group_name FROM profiles WHERE user_id = auth.uid())
            )
        )
    );

-- NUEVA: Solo creadores pueden actualizar
CREATE POLICY "Creators update own meetings" ON meetings
    FOR UPDATE
    USING (auth.uid() = creator_id);

-- NUEVA: Solo creadores pueden eliminar
CREATE POLICY "Creators delete own meetings" ON meetings
    FOR DELETE
    USING (auth.uid() = creator_id);

-- ============================================
-- 7. RLS PARA NUEVAS TABLAS
-- ============================================

-- Meeting Assignments
ALTER TABLE meeting_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Teachers and admins manage assignments" ON meeting_assignments
    FOR ALL
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('teacher', 'administrator')
    );

CREATE POLICY "Students view own assignments" ON meeting_assignments
    FOR SELECT
    USING (student_id = auth.uid());

-- Attendance
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Teachers and admins view all attendance" ON attendance
    FOR SELECT
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('teacher', 'administrator')
    );

CREATE POLICY "Students view own attendance" ON attendance
    FOR SELECT
    USING (user_id = auth.uid());

-- Achievements
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Everyone can view achievements" ON achievements
    FOR SELECT
    USING (true);

CREATE POLICY "Teachers and admins create achievements" ON achievements
    FOR INSERT
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('teacher', 'administrator')
    );

-- Student Achievements
ALTER TABLE student_achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students view own achievements" ON student_achievements
    FOR SELECT
    USING (student_id = auth.uid());

CREATE POLICY "Teachers unlock achievements" ON student_achievements
    FOR INSERT
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('teacher', 'administrator')
    );

-- ============================================
-- 8. FUNCIONES ÚTILES
-- ============================================

-- Verificar si un usuario puede unirse a una reunión
CREATE OR REPLACE FUNCTION can_join_meeting(
    p_meeting_id UUID,
    p_user_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_role VARCHAR(20);
    v_user_group VARCHAR(50);
    v_meeting RECORD;
    v_is_assigned BOOLEAN;
BEGIN
    -- Obtener datos del usuario
    SELECT role, group_name INTO v_user_role, v_user_group
    FROM profiles WHERE user_id = p_user_id;
    
    -- Obtener datos de la reunión
    SELECT * INTO v_meeting FROM meetings WHERE id = p_meeting_id;
    
    -- Admins siempre pueden
    IF v_user_role = 'administrator' THEN
        RETURN true;
    END IF;
    
    -- Verificar si está asignado (si la reunión requiere asignación)
    IF v_meeting.require_assignment THEN
        SELECT EXISTS(
            SELECT 1 FROM meeting_assignments
            WHERE meeting_id = p_meeting_id AND student_id = p_user_id
        ) INTO v_is_assigned;
        
        RETURN v_is_assigned;
    END IF;
    
    -- Verificar grupo
    IF v_meeting.group_name = v_user_group THEN
        RETURN true;
    END IF;
    
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Registrar asistencia automáticamente
CREATE OR REPLACE FUNCTION record_attendance(
    p_meeting_id UUID,
    p_user_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_attendance_id UUID;
BEGIN
    INSERT INTO attendance (
        meeting_id,
        user_id,
        joined_at,
        meeting_date,
        was_on_time
    ) VALUES (
        p_meeting_id,
        p_user_id,
        NOW(),
        CURRENT_DATE,
        NOW() <= (SELECT created_at + INTERVAL '5 minutes' FROM meetings WHERE id = p_meeting_id)
    )
    ON CONFLICT (meeting_id, user_id) DO UPDATE
    SET joined_at = NOW()
    RETURNING id INTO v_attendance_id;
    
    RETURN v_attendance_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 9. DATOS INICIALES (OPCIONAL)
-- ============================================

-- Crear primer administrador (ajusta el email)
-- DESCOMENTAR Y AJUSTAR SEGÚN NECESITES:
/*
UPDATE profiles 
SET role = 'administrator'
WHERE email = 'admin@ejemplo.com';
*/

-- Crear grupos de ejemplo
-- Los grupos se pueden crear dinámicamente, estos son solo ejemplos
COMMENT ON COLUMN profiles.group_name IS 'Ejemplos: manzanas, peras, uvas, naranjas';

-- ============================================
-- COMENTARIOS Y DOCUMENTACIÓN
-- ============================================

COMMENT ON TABLE meeting_assignments IS 'Asignaciones explícitas de estudiantes a reuniones';
COMMENT ON TABLE attendance IS 'Registro automático de asistencia a reuniones';
COMMENT ON TABLE achievements IS 'Logros/actividades que pueden desbloquear estudiantes';
COMMENT ON TABLE student_achievements IS 'Logros desbloqueados por cada estudiante';

COMMENT ON COLUMN profiles.role IS 'Rol del usuario: student, teacher, administrator';
COMMENT ON COLUMN profiles.group_name IS 'Grupo/clase al que pertenece (ej: manzanas)';
COMMENT ON COLUMN profiles.teacher_id IS 'Maestro asignado si es estudiante';

COMMENT ON COLUMN meetings.is_general IS 'Reunión general creada por admin con permisos especiales';
COMMENT ON COLUMN meetings.allowed_roles IS 'Array JSON de roles permitidos';
COMMENT ON COLUMN meetings.allowed_groups IS 'Array JSON de grupos permitidos';
COMMENT ON COLUMN meetings.require_assignment IS 'Si true, solo estudiantes asignados pueden unirse';
