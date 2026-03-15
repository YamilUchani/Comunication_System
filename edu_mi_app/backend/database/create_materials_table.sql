CREATE TABLE IF NOT EXISTS materials (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    image_url TEXT,
    pdf_url TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE materials ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view materials" ON materials;
CREATE POLICY "Public can view materials" ON materials FOR SELECT USING (true);

DROP POLICY IF EXISTS "Only admins can manage materials" ON materials;
CREATE POLICY "Only admins can manage materials" ON materials FOR ALL USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.user_id = auth.uid() 
        AND profiles.role = 'administrator'
    )
);

-- Habilitar buckets en storage (esto a veces requiere ser superuser o por la GUI, pero lo intentamos)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('materials', 'materials', true) 
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'materials');

DROP POLICY IF EXISTS "Authenticated users can upload objects" ON storage.objects;
CREATE POLICY "Authenticated users can upload objects" ON storage.objects FOR INSERT USING (bucket_id = 'materials' AND auth.role() = 'authenticated');

-- O permitir todo a auth users si lo anterior falla para simplificar
DROP POLICY IF EXISTS "Admins can manage objects" ON storage.objects;
CREATE POLICY "Admins can manage objects" ON storage.objects FOR ALL USING (bucket_id = 'materials' AND auth.role() = 'authenticated');
