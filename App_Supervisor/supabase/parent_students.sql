-- Parent_Students Junction Table
-- Links parent accounts (auth.users) to student profiles (profiles)
-- Ejecuta esto en el SQL Editor de Supabase (https://supabase.com/dashboard/project/tcbmlktpzshltvmoirjs/sql/new)

CREATE TABLE IF NOT EXISTS public.parent_students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  UNIQUE(parent_id, student_id)
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_parent_students_parent ON public.parent_students(parent_id);
CREATE INDEX IF NOT EXISTS idx_parent_students_student ON public.parent_students(student_id);

-- RLS (opcional cuando actives RLS)
ALTER TABLE public.parent_students ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Parents can view their own links"
  ON public.parent_students FOR SELECT
  USING (auth.uid() = parent_id);

-- ═══════════════════════════════════════════════
-- CÓMO VINCULAR UN PADRE A SUS HIJOS:
-- ═══════════════════════════════════════════════
-- OPCIÓN A: Desde el panel de Administrador (edu_mi_app)
--   1. Ve al Panel de Administrador en edu_mi_app
--   2. Busca la sección "Vinculación Padres-Hijos"
--   3. Si el padre no aparece, asígnale el rol "parent" desde Gestión de Usuarios
--   4. Haz clic en "Vincular Estudiante" y busca al hijo por nombre
--   5. Repite para cada hijo
--
-- OPCIÓN B: Manualmente (SQL)
-- 1. Obtén el ID del padre (de auth.users o profiles):
--    SELECT user_id, email, full_name FROM profiles WHERE email = 'padre@ejemplo.com';
--
-- 2. Obtén el ID del estudiante:
--    SELECT user_id, full_name, email FROM profiles WHERE full_name = 'Damian Agramont';
--
-- 3. Inserta la relación:
--    INSERT INTO parent_students (parent_id, student_id)
--    VALUES ('UUID-del-padre', 'UUID-del-estudiante');
--
-- 4. Para vincular múltiples hijos, repite el INSERT:
--    INSERT INTO parent_students (parent_id, student_id) VALUES
--    ('UUID-del-padre', 'UUID-hijo-1'),
--    ('UUID-del-padre', 'UUID-hijo-2');
--
-- 5. Verifica:
--    SELECT p.full_name AS padre, s.full_name AS hijo
--    FROM parent_students ps
--    JOIN profiles p ON p.user_id = ps.parent_id
--    JOIN profiles s ON s.user_id = ps.student_id;
