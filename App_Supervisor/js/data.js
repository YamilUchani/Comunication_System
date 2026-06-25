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
    {
      id: "att-001",
      user_id: "std-uuid-01",
      meeting_id: "meet-001",
      meeting_date: "2025-06-15",
      joined_at: "2025-06-15T10:00:00Z",
      left_at: "2025-06-15T11:30:00Z",
      was_on_time: true,
      duration_minutes: 90
    },
    {
      id: "att-002",
      user_id: "std-uuid-01",
      meeting_id: "meet-002",
      meeting_date: "2025-06-16",
      joined_at: "2025-06-16T10:05:00Z",
      left_at: "2025-06-16T11:30:00Z",
      was_on_time: false,
      duration_minutes: 85
    }
  ],
  
  // 3. Student Level Progress
  student_level_progress: [
    {
      id: "slp-001",
      student_id: "std-uuid-01",
      challenge_id: "ch-001",
      status: "completed",
      unlocked_at: "2025-06-01T10:00:00Z",
      completed_at: "2025-06-05T15:30:00Z"
    },
    {
      id: "slp-002",
      student_id: "std-uuid-01",
      challenge_id: "ch-002",
      status: "in_progress",
      unlocked_at: "2025-06-06T10:00:00Z",
      completed_at: null
    }
  ],
  
  // 4. Challenges
  challenges: [
    {
      id: "ch-001",
      title: "Introducción a la Programación",
      description: "Aprende los conceptos básicos de programación con Scratch",
      order_index: 1
    },
    {
      id: "ch-002",
      title: "Variables y Tipos de Datos",
      description: "Comprende qué son las variables y cómo usarlas",
      order_index: 2
    }
  ],
  
  // 5. Student Achievements
  student_achievements: [
    {
      id: "sa-001",
      student_id: "std-uuid-01",
      achievement_id: "ach-001",
      unlocked_at: "2025-06-10T14:00:00Z"
    },
    {
      id: "sa-002",
      student_id: "std-uuid-01",
      achievement_id: "ach-002",
      unlocked_at: "2025-06-12T16:30:00Z"
    }
  ],
  
  // 6. Achievements
  achievements: [
    {
      id: "ach-001",
      name: "Primer Paso",
      description: "Completa tu primer reto de programación",
      icon: "🥇",
      points: 100
    },
    {
      id: "ach-002",
      name: "Estudiante Dedicado",
      description: "Completa 5 retos en una semana",
      icon: "⭐",
      points: 250
    }
  ],
  
  // 7. Class Schedules
  class_schedules: [
    {
      id: "cs-001",
      group_name: "8A",
      subject: "Programación Básica",
      teacher_id: "teacher-001",
      day_of_week: 1,
      start_time: "10:00:00",
      end_time: "11:30:00",
      is_active: true
    },
    {
      id: "cs-002",
      group_name: "8A",
      subject: "Matemáticas",
      teacher_id: "teacher-002",
      day_of_week: 3,
      start_time: "08:00:00",
      end_time: "09:30:00",
      is_active: true
    }
  ],
  
  // 8. Student Material Progress
  student_material_progress: [
    {
      id: "smp-001",
      student_id: "std-uuid-01",
      material_id: "mat-001",
      status: "completed",
      updated_at: "2025-06-08T12:00:00Z"
    },
    {
      id: "smp-002",
      student_id: "std-uuid-01",
      material_id: "mat-002",
      status: "pending",
      updated_at: "2025-06-09T10:00:00Z"
    }
  ],
  
  // 9. Materials
  materials: [
    {
      id: "mat-001",
      title: "Ficha de Refuerzo - Variables",
      description: "Ejercicios prácticos sobre variables y tipos de datos",
      pdf_url: "https://example.com/ficha-variables.pdf",
      image_url: null
    },
    {
      id: "mat-002",
      title: "Guía de Estudio - Bucles",
      description: "Material complementario sobre bucles y repeticiones",
      pdf_url: "https://example.com/guia-bucles.pdf",
      image_url: null
    }
  ],
  
  // 10. Meetings
  meetings: [
    {
      id: "meet-001",
      title: "Clase de Introducción",
      description: "Sala virtual para la primera clase de programación",
      channel_name: "edu-8a-programacion-001",
      meeting_type: "master",
      is_active: true,
      created_at: "2025-06-01T08:00:00Z"
    },
    {
      id: "meet-002",
      title: "Repaso de Variables",
      description: "Sesión de repaso y consultas sobre variables",
      channel_name: "edu-8a-variables-001",
      meeting_type: "review",
      is_active: true,
      created_at: "2025-06-05T14:00:00Z"
    }
  ]
};

window.mockDb = mockDb;
