// Mock Database for the Parent Portal
const mockDb = {
  students: [
    {
      id: "std-01",
      name: "Sophia Martinez",
      grade: "8th Grade - Class A",
      avatar: "SM",
      gpa: 82.5,
      attendance: 96,
      avatarColor: "var(--accent-primary)"
    },
    {
      id: "std-02",
      name: "Leo Martinez",
      grade: "5th Grade - Class B",
      avatar: "LM",
      gpa: 94.2,
      attendance: 98,
      avatarColor: "var(--accent-secondary)"
    }
  ],
  
  grades: {
    "std-01": [
      { id: "grd-1", subject: "Mathematics", score: 62, maxScore: 100, date: "2026-05-18", category: "Exam 2", weight: "30%", teacher: "Prof. Emily Carter", comments: "Struggled with quadratic equations and factorization." },
      { id: "grd-2", subject: "Science", score: 85, maxScore: 100, date: "2026-05-15", category: "Lab Report", weight: "20%", teacher: "Prof. Marcus Vance", comments: "Excellent lab notebook organization." },
      { id: "grd-3", subject: "History", score: 92, maxScore: 100, date: "2026-05-10", category: "Essay", weight: "25%", teacher: "Prof. Clara Higgins", comments: "Brilliant analysis of the Industrial Revolution." },
      { id: "grd-4", subject: "Language Arts", score: 78, maxScore: 100, date: "2026-05-08", category: "Quiz 3", weight: "15%", teacher: "Prof. Arthur Miller", comments: "Good understanding of sentence structures, needs vocabulary practice." },
      { id: "grd-5", subject: "Mathematics", score: 75, maxScore: 100, date: "2026-04-28", category: "Quiz 2", weight: "15%", teacher: "Prof. Emily Carter", comments: "Decent understanding, minor calculation errors." }
    ],
    "std-02": [
      { id: "grd-6", subject: "Mathematics", score: 95, maxScore: 100, date: "2026-05-19", category: "Exam 2", weight: "30%", teacher: "Prof. Sarah Jenkins", comments: "Outstanding spatial reasoning skills." },
      { id: "grd-7", subject: "Science", score: 98, maxScore: 100, date: "2026-05-14", category: "Project", weight: "30%", teacher: "Prof. Marcus Vance", comments: "Built an exceptional model of the water cycle." },
      { id: "grd-8", subject: "History", score: 90, maxScore: 100, date: "2026-05-12", category: "Quiz", weight: "20%", teacher: "Prof. Clara Higgins", comments: "Participated actively and showed good retention." },
      { id: "grd-9", subject: "Language Arts", score: 94, maxScore: 100, date: "2026-05-05", category: "Reading Log", weight: "20%", teacher: "Prof. Arthur Miller", comments: "Read beyond the required reading list." }
    ]
  },

  tasks: {
    "std-01": [
      {
        id: "tsk-1",
        title: "Quadratic Equations Reinforcement Worksheet",
        subject: "Mathematics",
        dueDate: "2026-05-24",
        status: "pending",
        difficulty: "High",
        resources: [
          { name: "Live Session Recording: Factoring Quadratics", type: "video", url: "#", duration: "45m" },
          { name: "Step-by-step PDF Practice Guide", type: "pdf", url: "#", size: "2.4 MB" }
        ],
        coLearnDiscussions: [
          { author: "Teacher", text: "Parents: Please review the visual box method with your child if they find algebra symbols confusing." },
          { author: "Sophia (Student)", text: "I keep getting confused when there's a negative sign in front of the middle term." }
        ]
      },
      {
        id: "tsk-2",
        title: "Photosynthesis Diagram & Vocabulary Quiz",
        subject: "Science",
        dueDate: "2026-05-22",
        status: "pending",
        difficulty: "Medium",
        resources: [
          { name: "Cell Structure Animation", type: "video", url: "#", duration: "12m" },
          { name: "Photosynthesis Diagram Handout", type: "pdf", url: "#", size: "1.1 MB" }
        ],
        coLearnDiscussions: []
      },
      {
        id: "tsk-3",
        title: "World War I Chronology Project",
        subject: "History",
        dueDate: "2026-05-20",
        status: "completed",
        difficulty: "Medium",
        resources: [
          { name: "WWI Interactive Timeline Reference", type: "link", url: "#" }
        ],
        coLearnDiscussions: [
          { author: "You (Parent)", text: "We completed the draft map timeline together. Sophia was highly engaged in drawing the maps!" }
        ]
      },
      {
        id: "tsk-4",
        title: "Paragraph Construction Portfolio",
        subject: "Language Arts",
        dueDate: "2026-05-18",
        status: "completed",
        difficulty: "Low",
        resources: [
          { name: "Transition Words Cheatsheet", type: "pdf", url: "#", size: "850 KB" }
        ],
        coLearnDiscussions: []
      }
    ],
    "std-02": [
      {
        id: "tsk-5",
        title: "Basic Multiplication & Division Quiz prep",
        subject: "Mathematics",
        dueDate: "2026-05-23",
        status: "pending",
        difficulty: "Low",
        resources: [
          { name: "Classroom Multiplication Game Link", type: "link", url: "#" }
        ],
        coLearnDiscussions: []
      },
      {
        id: "tsk-6",
        title: "Insect Life Cycle Notebook",
        subject: "Science",
        dueDate: "2026-05-21",
        status: "completed",
        difficulty: "Medium",
        resources: [
          { name: "Metamorphosis Video", type: "video", url: "#", duration: "8m" }
        ],
        coLearnDiscussions: [
          { author: "Teacher", text: "Excellent drawing of the caterpillar chrysalis phase, Leo!" }
        ]
      }
    ]
  },

  teachers: [
    { id: "tch-1", name: "Prof. Emily Carter", subject: "Mathematics", email: "emily.carter@school.edu", color: "#6366f1" },
    { id: "tch-2", name: "Prof. Marcus Vance", subject: "Science", email: "marcus.vance@school.edu", color: "#10b981" },
    { id: "tch-3", name: "Prof. Clara Higgins", subject: "History", email: "clara.higgins@school.edu", color: "#f59e0b" },
    { id: "tch-4", name: "Prof. Arthur Miller", subject: "Language Arts", email: "arthur.miller@school.edu", color: "#ec4899" },
    { id: "tch-5", name: "Prof. Sarah Jenkins", subject: "Mathematics", email: "sarah.jenkins@school.edu", color: "#8b5cf6" }
  ],

  chats: {
    "tch-1": [
      { sender: "teacher", text: "Hello! I noticed Sophia had some difficulty with Quadratic Equations in the recent exam (score 62/100).", timestamp: "2026-05-18 16:30" },
      { sender: "parent", text: "Thanks for reaching out, Prof. Carter. Yes, we saw the grade. What do you recommend we focus on at home?", timestamp: "2026-05-18 17:15" },
      { sender: "teacher", text: "I have uploaded a Quadratic Equations Reinforcement Worksheet. If you can, go through the box-method worksheet together in Co-Aprendiz mode.", timestamp: "2026-05-18 17:40" }
    ],
    "tch-2": [
      { sender: "teacher", text: "Hi! Marcus here. The science project submissions are looking wonderful. Just checking if you have any questions on the upcoming cell lab.", timestamp: "2026-05-15 14:00" },
      { sender: "parent", text: "Hi Prof. Vance! No questions yet, we downloaded the diagram and will start sketching it this weekend.", timestamp: "2026-05-15 15:22" }
    ]
  },

  calendarEvents: [
    { title: "Parent-Teacher Meeting: Math Progress", type: "meeting", date: "2026-05-25", time: "15:00 - 15:30", note: "Virtual room: Room-A" },
    { title: "Math Exam 3: Algebra Basics", type: "exam", date: "2026-05-28", time: "09:00 - 10:30", note: "In-class exam" },
    { title: "Science Lab: Plant Cells", type: "class", date: "2026-05-22", time: "10:00 - 11:30", note: "Virtual/Live Zoom" },
    { title: "History Essay Submission: WWI", type: "homework", date: "2026-05-20", time: "23:59", note: "Submit via portal" },
    { title: "Math Homework: Quadratics Quiz", type: "homework", date: "2026-05-24", time: "23:59", note: "Submit via portal" }
  ],

  storeCourses: [
    { id: "crs-1", title: "Algebra Boot Camp: Zero to Hero", subject: "Mathematics", tutor: "Prof. Emily Carter", price: 49.99, rating: 4.9, image: "algebra" },
    { id: "crs-2", title: "Coding Adventures in Python (Kids)", subject: "Technology", tutor: "Instructor Carlos R.", price: 79.99, rating: 4.8, image: "python" },
    { id: "crs-3", title: "Advanced Placement Bio Prep", subject: "Science", tutor: "Prof. Marcus Vance", price: 120.00, rating: 5.0, image: "biology" }
  ],

  alerts: [
    {
      id: "al-1",
      studentId: "std-01",
      type: "warning",
      message: "Low performance detected in Mathematics: Exam 2 (62/100).",
      action: "schedule_meeting",
      teacherId: "tch-1",
      resolved: false,
      date: "2026-05-18"
    },
    {
      id: "al-2",
      studentId: "std-01",
      type: "info",
      message: "New Math Reinforcement Worksheets added by Prof. Emily Carter.",
      action: "view_tasks",
      resolved: false,
      date: "2026-05-19"
    }
  ]
};

// Export to window object for access across scripts
window.mockDb = mockDb;
