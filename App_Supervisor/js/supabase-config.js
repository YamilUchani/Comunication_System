// Supabase Cloud Connection & Failover API SDK
// Base de datos compartida; retorno de autenticación exclusivo de App_Supervisor.

const supervisorConfig = window.APP_SUPERVISOR_CONFIG || {};
const SUPABASE_URL = (supervisorConfig.supabaseUrl || "").trim();
const SUPABASE_ANON_KEY = (supervisorConfig.supabaseAnonKey || "").trim();
const APP_SUPERVISOR_URL = (supervisorConfig.appUrl || "").trim();

function getAuthRedirectUrl() {
  const isLocal =
    window.location.hostname === "localhost" ||
    window.location.hostname === "127.0.0.1";

  if (isLocal || !APP_SUPERVISOR_URL) {
    return `${window.location.origin}${window.location.pathname}`;
  }

  return APP_SUPERVISOR_URL;
}

let supabaseClient = null;
let isSupabaseActive = false;

try {
  if (
    /^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(SUPABASE_URL) &&
    SUPABASE_ANON_KEY
  ) {
    if (typeof supabase !== 'undefined' && supabase && typeof supabase.createClient === 'function') {
      supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
      isSupabaseActive = true;
      console.log("[SUPABASE] Connected successfully to Cloud database.");
    } else {
      console.warn("[SUPABASE] Supabase SDK not loaded (CDN may be blocked or offline). Running in LOCAL mode.");
    }
  } else {
    console.warn("[APP_SUPERVISOR] Supabase credentials are not configured. Running in LOCAL mode.");
  }
} catch (error) {
  console.error("[SUPABASE ERROR] Failed to initialize connection client:", error);
  // Keep supabaseClient = null and isSupabaseActive = false
}

// ===== AUTH =====
const supabaseAuth = {
  signUp: async (email, password, fullName, guardianInfo = {}) => {
    if (!isSupabaseActive || !supabaseClient) throw new Error("Supabase no disponible");
    const { data, error } = await supabaseClient.auth.signUp({
      email, password,
      options: {
        data: {
          full_name: fullName,
          parent_age: guardianInfo.parent_age,
          relationship_to_student: guardianInfo.relationship_to_student
        }
      }
    });
    if (error) throw error;

    // Crear/actualizar perfil con role='parent'
    if (data?.user) {
      try {
        await supabaseClient.from("parent_profiles").upsert({
          id: data.user.id,
          email: email,
          full_name: fullName,
          parent_age: guardianInfo.parent_age,
          relationship_to_student: guardianInfo.relationship_to_student,
          updated_at: new Date().toISOString()
        }, { onConflict: "id" });
      } catch (profileErr) {
        console.warn("[SUPABASE] Could not create parent profile:", profileErr.message);
        await supabaseClient.from("parent_profiles").upsert({
          id: data.user.id,
          email: email,
          full_name: fullName,
          updated_at: new Date().toISOString()
        }, { onConflict: "id" });
      }
    }

    return data;
  },

  signInWithGoogle: async () => {
    if (!isSupabaseActive || !supabaseClient) throw new Error("Supabase no disponible");

    const { data, error } = await supabaseClient.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: getAuthRedirectUrl(),
        queryParams: { access_type: "offline", prompt: "consent" }
      }
    });
    if (error) throw error;
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

  getCurrentUser: async () => {
    if (!isSupabaseActive || !supabaseClient) return null;
    const { data, error } = await supabaseClient.auth.getUser();
    if (error) throw error;
    return data.user;
  },

  setSession: async (accessToken, refreshToken) => {
    if (!isSupabaseActive || !supabaseClient) throw new Error("Supabase no disponible");
    const { data, error } = await supabaseClient.auth.setSession({
      access_token: accessToken,
      refresh_token: refreshToken
    });
    if (error) throw error;
    return data;
  },

  exchangeCodeForSession: async (code) => {
    if (!isSupabaseActive || !supabaseClient) throw new Error("Supabase no disponible");
    const { data, error } = await supabaseClient.auth.exchangeCodeForSession(code);
    if (error) throw error;
    return data;
  }
};

// ===== PARENT-STUDENT LINK =====
// Requires the parent_students table (see supabase/parent_students.sql)
const supabaseApi = {
  isActive: () => isSupabaseActive,

  // 1. Fetch the parent's linked students from parent_students
  getMyStudents: async () => {
    if (isSupabaseActive && supabaseClient) {
      const { data: userData, error: userError } = await supabaseClient.auth.getUser();
      if (userError) {
        console.warn("[SUPABASE] Could not resolve authenticated user:", userError.message);
        return [];
      }
      const user = userData.user;
      if (!user) return [];
      try {
        console.log("[SUPABASE] Fetching parent_students for:", user.id);
        const { data: links, error } = await supabaseClient
          .from("parent_students")
          .select("student_id")
          .eq("parent_id", user.id);
        if (error) throw error;
        if (!links || links.length === 0) {
          console.log("[SUPABASE] No parent_students links found for this parent.");
          return [];
        }

        const studentIds = links.map(l => l.student_id).filter(id => id && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id));
        console.log("[SUPABASE] Looking for student profiles with valid UUIDs:", studentIds);
        
        if (studentIds.length === 0) {
          console.log("[SUPABASE] No valid student UUIDs found.");
          return [];
        }
        
        // Get profiles - join with auth.users to get role info
        const { data: students, error: sError } = await supabaseClient
          .from("profiles")
          .select("id, email, full_name, created_at")
          .in("id", studentIds)
          .order("full_name", { ascending: true });
        
        if (sError) {
          console.warn("[SUPABASE] profiles query error:", sError.message);
          return [];
        }
        
        if (!students || students.length === 0) {
          console.log("[SUPABASE] No profile records found for linked student IDs.");
          return [];
        }
        
        // Try to get role from auth.users metadata
        const enrichedStudents = await Promise.all(
          students.map(async (s) => {
            try {
              const { data: authData } = await supabaseClient.auth.admin.getUserById(s.id);
              const role = authData?.user?.user_metadata?.role || "student";
              return {
                ...s,
                user_id: s.id,
                role: role,
                group_name: authData?.user?.user_metadata?.group_name || "Sin grupo",
                avatar_url: authData?.user?.user_metadata?.avatar_url || null,
                active_level: 1,
                total_levels: 20
              };
            } catch {
              return {
                ...s,
                user_id: s.id,
                role: "student",
                group_name: "Sin grupo",
                avatar_url: null,
                active_level: 1,
                total_levels: 20
              };
            }
          })
        );
        
        console.log("[SUPABASE] Found students:", enrichedStudents.length);
        return enrichedStudents;
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
      console.warn("[SUPABASE] getStudents is disabled in cloud mode for parent privacy.");
      return [];
    }
    return window.mockDb.profiles.filter(p => p.role === "student");
  },

  // 3. Fetch Attendance records
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
        const { data: studentProfile } = await supabaseClient
          .from("profiles")
          .select("group_name")
          .eq("user_id", studentId)
          .maybeSingle();

        const groupName = studentProfile?.group_name || null;
        const { data, error } = await supabaseClient
          .from("meetings")
          .select("*")
          .eq("is_active", true)
          .order("created_at", { ascending: false });
        if (error) throw error;
        return (data || []).filter(meeting => {
          const allowedGroups = Array.isArray(meeting.allowed_groups) ? meeting.allowed_groups : [];
          const allowedUsers = Array.isArray(meeting.allowed_users) ? meeting.allowed_users : [];
          const personallyInvited = allowedUsers.includes(studentId);
          const groupAllowed = groupName && allowedGroups.includes(groupName);
          const unrestricted = allowedGroups.length === 0 && allowedUsers.length === 0;
          return personallyInvited || groupAllowed || unrestricted;
        });
      } catch (err) {
        console.warn("[SUPABASE] getMeetings failed, using local fallback.", err.message);
        return window.mockDb.meetings;
      }
    }
    return window.mockDb.meetings;
  },

  // 8. Upsert Parent Profile — BUG FIX: exposed so app.js can call it without accessing supabaseClient
  upsertParentProfile: async (profileData) => {
    if (!isSupabaseActive || !supabaseClient) {
      return { ok: false, error: "Supabase client is not active" };
    }
    try {
      const cleanProfile = Object.fromEntries(
        Object.entries(profileData || {}).filter(([, value]) => value !== undefined)
      );
      const { error } = await supabaseClient
        .from("parent_profiles")
        .upsert(cleanProfile, { onConflict: "id" });
      if (error) throw error;
      console.log("[SUPABASE] Parent profile saved.");
      return { ok: true };
    } catch (err) {
      console.warn("[SUPABASE] upsertParentProfile failed:", err.message);
      if (profileData?.id) {
        try {
          const fallbackProfile = {
            id: profileData.id,
            email: profileData.email,
            full_name: profileData.full_name,
            updated_at: new Date().toISOString()
          };
          const { error } = await supabaseClient
            .from("parent_profiles")
            .upsert(fallbackProfile, { onConflict: "id" });
          if (!error) {
            console.warn("[SUPABASE] Saved parent profile without guardian optional fields.");
            return { ok: false, partial: true, error: err.message };
          }
        } catch (fallbackErr) {
          console.warn("[SUPABASE] Parent profile fallback failed:", fallbackErr.message);
        }
      }
      return { ok: false, error: err.message };
    }
  }
};

window.supabaseAuth = supabaseAuth;
window.supabaseApi = supabaseApi;
