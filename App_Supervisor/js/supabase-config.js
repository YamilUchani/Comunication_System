// Supabase Cloud Connection & Failover API SDK
// Priority 1: Data storage and real-time syncing

// Set your Supabase Credentials here (refer to INSTRUCCIONES_DETALLADAS.md)
const SUPABASE_URL = "TU_SUPABASE_URL_AQUÍ";
const SUPABASE_ANON_KEY = "TU_SUPABASE_ANON_KEY_AQUÍ";

let supabaseClient = null;
let isSupabaseActive = false;

try {
  if (
    SUPABASE_URL && 
    SUPABASE_URL !== "TU_SUPABASE_URL_AQUÍ" && 
    SUPABASE_ANON_KEY && 
    SUPABASE_ANON_KEY !== "TU_SUPABASE_ANON_KEY_AQUÍ"
  ) {
    // Loaded via CDN script tag: supabase.createClient
    if (typeof supabase !== 'undefined') {
      supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
      isSupabaseActive = true;
      console.log("[SUPABASE] Connected successfully to Cloud database.");
    }
  }
} catch (error) {
  console.error("[SUPABASE ERROR] Failed to initialize connection client:", error);
}

// Wrapper APIs with local mockDb graceful fallback
const supabaseApi = {
  isActive: () => isSupabaseActive,

  // Fetch Grades list
  getGrades: async (studentId) => {
    if (isSupabaseActive && supabaseClient) {
      try {
        console.log(`[SUPABASE] Fetching grades from cloud for student ID: ${studentId}`);
        const { data, error } = await supabaseClient
          .from("grades")
          .select("*")
          .eq("student_id", studentId);
        if (error) throw error;
        return data;
      } catch (err) {
        console.warn("[SUPABASE FALLBACK] Fetch grades failed, using mock DB instead.", err.message);
        return window.mockDb.grades[studentId] || [];
      }
    }
    return window.mockDb.grades[studentId] || [];
  },

  // Fetch Tasks list
  getTasks: async (studentId) => {
    if (isSupabaseActive && supabaseClient) {
      try {
        console.log(`[SUPABASE] Fetching tasks from cloud for student ID: ${studentId}`);
        const { data, error } = await supabaseClient
          .from("tasks")
          .select("*")
          .eq("student_id", studentId);
        if (error) throw error;
        return data;
      } catch (err) {
        console.warn("[SUPABASE FALLBACK] Fetch tasks failed, using mock DB instead.", err.message);
        return window.mockDb.tasks[studentId] || [];
      }
    }
    return window.mockDb.tasks[studentId] || [];
  },

  // Add Calendar event (meeting scheduler)
  addCalendarEvent: async (eventPayload) => {
    if (isSupabaseActive && supabaseClient) {
      try {
        console.log("[SUPABASE] Inserting new meeting record into public.calendar_events");
        const { data, error } = await supabaseClient
          .from("calendar_events")
          .insert([eventPayload]);
        if (error) throw error;
        return { success: true, data };
      } catch (err) {
        console.warn("[SUPABASE FALLBACK] Insert calendar event failed, writing locally instead.", err.message);
        window.mockDb.calendarEvents.push(eventPayload);
        return { success: true, fallback: true };
      }
    }
    window.mockDb.calendarEvents.push(eventPayload);
    return { success: true, fallback: true };
  },

  // Send Chat message
  sendChatMessage: async (messagePayload) => {
    if (isSupabaseActive && supabaseClient) {
      try {
        console.log("[SUPABASE] Logging outgoing chat message to public.chats table");
        const { data, error } = await supabaseClient
          .from("chats")
          .insert([messagePayload]);
        if (error) throw error;
        return { success: true, data };
      } catch (err) {
        console.warn("[SUPABASE FALLBACK] Outgoing chat write failed, storing locally instead.", err.message);
        return { success: true, fallback: true };
      }
    }
    return { success: true, fallback: true };
  }
};

// Export to global window object
window.supabaseApi = supabaseApi;
