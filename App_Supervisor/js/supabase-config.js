// Supabase Cloud Connection & Failover API SDK
// Aligned 100% with the production database schema of edu_mi_app

const SUPABASE_URL = "https://tcbmlktpzshltvmoirjs.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjYm1sa3RwenNobHR2bW9pcmpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNzI3MjcsImV4cCI6MjA3MDg0ODcyN30.Db7cmNGxdbfvvxD19g4JuYs8bkLF8m5ZZ8D0kpocztA";

let supabaseClient = null;
let isSupabaseActive = false;

try {
  if (
    SUPABASE_URL && 
    SUPABASE_URL !== "TU_SUPABASE_URL_AQUÍ" && 
    SUPABASE_ANON_KEY && 
    SUPABASE_ANON_KEY !== "TU_SUPABASE_ANON_KEY_AQUÍ"
  ) {
    if (typeof supabase !== 'undefined') {
      supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
      isSupabaseActive = true;
      console.log("[SUPABASE] Connected successfully to Cloud database.");
    }
  }
} catch (error) {
  console.error("[SUPABASE ERROR] Failed to initialize connection client:", error);
}

// ===== AUTH =====
const supabaseAuth = {
  signUp: async (email, password, fullName) => {
    if (!isSupabaseActive || !supabaseClient) throw new Error("Supabase no disponible");
    const { data, error } = await supabaseClient.auth.signUp({
      email, password,
      options: { data: { full_name: fullName } }
    });
    if (error) throw error;

    // Crear/actualizar perfil con role='parent'
    if (data?.user) {
      try {
        await supabaseClient.from("profiles").upsert({
          id: data.user.id,
          user_id: data.user.id,
          email: email,
          full_name: fullName,
          role: "parent"
        }, { onConflict: "id" });
      } catch (profileErr) {
        console.warn("[SUPABASE] Could not create parent profile:", profileErr.message);
      }
    }

    return data;
  },

  signInWithGoogle: async () => {
    if (!isSupabaseActive || !supabaseClient) throw new Error("Supabase no disponible");
    const { data, error } = await supabaseClient.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: window.location.href,
        skipBrowserRedirect: true,
        queryParams: { access_type: 'offline', prompt: 'consent' }
      }
    });
    if (error) throw error;
    if (data?.url) {
      const w = 600, h = 700;
      const left = screen.width / 2 - w / 2, top = screen.height / 2 - h / 2;
      const popup = window.open(data.url, 'google-oauth',
        `width=${w},height=${h},left=${left},top=${top}`);
      if (!popup) {
        throw new Error("Popup bloqueado. Permití ventanas emergentes para este sitio e intentá de nuevo.");
      }
    }
    return data;
  },

  signIn: async (email, password) => {
    if (!isSupabaseActive || !supabaseClient) throw new Error("Supabase no disponible");
    const { data, error } = await supabaseClient.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data;
  },

  signOut: async () => {
    if (!isSupabaseActive || !supabaseClient) return;
    const { error } = await supabaseClient.auth.signOut();
    if (error) throw error;
  },

  getSession: async () => {
    if (!isSupabaseActive || !supabaseClient) return null;
    const { data } = await supabaseClient.auth.getSession();
    return data.session;
  },

  onAuthChange: (callback) => {
    if (!isSupabaseActive || !supabaseClient) return;
    supabaseClient.auth.onAuthStateChange((event, session) => {
      callback(event, session);
    });
  },

  getCurrentUser: () => {
    if (!isSupabaseActive || !supabaseClient) return null;
    return supabaseClient.auth.currentUser;
  }
};

// ===== PARENT-STUDENT LINK =====
// Requires the parent_students table (see supabase/parent_students.sql)
const supabaseApi = {
  isActive: () => isSupabaseActive,

  // 1. Fetch the parent's linked students from parent_students
  getMyStudents: async () => {
    if (isSupabaseActive && supabaseClient) {
      const user = supabaseClient.auth.currentUser;
      if (!user) return [];
      try {
        console.log("[SUPABASE] Fetching parent_students for:", user.id);
        const { data: links, error } = await supabaseClient
          .from("parent_students")
          .select("student_id")
          .eq("parent_id", user.id);
        if (error) throw error;
        if (!links || links.length === 0) return [];

        const studentIds = links.map(l => l.student_id);
        const { data: students, error: sError } = await supabaseClient
          .from("profiles")
          .select("id, user_id, full_name, group_name, role, avatar_url, email, active_level, total_levels, deleted_at")
          .in("user_id", studentIds)
          .eq("role", "student")
          .is("deleted_at", null)
          .order("full_name", { ascending: true });
        if (sError) throw sError;
        return students || [];
      } catch (err) {
        console.warn("[SUPABASE] getMyStudents failed:", err.message);
        return [];
      }
    }
    return [];
  },

  // 2. Fetch all students (fallback / admin use)
  getStudents: async () => {
    if (isSupabaseActive && supabaseClient) {
      try {
        console.log("[SUPABASE] Fetching student profiles...");
        const { data, error } = await supabaseClient
          .from("profiles")
          .select("id, user_id, full_name, group_name, role, avatar_url, email, active_level, total_levels, deleted_at")
          .eq("role", "student")
          .is("deleted_at", null)
          .order("full_name", { ascending: true });
        if (error) throw error;
        return data || [];
      } catch (err) {
        console.warn("[SUPABASE] getStudents failed, using local fallback.", err.message);
        return window.mockDb.profiles.filter(p => p.role === "student");
      }
    }
    return window.mockDb.profiles.filter(p => p.role === "student");
  },

  // 2. Fetch Attendance records
  getAttendance: async (studentId) => {
    if (isSupabaseActive && supabaseClient) {
      try {
        console.log(`[SUPABASE] Fetching attendance for: ${studentId}`);
        const { data, error } = await supabaseClient
          .from("attendance")
          .select("*")
          .eq("user_id", studentId)
          .order("meeting_date", { ascending: false });
        if (error) throw error;
        return data || [];
      } catch (err) {
        console.warn("[SUPABASE] getAttendance failed, using local fallback.", err.message);
        return window.mockDb.attendance.filter(a => a.user_id === studentId);
      }
    }
    return window.mockDb.attendance.filter(a => a.user_id === studentId);
  },

  // 3. Fetch Level Progress (student_level_progress joined with challenges)
  getLevelProgress: async (studentId) => {
    if (isSupabaseActive && supabaseClient) {
      try {
        console.log(`[SUPABASE] Fetching level progress for: ${studentId}`);
        const { data, error } = await supabaseClient
          .from("student_level_progress")
          .select(`
            id,
            status,
            unlocked_at,
            completed_at,
            challenges (
              title,
              description,
              order_index
            )
          `)
          .eq("student_id", studentId)
          .order("created_at", { ascending: true });
        if (error) throw error;
        return data || [];
      } catch (err) {
        console.warn("[SUPABASE] getLevelProgress failed, using local fallback.", err.message);
        return window.mockDb.student_level_progress
          .filter(lp => lp.student_id === studentId)
          .map(lp => {
            const ch = window.mockDb.challenges.find(c => c.id === lp.challenge_id);
            return { ...lp, challenges: ch };
          });
      }
    }
    return window.mockDb.student_level_progress
      .filter(lp => lp.student_id === studentId)
      .map(lp => {
        const ch = window.mockDb.challenges.find(c => c.id === lp.challenge_id);
        return { ...lp, challenges: ch };
      });
  },

  // 4. Fetch Achievements (student_achievements joined with achievements)
  getAchievements: async (studentId) => {
    if (isSupabaseActive && supabaseClient) {
      try {
        console.log(`[SUPABASE] Fetching achievements for: ${studentId}`);
        const { data, error } = await supabaseClient
          .from("student_achievements")
          .select(`
            unlocked_at,
            achievements (
              name,
              description,
              icon,
              points
            )
          `)
          .eq("student_id", studentId)
          .order("unlocked_at", { ascending: false });
        if (error) throw error;
        return data || [];
      } catch (err) {
        console.warn("[SUPABASE] getAchievements failed, using local fallback.", err.message);
        return window.mockDb.student_achievements
          .filter(sa => sa.student_id === studentId)
          .map(sa => {
            const ach = window.mockDb.achievements.find(a => a.id === sa.achievement_id);
            return { ...sa, achievements: ach };
          });
      }
    }
    return window.mockDb.student_achievements
      .filter(sa => sa.student_id === studentId)
      .map(sa => {
        const ach = window.mockDb.achievements.find(a => a.id === sa.achievement_id);
        return { ...sa, achievements: ach };
      });
  },

  // 5. Fetch Class Schedules
  getClassSchedules: async (groupName) => {
    if (isSupabaseActive && supabaseClient) {
      try {
        console.log(`[SUPABASE] Fetching class schedules for group: ${groupName}`);
        const { data, error } = await supabaseClient
          .from("class_schedules")
          .select("*")
          .eq("group_name", groupName)
          .eq("is_active", true)
          .order("day_of_week", { ascending: true });
        if (error) throw error;
        return data || [];
      } catch (err) {
        console.warn("[SUPABASE] getClassSchedules failed, using local fallback.", err.message);
        return window.mockDb.class_schedules.filter(cs => cs.group_name === groupName);
      }
    }
    return window.mockDb.class_schedules.filter(cs => cs.group_name === groupName);
  },

  // 6. Fetch Study Material Progress (student_material_progress joined with materials)
  getMaterialProgress: async (studentId) => {
    if (isSupabaseActive && supabaseClient) {
      try {
        console.log(`[SUPABASE] Fetching material progress for: ${studentId}`);
        const { data, error } = await supabaseClient
          .from("student_material_progress")
          .select(`
            id,
            status,
            updated_at,
            materials (
              title,
              description,
              pdf_url,
              image_url
            )
          `)
          .eq("student_id", studentId);
        if (error) throw error;
        return data || [];
      } catch (err) {
        console.warn("[SUPABASE] getMaterialProgress failed, using local fallback.", err.message);
        return window.mockDb.student_material_progress
          .filter(smp => smp.student_id === studentId)
          .map(smp => {
            const mat = window.mockDb.materials.find(m => m.id === smp.material_id);
            return { ...smp, materials: mat };
          });
      }
    }
    return window.mockDb.student_material_progress
      .filter(smp => smp.student_id === studentId)
      .map(smp => {
        const mat = window.mockDb.materials.find(m => m.id === smp.material_id);
        return { ...smp, materials: mat };
      });
  },

  // 7. Fetch Virtual Meetings
  getMeetings: async (studentId) => {
    if (isSupabaseActive && supabaseClient) {
      try {
        console.log(`[SUPABASE] Fetching live meetings for student: ${studentId}`);
        const { data, error } = await supabaseClient
          .from("meetings")
          .select("*")
          .eq("is_active", true)
          .order("created_at", { ascending: false });
        if (error) throw error;
        return data || [];
      } catch (err) {
        console.warn("[SUPABASE] getMeetings failed, using local fallback.", err.message);
        return window.mockDb.meetings;
      }
    }
    return window.mockDb.meetings;
  }
};

window.supabaseAuth = supabaseAuth;
window.supabaseApi = supabaseApi;
