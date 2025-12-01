-- ================================================================
-- SCRIPT DE CORRECCIÓN: RECURSIÓN INFINITA EN PROFILES
-- ================================================================
-- Este script soluciona el error "infinite recursion detected"
-- reemplazando las políticas recursivas con funciones seguras.

-- 1. Función segura para obtener el ROL del usuario actual
-- (Bypasea RLS para evitar recursión al consultar el propio rol)
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS VARCHAR AS $$
BEGIN
    RETURN (SELECT role FROM profiles WHERE user_id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Función segura para obtener el GRUPO del usuario actual
-- (Bypasea RLS para evitar recursión al consultar el propio grupo)
CREATE OR REPLACE FUNCTION get_my_group_name()
RETURNS VARCHAR AS $$
BEGIN
    RETURN (SELECT group_name FROM profiles WHERE user_id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Eliminar TODAS las políticas existentes en profiles para limpiar
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "View profiles in same group" ON profiles;
DROP POLICY IF EXISTS "Users can view profiles in their group" ON profiles;
DROP POLICY IF EXISTS "Teachers can view their group" ON profiles;

-- 4. Recrear políticas usando las funciones seguras

-- A) Ver mi propio perfil (Siempre permitido)
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT
    USING (auth.uid() = user_id);

-- B) Ver perfiles del mismo grupo O si soy administrador
-- Esta era la causante de la recursión. Ahora usa funciones seguras.
CREATE POLICY "View profiles in same group or admin" ON profiles
    FOR SELECT
    USING (
        -- Si soy el dueño (ya cubierto, pero redundancia segura)
        auth.uid() = user_id
        OR
        -- Si soy administrador
        get_my_role() = 'administrator'
        OR
        -- Si el perfil que veo está en mi mismo grupo (y no es null)
        (group_name IS NOT NULL AND group_name = get_my_group_name())
    );

-- C) Actualizar mi propio perfil
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE
    USING (auth.uid() = user_id);

-- D) Administradores pueden actualizar cualquier perfil
CREATE POLICY "Admins can update any profile" ON profiles
    FOR UPDATE
    USING (get_my_role() = 'administrator');

-- E) Inserción (generalmente manejada por triggers de auth, pero por si acaso)
CREATE POLICY "Admins can insert profiles" ON profiles
    FOR INSERT
    WITH CHECK (get_my_role() = 'administrator');

-- ================================================================
-- Fin del script
-- ================================================================
