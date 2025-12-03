-- Desactivar RLS en profiles para solucionar error de recursión infinita
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Asegurar que el trigger de creación de usuario siga funcionando
-- (El trigger usa SECURITY DEFINER así que funcionará igual)
