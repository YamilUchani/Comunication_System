-- =====================================================
-- Script: Agregar columna de estado a la tabla attendance
-- Descripción: Agrega columna 'status' para rastrear 
--              "inactive", "present" (en sala de espera), "in_call"
-- =====================================================

-- 1. Agregar columna 'status' a la tabla attendance
ALTER TABLE attendance 
ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'inactive' CHECK (status IN ('inactive', 'present', 'in_call'));

-- 2. Crear índice para optimizar búsquedas por estado
CREATE INDEX IF NOT EXISTS idx_attendance_status ON attendance(status);

-- 3. Comentario para documentación
COMMENT ON COLUMN attendance.status IS 'Estado del estudiante: inactive (no conectado), present (en sala de espera), in_call (en videollamada)';

-- =====================================================
-- Nota: 
-- - inactive: El estudiante no está en sala de espera ni en videollamada
-- - present: El estudiante está en la sala de espera
-- - in_call: El estudiante está en la videollamada
-- =====================================================
