-- Bloque anónimo para manejar la lógica condicional
DO $$
BEGIN
    -- 1. Intentar eliminar el constraint VIEJO si existe
    -- Este es el que causaba problemas porque impedía duplicados por estudiante
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'student_achievements_student_id_achievement_id_key'
        AND table_name = 'student_achievements'
    ) THEN
        ALTER TABLE student_achievements 
        DROP CONSTRAINT student_achievements_student_id_achievement_id_key;
        RAISE NOTICE 'Constraint viejo eliminado exitosamente';
    END IF;

    -- 2. Verificar si el constraint NUEVO ya existe
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'student_achievements_student_achievement_attendance_key'
        AND table_name = 'student_achievements'
    ) THEN
        -- Crear el nuevo constraint si no existe
        ALTER TABLE student_achievements 
        ADD CONSTRAINT student_achievements_student_achievement_attendance_key 
        UNIQUE (student_id, achievement_id, attendance_id);
        RAISE NOTICE 'Nuevo constraint creado exitosamente';
    ELSE
        RAISE NOTICE 'El nuevo constraint ya existía, no se hizo nada';
    END IF;

END $$;
