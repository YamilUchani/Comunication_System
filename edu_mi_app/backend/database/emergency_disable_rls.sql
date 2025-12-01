-- ================================================================
-- SCRIPT DE EMERGENCIA: DESHABILITAR RLS EN PROFILES
-- ================================================================
-- Este script desactiva temporalmente la seguridad a nivel de fila
-- en la tabla 'profiles' para permitir el inicio de sesión.
-- Una vez que confirmemos que el login funciona, podremos reactivarla
-- con una política simplificada.

ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- También aseguramos que el usuario pueda leer su propio perfil sin restricciones
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "View profiles in same group or admin" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON profiles;

-- (Opcional) Si quieres reactivarla más tarde con una regla MÍNIMA:
-- ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow read own profile" ON profiles FOR SELECT USING (auth.uid() = user_id);
