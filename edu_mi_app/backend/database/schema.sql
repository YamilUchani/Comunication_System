-- Script SQL para crear las tablas necesarias en Supabase
-- Ejecuta este script en el SQL Editor de Supabase

-- Tabla de reuniones
CREATE TABLE IF NOT EXISTS meetings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  channel_name VARCHAR(64) NOT NULL UNIQUE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  ended_at TIMESTAMP WITH TIME ZONE,
  
  CONSTRAINT valid_channel_name CHECK (char_length(channel_name) >= 1 AND char_length(channel_name) <= 64)
);

-- Tabla de participantes de reuniones
CREATE TABLE IF NOT EXISTS meeting_participants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  left_at TIMESTAMP WITH TIME ZONE,
  
  UNIQUE(meeting_id, user_id)
);

-- Índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_meetings_channel ON meetings(channel_name);
CREATE INDEX IF NOT EXISTS idx_meetings_active ON meetings(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_meetings_creator ON meetings(creator_id);
CREATE INDEX IF NOT EXISTS idx_meeting_participants_meeting ON meeting_participants(meeting_id);
CREATE INDEX IF NOT EXISTS idx_meeting_participants_user ON meeting_participants(user_id);

-- Agregar campos opcionales a la tabla profiles si no existen
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS can_create_meetings BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS meeting_limit INTEGER DEFAULT NULL;

-- Row Level Security (RLS) policies

-- Habilitar RLS
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE meeting_participants ENABLE ROW LEVEL SECURITY;

-- Políticas para meetings
-- Todos pueden ver reuniones activas
CREATE POLICY "Reuniones activas son públicas" ON meetings
  FOR SELECT
  USING (is_active = true);

-- Solo usuarios autenticados pueden crear reuniones
CREATE POLICY "Usuarios autenticados pueden crear reuniones" ON meetings
  FOR INSERT
  WITH CHECK (auth.uid() = creator_id);

-- Solo el creador puede actualizar/eliminar su reunión
CREATE POLICY "Creadores pueden actualizar sus reuniones" ON meetings
  FOR UPDATE
  USING (auth.uid() = creator_id);

CREATE POLICY "Creadores pueden eliminar sus reuniones" ON meetings
  FOR DELETE
  USING (auth.uid() = creator_id);

-- Políticas para meeting_participants
-- Los participantes pueden ver sus propias participaciones
CREATE POLICY "Usuarios pueden ver sus participaciones" ON meeting_participants
  FOR SELECT
  USING (auth.uid() = user_id);

-- Usuarios pueden unirse a reuniones
CREATE POLICY "Usuarios pueden unirse a reuniones" ON meeting_participants
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Usuarios pueden actualizar sus propias participaciones
CREATE POLICY "Usuarios pueden actualizar sus participaciones" ON meeting_participants
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Función para limpiar reuniones expiradas automáticamente
CREATE OR REPLACE FUNCTION cleanup_expired_meetings()
RETURNS void AS $$
BEGIN
  UPDATE meetings
  SET is_active = false
  WHERE is_active = true 
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comentarios para documentación
COMMENT ON TABLE meetings IS 'Almacena información de reuniones de video';
COMMENT ON TABLE meeting_participants IS 'Registra los participantes de cada reunión';
COMMENT ON COLUMN profiles.can_create_meetings IS 'Indica si el usuario tiene permisos para crear reuniones';
COMMENT ON COLUMN profiles.meeting_limit IS 'Límite de reuniones activas simultáneas (NULL = sin límite)';
