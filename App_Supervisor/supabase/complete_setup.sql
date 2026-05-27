-- ═══════════════════════════════════════════════════════════════════
-- COMPLETE SUPABASE SETUP — App_Supervisor (Padres)
-- Ejecuta TODO esto en el SQL Editor de Supabase:
-- https://supabase.com/dashboard/project/tcbmlktpzshltvmoirjs/sql/new
-- ═══════════════════════════════════════════════════════════════════

-- ==========================================
-- 1. Asegurar columna role en profiles
-- ==========================================
ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'student';

-- ==========================================
-- 2. Crear tabla parent_students (puente)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.parent_students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  UNIQUE(parent_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_parent_students_parent ON public.parent_students(parent_id);
CREATE INDEX IF NOT EXISTS idx_parent_students_student ON public.parent_students(student_id);

-- ==========================================
-- 3. RLS en parent_students
-- ==========================================
ALTER TABLE public.parent_students ENABLE ROW LEVEL SECURITY;

-- Los padres pueden ver sus propios vínculos
DROP POLICY IF EXISTS "Parents can view their own links" ON public.parent_students;
CREATE POLICY "Parents can view their own links"
  ON public.parent_students FOR SELECT
  USING (auth.uid() = parent_id);

-- El admin usa service_role key, estas policies no lo afectan
DROP POLICY IF EXISTS "Admins can manage parent_students" ON public.parent_students;
CREATE POLICY "Admins can manage parent_students"
  ON public.parent_students FOR ALL
  USING (auth.role() = 'service_role');

-- ==========================================
-- 4. RLS en profiles (para que al leer no
--    necesitemos la service_role key)
-- ==========================================
-- Solo agregar si NO existen ya policies más permisivas
-- (Si ya tenés RLS deshabilitado en profiles, podés saltarte esto)

-- Permitir que cualquiera autenticado pueda leer profiles
-- (necesario para que App_Supervisor pueda buscar estudiantes)
DROP POLICY IF EXISTS "Anyone can read profiles" ON public.profiles;
CREATE POLICY "Anyone can read profiles"
  ON public.profiles FOR SELECT
  USING (auth.role() = 'authenticated');

-- ==========================================
-- 5. VERIFICACIÓN RÁPIDA
-- ==========================================
-- Después de ejecutar, corré esto para verificar:
--   SELECT table_name FROM information_schema.tables
--   WHERE table_schema = 'public'
--   AND table_name IN ('profiles','parent_students');
--
-- Para ver los padres registrados:
--   SELECT id, email, full_name, role FROM profiles WHERE role = 'parent';
--
-- Para ver vínculos existentes:
--   SELECT * FROM parent_students;

-- ═══════════════════════════════════════════════════════════════════
-- CONFIGURACIÓN EN SUPABASE DASHBOARD (interfaz web)
-- ═══════════════════════════════════════════════════════════════════

-- A) AGREGAR URL DE GITHUB PAGES A REDIRECT URLS
--    1. Ve a Authentication → Settings
--    2. En "Redirect URLs" agregá:
--       https://yamiluchani.github.io/Comunication_System/**
--    3. Guardá

-- B) HABILITAR GOOGLE OAUTH
--    1. Ve a Authentication → Providers → Google
--    2. Activá "Enable Sign in with Google"
--    3. Client ID y Client Secret:
--       a. Ve a https://console.cloud.google.com/apis/credentials
--       b. Creá un proyecto o usá uno existente
--       c. Creá una "OAuth 2.0 Client ID" (tipo "Web application")
--       d. Agregá como URI de redirección autorizada:
--          https://tcbmlktpzshltvmoirjs.supabase.co/auth/v1/callback
--       e. Copiá Client ID y Client Secret a Supabase
--    4. Guardá

-- C) (OPCIONAL) SACAR CONFIRMACIÓN DE EMAIL
--    Si querés que los padres puedan registrarse SIN confirmar email:
--    1. Authentication → Settings
--    2. "Confirm email" → OFF
--    3. "Secure email password change" → OFF

-- ═══════════════════════════════════════════════════════════════════
-- FLUJO DE USO
-- ═══════════════════════════════════════════════════════════════════
-- 1. Padre abre App_Supervisor → ve modal de login
-- 2. Padre puede: a) Registrarse con email+password
--                 b) Registrarse/Entrar con Google
-- 3. Al registrarse se crea profile con role='parent'
-- 4. Admin (en edu_mi_app) va a "Vinculación Padres-Hijos"
--    y vincula al padre con sus hijos
-- 5. Padre vuelve a App_Supervisor, inicia sesión
--    y ve SOLO los estudiantes vinculados
