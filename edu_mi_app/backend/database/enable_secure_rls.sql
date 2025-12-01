-- ================================================================
-- SCRIPT: HABILITAR RLS DE FORMA SEGURA (SIN RECURSIÓN)
-- ================================================================
-- Ejecuta este script para reactivar la seguridad (RLS) en 'profiles'
-- sin que vuelva a aparecer el error de "infinite recursion".

-- 1. Habilitar RLS nuevamente
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 2. Crear funciones "Helper" con SECURITY DEFINER
-- Estas funciones son el TRUCO: se ejecutan con permisos de superusuario,
-- por lo que pueden leer la tabla 'profiles' sin activar las políticas RLS de nuevo.
-- Esto rompe el ciclo infinito.

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS VARCHAR AS $$
BEGIN
    RETURN (SELECT role FROM profiles WHERE user_id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_group_name()
RETURNS VARCHAR AS $$
BEGIN
    RETURN (SELECT group_name FROM profiles WHERE user_id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Limpiar políticas antiguas para evitar conflictos
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "View profiles in same group or admin" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON profiles;
DROP POLICY IF EXISTS "Admins can insert profiles" ON profiles;
DROP POLICY IF EXISTS "Public profiles" ON profiles;

-- 4. Crear las nuevas políticas SEGURAS

-- A) Ver mi propio perfil (Siempre permitido)
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT
    USING (auth.uid() = user_id);

-- B) Ver otros perfiles (Usa las funciones helper para no causar recursión)
CREATE POLICY "View profiles in same group or admin" ON profiles
    FOR SELECT
    USING (
        get_my_role() = 'administrator'
        OR
        (group_name IS NOT NULL AND group_name = get_my_group_name())
    );

-- C) Actualizar mi propio perfil
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE
    USING (auth.uid() = user_id);

-- D) Admin puede actualizar cualquier perfil
CREATE POLICY "Admins can update any profile" ON profiles
    FOR UPDATE
    USING (get_my_role() = 'administrator');

-- E) Admin puede insertar nuevos perfiles
CREATE POLICY "Admins can insert profiles" ON profiles
    FOR INSERT
    WITH CHECK (get_my_role() = 'administrator');

-- ================================================================
-- ¡LISTO! Ahora tienes seguridad activada y sin errores.
-- ================================================================
