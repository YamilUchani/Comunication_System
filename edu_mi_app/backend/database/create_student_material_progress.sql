-- Tabla de progreso por estudiante y material
CREATE TABLE IF NOT EXISTS student_material_progress (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    material_id UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
    student_id UUID NOT NULL,
    status VARCHAR(20) DEFAULT 'disabled' NOT NULL,  -- 'disabled' | 'active' | 'achieved'
    updated_by UUID,                                  -- quien lo cambio (el maestro)
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(material_id, student_id)
);

ALTER TABLE student_material_progress ENABLE ROW LEVEL SECURITY;

-- Estudiantes: pueden leer su propio progreso
CREATE POLICY "Students read own progress" ON student_material_progress
    FOR SELECT USING (student_id = auth.uid());

-- Maestros y admins: pueden leer y escribir todo
CREATE POLICY "Teachers manage progress" ON student_material_progress
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.user_id = auth.uid()
            AND profiles.role IN ('teacher', 'administrator')
        )
    );

-- Eliminar la columna status de materials si existe (ya no la necesitamos)
ALTER TABLE materials DROP COLUMN IF EXISTS status;
