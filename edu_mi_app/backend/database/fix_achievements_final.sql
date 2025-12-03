-- Script DEFINITIVO para arreglar los constraints de logros
-- Ejecuta esto en el Editor SQL de Supabase

DO $$
BEGIN
    -- 1. Borrar explícitamente ambos constraints posibles (el viejo y el nuevo) para empezar de cero
    -- Usamos CASCADE para asegurar que se borren dependencias si las hay
    
    -- Borrar el constraint viejo (si existe)
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'student_achievements_student_id_achievement_id_key') THEN
        ALTER TABLE student_achievements DROP CONSTRAINT student_achievements_student_id_achievement_id_key;
    END IF;

    -- Borrar el constraint nuevo (si existe, para recrearlo limpio)
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'student_achievements_student_achievement_attendance_key') THEN
        ALTER TABLE student_achievements DROP CONSTRAINT student_achievements_student_achievement_attendance_key;
    END IF;

    -- 2. Crear el constraint correcto
    ALTER TABLE student_achievements 
    ADD CONSTRAINT student_achievements_student_achievement_attendance_key 
    UNIQUE (student_id, achievement_id, attendance_id);

    RAISE NOTICE '✅ Base de datos reparada exitosamente. Constraints actualizados.';
END $$;
