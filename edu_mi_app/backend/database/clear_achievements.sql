-- Script para borrar todos los logros de los estudiantes
-- Ejecuta esto en el Editor SQL de Supabase para limpiar los datos de prueba

-- Borrar todos los registros de student_achievements
DELETE FROM student_achievements;

-- Verificar que se borraron todos
SELECT COUNT(*) as total_achievements FROM student_achievements;

-- Esto debería retornar 0 si se borraron correctamente
