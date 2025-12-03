-- =====================================================
-- Script: Sistema de Asistencia y Logros por Sesión
-- Descripción: Crea tabla de asistencia y modifica
--              student_achievements para vincular logros
--              con sesiones de clase específicas
-- =====================================================

-- 1. Crear tabla de asistencia
CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID REFERENCES meetings(id) ON DELETE SET NULL,
    student_id UUID NOT NULL,
    teacher_id UUID NOT NULL,
    meeting_date DATE NOT NULL,
    was_present BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Crear índices para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_teacher ON attendance(teacher_id);
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

-- 6. Habilitar RLS (Row Level Security) en attendance
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

-- 7. Políticas de seguridad para attendance

-- Teachers pueden ver asistencias de sus estudiantes
DROP POLICY IF EXISTS "Teachers can view their students attendance" ON attendance;
CREATE POLICY "Teachers can view their students attendance"
ON attendance FOR SELECT
TO authenticated
USING (
    teacher_id = auth.uid()
    OR
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.user_id = auth.uid()
        AND profiles.role = 'administrator'
    )
);

-- Teachers pueden crear registros de asistencia
DROP POLICY IF EXISTS "Teachers can create attendance records" ON attendance;
CREATE POLICY "Teachers can create attendance records"
ON attendance FOR INSERT
TO authenticated
WITH CHECK (
    teacher_id = auth.uid()
    AND
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.user_id = auth.uid()
        AND profiles.role IN ('teacher', 'administrator')
    )
);

-- Teachers pueden actualizar sus propios registros de asistencia
DROP POLICY IF EXISTS "Teachers can update their attendance records" ON attendance;
CREATE POLICY "Teachers can update their attendance records"
ON attendance FOR UPDATE
TO authenticated
USING (teacher_id = auth.uid())
WITH CHECK (teacher_id = auth.uid());

-- Students pueden ver su propia asistencia
DROP POLICY IF EXISTS "Students can view their own attendance" ON attendance;
CREATE POLICY "Students can view their own attendance"
ON attendance FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- 8. Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_attendance_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. Trigger para actualizar updated_at
DROP TRIGGER IF EXISTS attendance_updated_at ON attendance;
CREATE TRIGGER attendance_updated_at
    BEFORE UPDATE ON attendance
    FOR EACH ROW
    EXECUTE FUNCTION update_attendance_updated_at();

-- 10. Comentarios para documentación
COMMENT ON TABLE attendance IS 'Registros de asistencia de estudiantes a clases';
COMMENT ON COLUMN attendance.meeting_id IS 'Referencia opcional a la reunión/clase';
COMMENT ON COLUMN attendance.student_id IS 'ID del estudiante';
COMMENT ON COLUMN attendance.teacher_id IS 'ID del profesor que registró la asistencia';
COMMENT ON COLUMN attendance.meeting_date IS 'Fecha de la clase';
COMMENT ON COLUMN attendance.was_present IS 'Indica si el estudiante estuvo presente';
COMMENT ON COLUMN attendance.notes IS 'Notas del profesor sobre la sesión';

-- =====================================================
-- Fin del script
-- =====================================================

