-- Script para limpiar reuniones antiguas/inactivas
-- Ejecuta esto en Supabase SQL Editor

-- 1. Ver todas las reuniones inactivas
SELECT 
    id,
    title,
    channel_name,
    created_at,
    is_active
FROM meetings
WHERE is_active = false
ORDER BY created_at DESC;

-- 2. Eliminar todas las reuniones inactivas
DELETE FROM meetings
WHERE is_active = false;

-- 3. Ver cuántas reuniones quedan
SELECT 
    COUNT(*) as total_meetings,
    COUNT(*) FILTER (WHERE is_active = true) as active_meetings,
    COUNT(*) FILTER (WHERE is_active = false) as inactive_meetings
FROM meetings;
