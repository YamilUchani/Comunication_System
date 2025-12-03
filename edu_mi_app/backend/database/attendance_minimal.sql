-- Script minimalista para crear tabla attendance
-- Solo crea la tabla básica sin foreign keys ni RLS

CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID,
    student_id UUID NOT NULL,
    teacher_id UUID NOT NULL,
    meeting_date DATE NOT NULL,
    was_present BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices básicos
CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_teacher ON attendance(teacher_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(meeting_date);

-- Agregar attendance_id a student_achievements si no existe
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
