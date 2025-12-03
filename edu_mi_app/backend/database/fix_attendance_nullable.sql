-- Fix attendance table to allow null meeting_id
-- This allows manual attendance recording without a specific meeting

-- Make meeting_id nullable in attendance table
ALTER TABLE attendance 
ALTER COLUMN meeting_id DROP NOT NULL;

-- Add comment explaining the nullable field
COMMENT ON COLUMN attendance.meeting_id IS 'Optional reference to a meeting. Can be null for manual attendance records.';

-- Verify the change
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'attendance' 
  AND column_name = 'meeting_id';
