-- Script para agregar sistema de heartbeat para detectar desconexiones abruptas
-- Ejecuta este script en el SQL Editor de Supabase

-- Agregar campo last_heartbeat a meeting_participants
ALTER TABLE meeting_participants
ADD COLUMN IF NOT EXISTS last_heartbeat TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Agregar índice para búsquedas por heartbeat
CREATE INDEX IF NOT EXISTS idx_meeting_participants_heartbeat 
ON meeting_participants(last_heartbeat) 
WHERE left_at IS NULL;

-- Comentario documentando el propósito
COMMENT ON COLUMN meeting_participants.last_heartbeat IS 'Último timestamp de actividad del usuario en la llamada. Se usa para detectar desconexiones abruptas (sin click en abandonar)';
