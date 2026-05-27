// Mock Database representing exactly the Supabase CSV Database schema
// Excludes all simulated, fake, or non-existent tables

const mockDb = {
  // 1. Profiles Table
  profiles: [
    {
      id: "std-uuid-01",
      user_id: "std-uuid-01",
      full_name: "Damian Agramont Pareja",
      age: 14,
      group_name: "8A",
      role: "student",
      avatar_url: null,
      email: "damian@gmail.com",
      active_level: 8,
      total_levels: 20,
      is_verified: true,
      can_create_meetings: false
    },
    {
      id: "std-uuid-02",
      user_id: "std-uuid-02",
      full_name: "Angel Andre Calle Mansmith",
      age: 15,
      group_name: "8B",
      role: "student",
      avatar_url: null,
      email: "angel@gmail.com",
      active_level: 12,
      total_levels: 20,
      is_verified: true,
      can_create_meetings: false
    },
    {
      id: "std-uuid-03",
      user_id: "std-uuid-03",
      full_name: "Bernard Alejandro Ibañez",
      age: 13,
      group_name: "8A",
      role: "student",
      avatar_url: null,
      email: "bernard@gmail.com",
      active_level: 15,
      total_levels: 20,
      is_verified: true,
      can_create_meetings: false
    }
  ],

  // 2. Attendance Table
  attendance: [
    { id: "att-1", user_id: "std-uuid-01", meeting_id: "meet-1", joined_at: "2026-05-22T08:00:00Z", left_at: "2026-05-22T09:00:00Z", duration_minutes: 60, was_on_time: true, meeting_date: "2026-05-22", status: "active" },
    { id: "att-2", user_id: "std-uuid-01", meeting_id: "meet-2", joined_at: "2026-05-20T10:15:00Z", left_at: "2026-05-20T11:15:00Z", duration_minutes: 60, was_on_time: false, meeting_date: "2026-05-20", status: "active" },
    { id: "att-3", user_id: "std-uuid-01", meeting_id: "meet-3", joined_at: "2026-05-18T08:02:00Z", left_at: "2026-05-18T09:00:00Z", duration_minutes: 58, was_on_time: true, meeting_date: "2026-05-18", status: "active" },
    
    { id: "att-4", user_id: "std-uuid-02", meeting_id: "meet-1", joined_at: "2026-05-22T08:01:00Z", left_at: "2026-05-22T09:00:00Z", duration_minutes: 59, was_on_time: true, meeting_date: "2026-05-22", status: "active" },
    { id: "att-5", user_id: "std-uuid-02", meeting_id: "meet-2", joined_at: "2026-05-20T10:00:00Z", left_at: "2026-05-20T11:00:00Z", duration_minutes: 60, was_on_time: true, meeting_date: "2026-05-20", status: "active" },
    
    { id: "att-6", user_id: "std-uuid-03", meeting_id: "meet-1", joined_at: "2026-05-22T08:00:00Z", left_at: "2026-05-22T09:00:00Z", duration_minutes: 60, was_on_time: true, meeting_date: "2026-05-22", status: "active" }
  ],

  // 3. Challenges Table
  challenges: [
    { id: "ch-1", title: "Operaciones Aritméticas Básicas", description: "Suma, resta, multiplicación y división de números enteros.", order_index: 1 },
    { id: "ch-2", title: "Introducción a las Fracciones", description: "Identificar y representar partes de un entero.", order_index: 2 },
    { id: "ch-3", title: "Ecuaciones Lineales Simples", description: "Despejar la incógnita X en ecuaciones sencillas.", order_index: 3 },
    { id: "ch-4", title: "Geometría Básica: Áreas", description: "Fórmulas para calcular el área de triángulos y rectángulos.", order_index: 4 },
    { id: "ch-5", title: "Fracciones Equivalentes", description: "Simplificación y comparación de fracciones.", order_index: 5 }
  ],

  // 4. Student Level Progress Table
  student_level_progress: [
    { id: "slp-1", student_id: "std-uuid-01", challenge_id: "ch-1", status: "completed", unlocked_at: "2026-05-10T12:00:00Z", completed_at: "2026-05-11T14:30:00Z" },
    { id: "slp-2", student_id: "std-uuid-01", challenge_id: "ch-2", status: "completed", unlocked_at: "2026-05-12T09:00:00Z", completed_at: "2026-05-15T11:00:00Z" },
    { id: "slp-3", student_id: "std-uuid-01", challenge_id: "ch-3", status: "completed", unlocked_at: "2026-05-16T10:00:00Z", completed_at: "2026-05-18T16:00:00Z" },
    { id: "slp-4", student_id: "std-uuid-01", challenge_id: "ch-4", status: "in_progress", unlocked_at: "2026-05-19T08:00:00Z", completed_at: null },
    
    { id: "slp-5", student_id: "std-uuid-02", challenge_id: "ch-1", status: "completed", unlocked_at: "2026-05-10T12:00:00Z", completed_at: "2026-05-11T13:00:00Z" },
    { id: "slp-6", student_id: "std-uuid-02", challenge_id: "ch-2", status: "completed", unlocked_at: "2026-05-12T09:00:00Z", completed_at: "2026-05-14T10:15:00Z" }
  ],

  // 5. Achievements Table
  achievements: [
    { id: "ach-1", name: "Primer Paso", description: "Completa la primera lección con puntaje perfecto.", icon: "🏆", points: 10 },
    { id: "ach-2", name: "Asistencia Perfecta", description: "Asiste a 3 clases consecutivas a tiempo.", icon: "⭐", points: 20 },
    { id: "ach-3", name: "Maestro Fraccionario", description: "Completa el módulo de fracciones de nivel intermedio.", icon: "🎯", points: 30 }
  ],

  // 6. Student Achievements Table
  student_achievements: [
    { student_id: "std-uuid-01", achievement_id: "ach-1", unlocked_at: "2026-05-11T14:30:00Z" },
    { student_id: "std-uuid-01", achievement_id: "ach-2", unlocked_at: "2026-05-22T09:00:00Z" },
    
    { student_id: "std-uuid-02", achievement_id: "ach-1", unlocked_at: "2026-05-11T13:00:00Z" }
  ],

  // 7. Class Schedules Table
  class_schedules: [
    { id: "sched-1", teacher_id: "teach-01", group_name: "8A", subject: "Matemáticas Básicas", day_of_week: 1, start_time: "08:00:00", end_time: "09:00:00", is_active: true },
    { id: "sched-2", teacher_id: "teach-01", group_name: "8A", subject: "Ciencias de la Tierra", day_of_week: 3, start_time: "10:15:00", end_time: "11:15:00", is_active: true },
    { id: "sched-3", teacher_id: "teach-01", group_name: "8A", subject: "Historia Universal", day_of_week: 5, start_time: "08:00:00", end_time: "09:00:00", is_active: true },
    
    { id: "sched-4", teacher_id: "teach-02", group_name: "8B", subject: "Matemáticas Avanzadas", day_of_week: 1, start_time: "08:00:00", end_time: "09:00:00", is_active: true },
    { id: "sched-5", teacher_id: "teach-02", group_name: "8B", subject: "Física Cuántica Básica", day_of_week: 3, start_time: "10:00:00", end_time: "11:00:00", is_active: true }
  ],

  // 8. Materials Table
  materials: [
    { id: "mat-1", title: "Ficha de Fracciones y Decimales", description: "PDF de reforzamiento interactivo con problemas matemáticos.", pdf_url: "#", image_url: null },
    { id: "mat-2", title: "Guía de Ecuaciones de Primer Grado", description: "Infografía paso a paso para resolver ecuaciones de la forma ax + b = c.", pdf_url: "#", image_url: null }
  ],

  // 9. Student Material Progress Table
  student_material_progress: [
    { id: "smp-1", student_id: "std-uuid-01", material_id: "mat-1", status: "completed", updated_at: "2026-05-18T10:00:00Z" },
    { id: "smp-2", student_id: "std-uuid-01", material_id: "mat-2", status: "pending", updated_at: "2026-05-20T11:00:00Z" },
    
    { id: "smp-3", student_id: "std-uuid-02", material_id: "mat-1", status: "completed", updated_at: "2026-05-19T09:30:00Z" }
  ],

  // 10. Meetings Table
  meetings: [
    { id: "meet-uuid-1", channel_name: "Room-A8", title: "Clase en Vivo: Geometría de Áreas", description: "Sala virtual de Matemáticas 8º Grado.", creator_id: "teach-01", is_active: true, expires_at: "2026-05-28T10:00:00Z", group_name: "8A", meeting_type: "master" }
  ]
};

// Export to global window object
window.mockDb = mockDb;
