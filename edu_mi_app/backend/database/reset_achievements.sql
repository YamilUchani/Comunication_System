-- Eliminar todos los logros existentes y crear solo los 4 requeridos
DELETE FROM student_achievements;
DELETE FROM achievements;

-- Insertar los 4 logros específicos (globales, sin grupo específico)
-- Usa el primer usuario disponible en la tabla profiles
INSERT INTO achievements (name, description, icon, created_by, group_name, is_global) 
SELECT 
  achievement_data.name,
  achievement_data.description,
  achievement_data.icon,
  (SELECT user_id FROM profiles LIMIT 1) as created_by,
  NULL as group_name,
  true as is_global
FROM (
  VALUES 
    ('Modelo Terminado', 'Completó el modelo de la clase', '✅'),
    ('Puntualidad', 'Llegó a tiempo a la clase', '⏰'),
    ('Participación', 'Participó activamente en clase', '🙋'),
    ('Creatividad', 'Mostró creatividad en su trabajo', '🎨')
) AS achievement_data(name, description, icon);
