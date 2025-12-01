-- ============================================
-- FIX: Asegurar que profiles.user_id sea único
-- ============================================
-- Ejecutar este script ANTES de educational_roles.sql

-- Verificar estructura actual de profiles
-- Si la tabla existe pero user_id no es PRIMARY KEY, lo arreglamos

-- Opción 1: Si profiles no tiene PK en user_id, agregarlo
DO $$
BEGIN
    -- Intentar agregar constraint único en user_id si no existe
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'profiles_user_id_key'
    ) THEN
        ALTER TABLE profiles ADD CONSTRAINT profiles_user_id_key UNIQUE (user_id);
    END IF;
END $$;

-- Verificar que funcionó
SELECT 
    table_name,
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'profiles'
  AND constraint_type = 'UNIQUE';
