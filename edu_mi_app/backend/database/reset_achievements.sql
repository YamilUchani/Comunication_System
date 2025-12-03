-- Eliminar todos los logros existentes y crear solo los 4 requeridos
DELETE FROM student_achievements;
DELETE FROM achievements;

-- Insertar los 4 logros específicos (globales, sin grupo específico)
-- Nota: Reemplaza 'YOUR_USER_ID' con tu user_id real de la tabla profiles
-- Puedes obtenerlo con: SELECT user_id FROM profiles WHERE role = 'admin' LIMIT 1;

INSERT INTO achievements (name, description, icon, created_by, group_name, is_global) VALUES
  ('Modelo Terminado', 'Completó el modelo de la clase', '✅', (SELECT user_id FROM profiles WHERE role = 'admin' LIMIT 1), NULL, true),
  ('Puntualidad', 'Llegó a tiempo a la clase', '⏰', (SELECT user_id FROM profiles WHERE role = 'admin' LIMIT 1), NULL, true),
  ('Participación', 'Participó activamente en clase', '🙋', (SELECT user_id FROM profiles WHERE role = 'admin' LIMIT 1), NULL, true),
  ('Creatividad', 'Mostró creatividad en su trabajo', '🎨', (SELECT user_id FROM profiles WHERE role = 'admin' LIMIT 1), NULL, true);
