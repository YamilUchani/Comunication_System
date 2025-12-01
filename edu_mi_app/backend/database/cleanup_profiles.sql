-- ================================================================
-- SCRIPT: LIMPIAR Y OPTIMIZAR TABLA PROFILES
-- ================================================================
-- Este script elimina columnas obsoletas y agrega columnas necesarias

-- 1. Eliminar columna obsoleta 'isteacher' (reemplazada por 'role')
ALTER TABLE profiles DROP COLUMN IF EXISTS isteacher;

-- 2. Agregar columna 'email' si no existe (necesaria para mostrar en admin)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- 3. Poblar email desde auth.users si está vacío
UPDATE profiles
SET email = (
    SELECT email 
    FROM auth.users 
    WHERE auth.users.id = profiles.user_id
)
WHERE profiles.email IS NULL OR profiles.email = '';

-- 4. Eliminar columna duplicada 'Group_Class' (usar solo 'group_name')
ALTER TABLE profiles DROP COLUMN IF EXISTS "Group_Class";

-- 5. Asegurar que user_id sea único
CREATE UNIQUE INDEX IF NOT EXISTS profiles_user_id_unique ON profiles(user_id);

-- 6. Comentarios para documentación
COMMENT ON COLUMN profiles.group_name IS 'Nombre del grupo al que pertenece el usuario (ej: manzanas, peras)';
COMMENT ON COLUMN profiles.role IS 'Rol del usuario: student, teacher, o administrator';
COMMENT ON COLUMN profiles.email IS 'Email del usuario (copiado de auth.users)';
