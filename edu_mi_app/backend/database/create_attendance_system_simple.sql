-- =====================================================
-- Script: Sistema de Asistencia - Versión Simplificada
-- Descripción: Crea tabla de asistencia sin RLS complejo
-- =====================================================

-- 1. Crear tabla de asistencia
CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID,
    student_user_id UUID NOT NULL,
    teacher_user_id UUID NOT NULL,
    meeting_date DATE NOT NULL,
    was_present BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Crear índices para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_user_id);
CREATE INDEX IF NOT EXISTS idx_attendance_teacher ON attendance(teacher_user_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(meeting_date);
CREATE INDEX IF NOT EXISTS idx_attendance_meeting ON attendance(meeting_id);

-- 3. Crear tabla student_achievements si no existe
CREATE TABLE IF NOT EXISTS student_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL,
    achievement_id UUID NOT NULL,
    unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, achievement_id)
);

-- 4. Agregar columna attendance_id a student_achievements si no existe
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'student_achievements' 
        AND column_name = 'attendance_id'
    ) THEN
        ALTER TABLE student_achievements 
        ADD COLUMN attendance_id UUID;
    END IF;
END $$;

-- 5. Crear índice para vincular logros con asistencia
CREATE INDEX IF NOT EXISTS idx_student_achievements_attendance 
ON student_achievements(attendance_id);

-- 6. Deshabilitar RLS temporalmente para evitar conflictos
ALTER TABLE attendance DISABLE ROW LEVEL SECURITY;

-- 7. Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_attendance_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Trigger para actualizar updated_at
DROP TRIGGER IF EXISTS attendance_updated_at ON attendance;
CREATE TRIGGER attendance_updated_at
    BEFORE UPDATE ON attendance
    FOR EACH ROW
    EXECUTE FUNCTION update_attendance_updated_at();

-- 9. Comentarios para documentación
COMMENT ON TABLE attendance IS 'Registros de asistencia de estudiantes a clases';
COMMENT ON COLUMN attendance.meeting_id IS 'Referencia opcional a la reunión/clase';
COMMENT ON COLUMN attendance.student_user_id IS 'user_id del estudiante (de tabla profiles)';
COMMENT ON COLUMN attendance.teacher_user_id IS 'user_id del profesor (de tabla profiles)';
COMMENT ON COLUMN attendance.meeting_date IS 'Fecha de la clase';
COMMENT ON COLUMN attendance.was_present IS 'Indica si el estudiante estuvo presente';
COMMENT ON COLUMN attendance.notes IS 'Notas del profesor sobre la sesión';

-- =====================================================
-- NOTA: RLS está deshabilitado para evitar conflictos.
-- La seguridad se maneja a nivel de backend con JWT.
-- =====================================================
