-- ================================================================
-- SCRIPT: AGREGAR COLUMNAS DE FILTRO A LA TABLA MEETINGS
-- ================================================================
-- Este script agrega las columnas necesarias para filtrar reuniones
-- por grupo o usuario específico.

ALTER TABLE meetings 
ADD COLUMN IF NOT EXISTS allowed_groups TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS allowed_users UUID[] DEFAULT '{}';

-- Comentario para documentación
COMMENT ON COLUMN meetings.allowed_groups IS 'Array de nombres de grupos permitidos en esta reunión';
COMMENT ON COLUMN meetings.allowed_users IS 'Array de IDs de usuarios permitidos en esta reunión';
