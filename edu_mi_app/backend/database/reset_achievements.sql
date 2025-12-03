-- Eliminar todos los logros existentes y crear solo los 4 requeridos
DELETE FROM student_achievements;
DELETE FROM achievements;

-- Insertar los 4 logros específicos
INSERT INTO achievements (id, name, description, icon, points) VALUES
  (gen_random_uuid(), 'Modelo Terminado', 'Completó el modelo de la clase', '✅', 10),
  (gen_random_uuid(), 'Puntualidad', 'Llegó a tiempo a la clase', '⏰', 5),
  (gen_random_uuid(), 'Participación', 'Participó activamente en clase', '🙋', 5),
  (gen_random_uuid(), 'Creatividad', 'Mostró creatividad en su trabajo', '🎨', 10);
