-- ================================================================
-- SCRIPT DE FUERZA BRUTA: ARREGLAR PERFILES DEFINITIVAMENTE
-- ================================================================
-- Este script elimina TODAS las políticas de la tabla profiles
-- y las vuelve a crear de forma limpia y segura.

-- 1. Deshabilitar RLS temporalmente para limpiar sin bloqueos
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- 2. Eliminar TODAS las políticas posibles (viejas y nuevas)
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "View profiles in same group" ON profiles;
DROP POLICY IF EXISTS "Users can view profiles in their group" ON profiles;
DROP POLICY IF EXISTS "Teachers can view their group" ON profiles;
DROP POLICY IF EXISTS "View profiles in same group or admin" ON profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON profiles;
DROP POLICY IF EXISTS "Admins can insert profiles" ON profiles;
DROP POLICY IF EXISTS "Public profiles" ON profiles;

-- 3. Recrear funciones de seguridad (SECURITY DEFINER es CLAVE)
-- Estas funciones se ejecutan como admin, ignorando RLS, para evitar el bucle.

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

-- 4. Habilitar RLS de nuevo
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 5. Crear políticas limpias

-- A) Ver mi propio perfil (Simple, sin recursión)
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT
    USING (auth.uid() = user_id);

-- B) Ver perfiles del mismo grupo O si soy admin (Usa las funciones seguras)
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

-- D) Admin puede actualizar todo
CREATE POLICY "Admins can update any profile" ON profiles
    FOR UPDATE
    USING (get_my_role() = 'administrator');

-- E) Admin puede insertar
CREATE POLICY "Admins can insert profiles" ON profiles
    FOR INSERT
    WITH CHECK (get_my_role() = 'administrator');

-- ================================================================
-- Fin del script
-- ================================================================
