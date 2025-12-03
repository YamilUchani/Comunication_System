-- Script para limpiar registros duplicados de asistencia
-- Ejecuta esto en Supabase SQL Editor

-- 1. Ver cuántos duplicados hay
SELECT 
    user_id, 
    meeting_date, 
    COUNT(*) as count
FROM attendance
GROUP BY user_id, meeting_date
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- 2. Eliminar duplicados, manteniendo solo el más reciente
WITH duplicates AS (
    SELECT 
        id,
        ROW_NUMBER() OVER (
            PARTITION BY user_id, meeting_date 
            ORDER BY joined_at DESC
        ) as rn
    FROM attendance
)
DELETE FROM attendance
WHERE id IN (
    SELECT id FROM duplicates WHERE rn > 1
);

-- 3. Agregar constraint UNIQUE para prevenir futuros duplicados
ALTER TABLE attendance 
ADD CONSTRAINT attendance_user_date_unique 
UNIQUE (user_id, meeting_date);

-- 4. Verificar que no quedan duplicados
SELECT 
    user_id, 
    meeting_date, 
    COUNT(*) as count
FROM attendance
GROUP BY user_id, meeting_date
HAVING COUNT(*) > 1;
