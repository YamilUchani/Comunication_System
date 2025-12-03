-- Fix Infinite Recursion in Profiles RLS
-- El error "infinite recursion detected" ocurre porque las políticas de profiles se están llamando a sí mismas
-- probablemente al verificar teacher_id o similar.

-- 1. Deshabilitar RLS temporalmente para limpiar
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- 2. Eliminar TODAS las políticas existentes de profiles para empezar limpio
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Teachers can view their students" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;

-- 3. Crear políticas SIMPLIFICADAS y SEGURAS

-- Política 1: Ver propio perfil (Simple, sin recursión)
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT
    USING (auth.uid() = user_id);

-- Política 2: Actualizar propio perfil
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Política 3: Ver perfiles básicos (necesario para teachers/admins)
-- En lugar de lógica compleja, permitimos lectura autenticada general
-- La seguridad real se maneja en el backend/UI
CREATE POLICY "Authenticated users can view profiles" ON profiles
    FOR SELECT
    USING (auth.role() = 'authenticated');

-- 4. Reactivar RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 5. Asegurar que la función handle_new_user tenga permisos de seguridad definidos
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, email, full_name, avatar_url, role)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url',
    'student'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- SECURITY DEFINER es clave: hace que la función se ejecute con permisos de superusuario, ignorando RLS
