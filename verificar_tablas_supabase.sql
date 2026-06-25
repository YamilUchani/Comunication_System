-- ═══════════════════════════════════════════════════════════════════
-- VERIFICACIÓN DE TABLAS EN SUPABASE
-- Compara las tablas que existen en Supabase vs las que se usan en el código
-- Ejecuta esto en el SQL Editor de Supabase:
-- https://supabase.com/dashboard/project/tcbmlktpzshltvmoirjs/sql/new
-- ═══════════════════════════════════════════════════════════════════

-- 1. Listar TODAS las tablas existentes en el schema 'public'
SELECT 
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- ═══════════════════════════════════════════════════════════════════
-- 2. VERIFICAR TABLAS ESPERADAS vs EXISTENTES
-- ═══════════════════════════════════════════════════════════════════

-- Tablas definidas en schema.sql (App_Supervisor)
WITH expected_tables AS (
    SELECT 'profiles' AS table_name UNION ALL
    SELECT 'students' UNION ALL
    SELECT 'teachers' UNION ALL
    SELECT 'grades' UNION ALL
    SELECT 'tasks' UNION ALL
    SELECT 'chats' UNION ALL
    SELECT 'calendar_events' UNION ALL
    SELECT 'alerts' UNION ALL
    -- Tablas de complete_setup.sql
    SELECT 'parent_students' UNION ALL
    -- Tablas usadas en edu_mi_app (Dart/Flutter)
    SELECT 'groups' UNION ALL
    SELECT 'materials' UNION ALL
    SELECT 'student_material_progress' UNION ALL
    SELECT 'student_level_progress' UNION ALL
    SELECT 'student_achievements' UNION ALL
    SELECT 'achievements' UNION ALL
    SELECT 'meetings' UNION ALL
    SELECT 'meeting_participants' UNION ALL
    SELECT 'session_participants' UNION ALL
    SELECT 'class_schedules' UNION ALL
    SELECT 'attendance' UNION ALL
    SELECT 'notifications'
),
existing_tables AS (
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
)
SELECT 
    e.table_name AS tabla_esperada,
    CASE WHEN x.table_name IS NOT NULL THEN '✅ EXISTE' ELSE '❌ FALTA' END AS estado
FROM expected_tables e
LEFT JOIN existing_tables x ON e.table_name = x.table_name
ORDER BY e.table_name;

-- ═══════════════════════════════════════════════════════════════════
-- 3. VERIFICAR COLUMNAS DE TABLAS CRÍTICAS
-- ═══════════════════════════════════════════════════════════════════

-- Verificar columnas de la tabla 'profiles'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'profiles'
ORDER BY ordinal_position;

-- Verificar columnas de la tabla 'meetings'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'meetings'
ORDER BY ordinal_position;

-- Verificar columnas de la tabla 'meeting_participants'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'meeting_participants'
ORDER BY ordinal_position;

-- Verificar columnas de la tabla 'student_achievements'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'student_achievements'
ORDER BY ordinal_position;

-- Verificar columnas de la tabla 'materials'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'materials'
ORDER BY ordinal_position;

-- Verificar columnas de la tabla 'student_material_progress'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'student_material_progress'
ORDER BY ordinal_position;

-- Verificar columnas de la tabla 'session_participants'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'session_participants'
ORDER BY ordinal_position;

-- Verificar columnas de la tabla 'class_schedules'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'class_schedules'
ORDER BY ordinal_position;

-- Verificar columnas de la tabla 'attendance'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'attendance'
ORDER BY ordinal_position;

-- Verificar columnas de la tabla 'notifications'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'notifications'
ORDER BY ordinal_position;

-- Verificar columnas de la tabla 'groups'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'groups'
ORDER BY ordinal_position;

-- Verificar columnas de la tabla 'achievements'
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'achievements'
ORDER BY ordinal_position;

-- ═══════════════════════════════════════════════════════════════════
-- 4. VERIFICAR STORAGE BUCKETS (para materiales)
-- ═══════════════════════════════════════════════════════════════════

SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
ORDER BY name;

-- ═══════════════════════════════════════════════════════════════════
-- 5. RESUMEN DE FALTANTES
-- ═══════════════════════════════════════════════════════════════════

-- Contar cuántas tablas faltan
WITH expected_tables AS (
    SELECT 'profiles' AS table_name UNION ALL
    SELECT 'students' UNION ALL
    SELECT 'teachers' UNION ALL
    SELECT 'grades' UNION ALL
    SELECT 'tasks' UNION ALL
    SELECT 'chats' UNION ALL
    SELECT 'calendar_events' UNION ALL
    SELECT 'alerts' UNION ALL
    SELECT 'parent_students' UNION ALL
    SELECT 'groups' UNION ALL
    SELECT 'materials' UNION ALL
    SELECT 'student_material_progress' UNION ALL
    SELECT 'student_level_progress' UNION ALL
    SELECT 'student_achievements' UNION ALL
    SELECT 'achievements' UNION ALL
    SELECT 'meetings' UNION ALL
    SELECT 'meeting_participants' UNION ALL
    SELECT 'session_participants' UNION ALL
    SELECT 'class_schedules' UNION ALL
    SELECT 'attendance' UNION ALL
    SELECT 'notifications'
),
existing_tables AS (
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
),
missing AS (
    SELECT e.table_name
    FROM expected_tables e
    LEFT JOIN existing_tables x ON e.table_name = x.table_name
    WHERE x.table_name IS NULL
)
SELECT 
    COUNT(*) AS tablas_faltantes,
    array_agg(table_name ORDER BY table_name) AS nombres_tablas_faltantes
FROM missing;