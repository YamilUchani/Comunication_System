-- Eliminar el constraint único actual que impide múltiples logros por estudiante
ALTER TABLE student_achievements 
DROP CONSTRAINT IF EXISTS student_achievements_student_id_achievement_id_key;

-- Crear nuevo constraint único que incluye attendance_id
-- Esto permite que un estudiante tenga el mismo logro en diferentes fechas
ALTER TABLE student_achievements 
ADD CONSTRAINT student_achievements_student_achievement_attendance_key 
UNIQUE (student_id, achievement_id, attendance_id);
