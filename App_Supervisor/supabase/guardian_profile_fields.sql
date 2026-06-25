-- EduCoParent parent/tutor profiles.
-- This table is separate from public.profiles, which is used by edu_mi_app.
-- Run this in the Supabase SQL Editor before using the parent linking workflow.

CREATE TABLE IF NOT EXISTS public.parent_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  parent_age INTEGER,
  relationship_to_student TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_parent_profiles_email
  ON public.parent_profiles(email);

ALTER TABLE public.parent_profiles ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE ON public.parent_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.parent_profiles TO anon;

DROP POLICY IF EXISTS "Parents can read their own parent profile" ON public.parent_profiles;
CREATE POLICY "Parents can read their own parent profile"
  ON public.parent_profiles FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Parents can insert their own parent profile" ON public.parent_profiles;
CREATE POLICY "Parents can insert their own parent profile"
  ON public.parent_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Parents can update their own parent profile" ON public.parent_profiles;
CREATE POLICY "Parents can update their own parent profile"
  ON public.parent_profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

COMMENT ON TABLE public.parent_profiles IS
  'EduCoParent-only profile data for parents, guardians, and legal tutors.';

COMMENT ON COLUMN public.parent_profiles.relationship_to_student IS
  'Relationship to the student: madre, padre, tutor, otro_familiar, responsable_legal.';

NOTIFY pgrst, 'reload schema';
