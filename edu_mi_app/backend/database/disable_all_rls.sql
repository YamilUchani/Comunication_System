-- ================================================================
-- SCRIPT: DESHABILITAR RLS EN TODAS LAS TABLAS (MODO PRUEBA)
-- ================================================================
-- Este script desactiva la seguridad a nivel de fila en TODAS las tablas
-- para permitir pruebas funcionales completas sin restricciones de permisos.

-- 1. Tablas principales
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE meetings DISABLE ROW LEVEL SECURITY;
ALTER TABLE meeting_participants DISABLE ROW LEVEL SECURITY;

-- 2. Tablas de funcionalidades educativas
ALTER TABLE groups DISABLE ROW LEVEL SECURITY;
ALTER TABLE achievements DISABLE ROW LEVEL SECURITY;
ALTER TABLE student_achievements DISABLE ROW LEVEL SECURITY;
ALTER TABLE meeting_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE attendance DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs DISABLE ROW LEVEL SECURITY;

-- ================================================================
-- NOTA: Esto deja la base de datos abierta a cualquier usuario autenticado.
-- Úsalo solo para desarrollo y pruebas.
-- ================================================================
