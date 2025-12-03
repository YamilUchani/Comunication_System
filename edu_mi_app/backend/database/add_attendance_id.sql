-- Solo agregar attendance_id a student_achievements
-- La tabla attendance ya existe con user_id

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'student_achievements' 
        AND column_name = 'attendance_id'
    ) THEN
        ALTER TABLE student_achievements 
        ADD COLUMN attendance_id UUID;
        
        CREATE INDEX IF NOT EXISTS idx_student_achievements_attendance 
        ON student_achievements(attendance_id);
    END IF;
END $$;
