-- ═══════════════════════════════════════════════════════════════════
-- COMPLETAR PARENT PROFILES + POLÍTICAS PARA ADMIN
-- 
-- Problema: El admin no puede leer parent_profiles porque las RLS
-- solo permiten que cada padre lea su propio perfil.
-- 
-- SOLUCIÓN: Agregar políticas que permitan a usuarios con rol
-- 'administrator' leer/escribir TODOS los registros.
--
-- Además se agregan columnas útiles faltantes.
--
-- Ejecuta esto en el SQL Editor de Supabase:
-- https://supabase.com/dashboard/project/tcbmlktpzshltvmoirjs/sql/new
-- ═══════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 1. AGREGAR COLUMNAS FALTANTES A parent_profiles
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.parent_profiles 
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS preferred_language TEXT DEFAULT 'es',
  ADD COLUMN IF NOT EXISTS notification_preferences JSONB DEFAULT '{"email": true, "push": true, "sms": false}'::jsonb;

COMMENT ON COLUMN public.parent_profiles.phone IS 'Número de teléfono del padre/tutor';
COMMENT ON COLUMN public.parent_profiles.address IS 'Dirección de residencia';
COMMENT ON COLUMN public.parent_profiles.is_active IS 'Si la cuenta del padre está activa';
COMMENT ON COLUMN public.parent_profiles.preferred_language IS 'Idioma preferido (es, en, etc.)';
COMMENT ON COLUMN public.parent_profiles.notification_preferences IS 'Preferencias de notificación en JSON';

-- ═══════════════════════════════════════════════════════════════════
-- 2. ÍNDICES ADICIONALES
-- ═══════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_parent_profiles_is_active
  ON public.parent_profiles(is_active);

CREATE INDEX IF NOT EXISTS idx_parent_profiles_phone
  ON public.parent_profiles(phone);

-- ═══════════════════════════════════════════════════════════════════
-- 3. POLÍTICAS RLS PARA ADMINISTRADORES EN parent_profiles
-- ═══════════════════════════════════════════════════════════════════
-- Nota: Las políticas existentes ya permiten a padres leer su propio perfil.
-- Estas nuevas políticas permiten a los administradores del sistema
-- gestionar TODOS los perfiles de padres.

DROP POLICY IF EXISTS "Admins can read all parent profiles" ON public.parent_profiles;
CREATE POLICY "Admins can read all parent profiles"
  ON public.parent_profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.user_id = auth.uid()
      AND profiles.role = 'administrator'
    )
  );

DROP POLICY IF EXISTS "Admins can insert parent profiles" ON public.parent_profiles;
CREATE POLICY "Admins can insert parent profiles"
  ON public.parent_profiles FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.user_id = auth.uid()
      AND profiles.role = 'administrator'
    )
  );

DROP POLICY IF EXISTS "Admins can update all parent profiles" ON public.parent_profiles;
CREATE POLICY "Admins can update all parent profiles"
  ON public.parent_profiles FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.user_id = auth.uid()
      AND profiles.role = 'administrator'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.user_id = auth.uid()
      AND profiles.role = 'administrator'
    )
  );

DROP POLICY IF EXISTS "Admins can delete parent profiles" ON public.parent_profiles;
CREATE POLICY "Admins can delete parent profiles"
  ON public.parent_profiles FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.user_id = auth.uid()
      AND profiles.role = 'administrator'
    )
  );

-- ═══════════════════════════════════════════════════════════════════
-- 4. POLÍTICAS RLS PARA ADMINISTRADORES EN parent_students
-- ═══════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "Admins can read all parent_student links" ON public.parent_students;
CREATE POLICY "Admins can read all parent_student links"
  ON public.parent_students FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.user_id = auth.uid()
      AND profiles.role = 'administrator'
    )
  );

DROP POLICY IF EXISTS "Admins can insert parent_student links" ON public.parent_students;
CREATE POLICY "Admins can insert parent_student links"
  ON public.parent_students FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.user_id = auth.uid()
      AND profiles.role = 'administrator'
    )
  );

DROP POLICY IF EXISTS "Admins can delete parent_student links" ON public.parent_students;
CREATE POLICY "Admins can delete parent_student links"
  ON public.parent_students FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.user_id = auth.uid()
      AND profiles.role = 'administrator'
    )
  );

-- ═══════════════════════════════════════════════════════════════════
-- 5. FUNCIÓN: AUTO-CREAR PARENT PROFILE AL REGISTRARSE
--    (Opcional: si un usuario se registra como parent desde la app)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_parent_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.parent_profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email)
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Trigger: cuando se crea un usuario en auth.users, si tiene role=parent,
-- se crea automáticamente su perfil en parent_profiles
-- NOTA: Descomenta las siguientes líneas si quieres activar esta función:
--
-- CREATE OR REPLACE TRIGGER on_auth_user_created_parent_profile
--   AFTER INSERT ON auth.users
--   FOR EACH ROW
--   WHEN (NEW.raw_user_meta_data->>'role' = 'parent')
--   EXECUTE FUNCTION public.handle_new_parent_profile();

-- ═══════════════════════════════════════════════════════════════════
-- 6. ACTUALIZAR updated_at AUTOMÁTICAMENTE
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.update_parent_profiles_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc'::text, NOW());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_parent_profiles_updated_at ON public.parent_profiles;
CREATE TRIGGER set_parent_profiles_updated_at
  BEFORE UPDATE ON public.parent_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_parent_profiles_updated_at();

-- ═══════════════════════════════════════════════════════════════════
-- 7. VERIFICACIÓN
-- ═══════════════════════════════════════════════════════════════════

-- Verificar columnas de parent_profiles
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'parent_profiles'
ORDER BY ordinal_position;

-- Verificar políticas de parent_profiles
SELECT 
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'parent_profiles'
ORDER BY policyname;

-- Verificar políticas de parent_students
SELECT 
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'parent_students'
ORDER BY policyname;

-- Notificar a PostgREST para recargar schema
NOTIFY pgrst, 'reload schema';