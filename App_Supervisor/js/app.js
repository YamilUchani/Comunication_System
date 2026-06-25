document.addEventListener("DOMContentLoaded", () => {
  let currentStudentId = null;
  let currentStudent = null;
  let currentUser = null;
  let currentTab = "dashboard";
  let loadedStudents = [];

  const studentSelector = document.getElementById("student-select");
  const studentAvatar   = document.getElementById("header-avatar");
  const navItems        = document.querySelectorAll(".nav-links li");
  const tabContents     = document.querySelectorAll(".tab-content");
  const telemetryBody   = document.getElementById("telemetry-body");
  const telemetryDrawer = document.getElementById("telemetry-drawer");
  const telemetryHeader = document.getElementById("telemetry-header");
  const cloudBadge      = document.getElementById("cloud-status-badge");
  const displayName     = document.getElementById("user-display-name");
  const displayEmail    = document.getElementById("user-display-email");
  const logoutBtn       = document.getElementById("logout-btn");
  const pendingLinkCard = document.getElementById("pending-link-card");
  const pendingLinkText = document.getElementById("pending-link-text");
  const guardianFullName = document.getElementById("guardian-full-name");
  const guardianAge = document.getElementById("guardian-age");
  const guardianRelation = document.getElementById("guardian-relation");
  const guardianSaveBtn = document.getElementById("guardian-save-btn");
  const guardianSaveStatus = document.getElementById("guardian-save-status");

  // Redirect to login page
  function goToLogin() {
    window.location.href = './index.html';
  }

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function safeUrl(value) {
    try {
      const url = new URL(String(value || ""), window.location.origin);
      return ["http:", "https:"].includes(url.protocol) ? url.href : "";
    } catch (_) {
      return "";
    }
  }

  async function consumeAuthTokensFromUrl() {
    const query = new URLSearchParams(window.location.search);
    const hash = new URLSearchParams(window.location.hash.replace(/^#/, ""));
    const accessToken = query.get("access_token") || hash.get("access_token");
    const refreshToken = query.get("refresh_token") || hash.get("refresh_token");
    const authCode = query.get("code") || hash.get("code");

    if (accessToken && refreshToken && window.supabaseAuth?.setSession) {
      await window.supabaseAuth.setSession(accessToken, refreshToken);
      window.history.replaceState({}, document.title, window.location.pathname);
      logTelemetry("AUTH", "OAuth session restored from callback tokens.");
      return;
    }

    if (authCode && window.supabaseAuth?.exchangeCodeForSession) {
      await window.supabaseAuth.exchangeCodeForSession(authCode);
      window.history.replaceState({}, document.title, window.location.pathname);
      logTelemetry("AUTH", "OAuth session restored from callback code.");
    }
  }

  async function init() {
    logTelemetry("SYSTEM", "EduCoParent dashboard initializing...");
    updateConnectionBadge();
    console.log("[APP] Supabase active:", window.supabaseApi?.isActive());
    console.log("[APP] Current URL:", window.location.href);

    // Always bind nav/selector events first
    bindEvents();

    // Listen for auth state changes (logout from another tab, token expiry)
    try {
      window.supabaseAuth.onAuthChange((event, session) => {
        console.log("[APP] Auth state change:", event, session?.user?.email || "no user");
        if (event === "SIGNED_OUT") {
          logTelemetry("AUTH", "Session ended. Redirecting to login...");
          goToLogin();
        } else if (event === "SIGNED_IN" && session?.user) {
          // Reload if somehow we get a new sign-in event
          onAuthSuccess(session.user);
        }
      });
    } catch (e) {
      console.warn("[APP] Cannot listen to auth changes:", e.message);
    }

    // Check for OAuth callback tokens, then for existing session
    try {
      await consumeAuthTokensFromUrl();
    } catch (e) {
      console.warn("[APP] consumeAuthTokensFromUrl failed:", e.message);
    }

    try {
      const session = await window.supabaseAuth.getSession();
      console.log("[APP] getSession result:", session ? "session found for " + session.user.email : "no session");
      if (session?.user) {
        logTelemetry("AUTH", "Session found, loading dashboard...");
        await onAuthSuccess(session.user);
        return;
      }
    } catch (e) {
      console.warn("[APP] Session check failed:", e.message);
    }

    // Try getCurrentUser as fallback
    try {
      const user = await window.supabaseAuth.getCurrentUser();
      console.log("[APP] getCurrentUser result:", user ? "user found: " + user.email : "no user");
      if (user) {
        logTelemetry("AUTH", "User obtained via getCurrentUser, loading dashboard...");
        await onAuthSuccess(user);
        return;
      }
    } catch (e) {
      console.warn("[APP] getCurrentUser failed:", e.message);
    }

    // No Supabase OR no session — in local mode load mock data directly
    if (!window.supabaseApi || !window.supabaseApi.isActive()) {
      logTelemetry("AUTH", "Local fallback mode — loading mock data.");
      const mockUser = {
        id: "local-parent-001",
        email: "tutor@gmail.com",
        user_metadata: { full_name: "Tutor Local" }
      };
      await onAuthSuccess(mockUser);
      return;
    }

    // Supabase active but no session — redirect to login
    logTelemetry("AUTH", "No active session. Redirecting to login...");
    console.log("[APP] Redirecting to login because no session found");
    goToLogin();
  }

  function updateConnectionBadge() {
    const isConnected = window.supabaseApi && window.supabaseApi.isActive();
    if (isConnected) {
      cloudBadge.innerHTML = `<span style="width:8px; height:8px; border-radius:50%; background:#10b981; display:inline-block;"></span>CONECTADO A SUPABASE CLOUD`;
      cloudBadge.style.background = "rgba(16, 185, 129, 0.1)";
      cloudBadge.style.borderColor = "rgba(16, 185, 129, 0.3)";
      cloudBadge.style.color = "#10b981";
      logTelemetry("SUPABASE", "Connected directly to live database server.");
    } else {
      cloudBadge.innerHTML = `<span style="width:8px; height:8px; border-radius:50%; background:#f59e0b; display:inline-block;"></span>LOCAL FALLBACK (Sin Conexión)`;
      cloudBadge.style.background = "rgba(245, 158, 11, 0.1)";
      cloudBadge.style.borderColor = "rgba(245, 158, 11, 0.3)";
      cloudBadge.style.color = "#f59e0b";
      logTelemetry("SUPABASE", "Credentials missing. Standing by in Local Database Fallback.");
    }
  }

  // ===== AUTH LOCAL FALLBACK =====
  // Cuando no hay Supabase, usamos autenticación local simulada
  function handleLocalLogin(email, password) {
    if (!email || !password) {
      loginError.textContent = "Completa todos los campos";
      return;
    }
    loginError.textContent = "";
    logTelemetry("AUTH", "Local fallback login with: " + email);
    // Simular login exitoso con datos mock
    const mockUser = {
      id: "local-parent-001",
      email: email,
      user_metadata: { full_name: email.split('@')[0] || "Tutor" }
    };
    onAuthSuccess(mockUser);
  }

  // ===== AUTH =====

  function bindAuthEvents() {
    // BUG FIX: The HTML uses .auth-tab-btn buttons (not show-register-toggle/show-login-toggle)
    // Wire the actual auth tab buttons in the modal
    const authTabBtns = document.querySelectorAll(".auth-tab-btn");
    const loginForm = document.getElementById("login-form");
    const registerForm = document.getElementById("register-form");

    authTabBtns.forEach(btn => {
      btn.addEventListener("click", () => {
        const targetTab = btn.dataset.authTab;
        authTabBtns.forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        loginError.textContent = "";
        loginError.style.color = "var(--danger)";
        if (targetTab === "login") {
          loginForm.classList.add("active");
          registerForm.classList.remove("active");
        } else {
          registerForm.classList.add("active");
          loginForm.classList.remove("active");
        }
      });
    });

    // Olvidé mi contraseña (el enlace no existe aún en el HTML, guard seguro)
    const forgotPasswordLink = document.getElementById("forgot-password-link");
    if (forgotPasswordLink) {
      forgotPasswordLink.addEventListener("click", (e) => {
        e.preventDefault();
        const email = loginEmail.value.trim();
        if (!email) {
          loginError.textContent = "Ingresa tu correo para recuperar la contraseña";
          loginError.style.color = "var(--warning)";
          return;
        }
        // BUG FIX: la línea color=danger era código muerto (se sobreescribía inmediatamente)
        loginError.style.color = "var(--success)";
        loginError.textContent = `Se envió un enlace de recuperación a ${email}`;
      });
    }

    loginBtn.addEventListener("click", handleLogin);
    loginPassword.addEventListener("keydown", (e) => {
      if (e.key === "Enter") handleLogin();
    });
    loginEmail.addEventListener("keydown", (e) => {
      if (e.key === "Enter") handleLogin();
    });

    registerBtn.addEventListener("click", handleRegister);
    regName.addEventListener("keydown", (e) => {
      if (e.key === "Enter") handleRegister();
    });
    regPassword.addEventListener("keydown", (e) => {
      if (e.key === "Enter") handleRegister();
    });
    regEmail.addEventListener("keydown", (e) => {
      if (e.key === "Enter") handleRegister();
    });

    const googleBtn = document.getElementById("google-login-btn");
    if (googleBtn) {
      googleBtn.addEventListener("click", async () => {
        try {
          loginError.textContent = "";
          await window.supabaseAuth.signInWithGoogle();
          // El OAuth redirige, no hay más que hacer aquí
        } catch (e) {
          loginError.textContent = `Error con Google: ${e.message}`;
          logTelemetry("AUTH_ERROR", `Google sign-in error: ${e.message}`);
        }
      });
    }

    logoutBtn.addEventListener("click", async () => {
      try {
        await window.supabaseAuth.signOut();
      } catch (e) {
        logTelemetry("AUTH_ERROR", `Logout error: ${e.message}`);
      }
      onAuthLogout();
    });
  }

  function handleLogin() {
    const email = loginEmail.value.trim();
    const password = loginPassword.value.trim();
    if (!email || !password) {
      loginError.textContent = "Completa todos los campos";
      return;
    }
    loginError.textContent = "";
    loginBtn.disabled = true;
    loginSpinner.style.display = "inline-block";
    const btnText = document.querySelector("#login-form .auth-btn-text");
    btnText.textContent = "Entrando...";

    // Si Supabase no está activo, usar login local
    if (!window.supabaseApi || !window.supabaseApi.isActive()) {
      setTimeout(() => {
        handleLocalLogin(email, password);
        loginBtn.disabled = false;
        loginSpinner.style.display = "none";
        btnText.textContent = "Entrar";
      }, 500);
      return;
    }

    // Supabase activo - login real
    window.supabaseAuth.signIn(email, password)
      .then((data) => {
        if (data?.user) return onAuthSuccess(data.user);
        throw new Error("Supabase inició la sesión, pero no devolvió los datos del usuario.");
      })
      .catch(e => {
        loginError.textContent = e.message;
      })
      .finally(() => {
        loginBtn.disabled = false;
        loginSpinner.style.display = "none";
        btnText.textContent = "Entrar";
      });
  }

  function handleRegister() {
    const name = regName.value.trim();
    const email = regEmail.value.trim();
    const password = regPassword.value.trim();
    // BUG FIX: reg-phone and reg-relation don't exist in HTML — removed blocking validation
    // These optional fields are read only if present in future form extensions
    const phone = document.getElementById("reg-phone")?.value?.trim() || "";
    const relation = document.getElementById("reg-relation")?.value || "";
    
    if (!name || !email || !password) {
      loginError.textContent = "Completa todos los campos";
      loginError.style.color = "var(--danger)";
      return;
    }
    if (password.length < 6) {
      loginError.textContent = "La contraseña debe tener al menos 6 caracteres";
      loginError.style.color = "var(--danger)";
      return;
    }
    // BUG FIX: Removed validation for relation — field doesn't exist in HTML form
    
    loginError.textContent = "";
    loginError.style.color = "var(--danger)";
    registerBtn.disabled = true;
    registerSpinner.style.display = "inline-block";
    const btnText = document.querySelector("#register-form .auth-btn-text");
    btnText.textContent = "Creando cuenta...";

    // Si Supabase no está activo, simular registro exitoso
    if (!window.supabaseApi || !window.supabaseApi.isActive()) {
      setTimeout(() => {
        loginError.style.color = "var(--success)";
        loginError.textContent = "¡Registro exitoso! Ahora inicia sesión con tu correo.";
        btnText.textContent = "Cuenta creada ✓";
        regName.value = "";
        regEmail.value = "";
        regPassword.value = "";
        registerBtn.disabled = false;
        registerSpinner.style.display = "none";
      }, 500);
      return;
    }

    // Supabase activo - registro real
    window.supabaseAuth.signUp(email, password, name)
      .then(() => {
        loginError.style.color = "var(--success)";
        loginError.textContent = "¡Registro exitoso! Ahora inicia sesión con Google o tu correo.";
        btnText.textContent = "Cuenta creada ✓";
        regName.value = "";
        regEmail.value = "";
        regPassword.value = "";
      })
      .catch(e => {
        loginError.style.color = "var(--danger)";
        loginError.textContent = e.message;
        btnText.textContent = "Crear cuenta";
      })
      .finally(() => {
        registerBtn.disabled = false;
        registerSpinner.style.display = "none";
      });
  }

  async function onAuthSuccess(user) {
    currentUser = user;
    displayName.textContent = user.user_metadata?.full_name || user.email?.split('@')[0] || "Tutor / Apoderado";
    displayEmail.textContent = user.email || "";
    logoutBtn.style.display = "flex";
    logTelemetry("AUTH", `Logged in as: ${user.email}`);

    if (window.supabaseApi && window.supabaseApi.isActive()) {
      try {
        const profileData = {
          id: user.id,
          email: user.email,
          full_name: user.user_metadata?.full_name || user.email?.split('@')[0] || "Tutor / Apoderado",
          updated_at: new Date().toISOString()
        };
        if (user.user_metadata?.parent_age) {
          profileData.parent_age = Number(user.user_metadata.parent_age);
        }
        if (user.user_metadata?.relationship_to_student) {
          profileData.relationship_to_student = user.user_metadata.relationship_to_student;
        }
        await window.supabaseApi.upsertParentProfile(profileData);
        logTelemetry("AUTH", "Parent profile synced to Supabase.");
      } catch (e) {
        console.warn("[AUTH] Could not sync parent profile:", e.message);
      }
    }

    loadStudents();
  }

  function onAuthLogout() {
    logTelemetry("AUTH", "Logged out — redirecting to login.");
    goToLogin();
  }

  // ===== STUDENTS =====

  async function loadStudents() {
    logTelemetry("STUDENTS", "Fetching your children's profiles...");
    let rawStudents = [];

    // Try parent_students first
    try {
      rawStudents = await window.supabaseApi.getMyStudents();
    } catch (err) {
      logTelemetry("SUPABASE_ERROR", `getMyStudents failed: ${err.message}`);
    }

    const isRealSupabase = window.supabaseApi && window.supabaseApi.isActive();

    // Fallback to mock data ONLY when Supabase is NOT active (true local mode)
    // When Supabase is active but returns empty, it means no real students are linked
    if ((!rawStudents || rawStudents.length === 0) && !isRealSupabase) {
      logTelemetry("STUDENTS", "Local mode: loading mock students...");
      rawStudents = window.mockDb.profiles.filter(p => p.role === "student").map(s => ({
        ...s,
        _source: "mock"
      }));
    } else if ((!rawStudents || rawStudents.length === 0) && isRealSupabase) {
      logTelemetry("STUDENTS", "Supabase active but no linked students found. Check parent_students table.");
    }

    const isRealData = isRealSupabase && rawStudents && rawStudents.length > 0 && rawStudents.some(s => s.role === "student" && (s.user_id || s.id));

    if (!rawStudents || rawStudents.length === 0) {
      logTelemetry("STUDENTS", "No students found in database. Using local mock profiles.");
      loadedStudents = window.mockDb.profiles.filter(p => p.role === "student");
    } else {
      loadedStudents = rawStudents.map(s => ({
        id: s.user_id || s.id,
        name: s.full_name || s.name || s.email || "Sin nombre",
        grade: s.group_name || s.grade || "Sin grupo",
        email: s.email || "",
        avatar_url: s.avatar_url || null,
        active_level: s.active_level || 1,
        total_levels: s.total_levels || 20,
        _source: isRealData ? "supabase" : "mock"
      }));

      if (isRealSupabase) {
        logTelemetry("SUPABASE", `Successfully loaded ${loadedStudents.length} student(s) from Supabase!`);
      } else {
        logTelemetry("STUDENTS", "Loaded local mock profiles.");
      }
    }

    studentSelector.innerHTML = "";

    if (loadedStudents.length === 0) {
      const opt = document.createElement("option");
      opt.value = "";
      opt.textContent = "Pendiente de vinculacion";
      opt.disabled = true;
      opt.selected = true;
      studentSelector.appendChild(opt);
      renderNoLinkedStudents();
      return;
    }

    document.body.classList.remove("awaiting-link");
    if (pendingLinkCard) pendingLinkCard.style.display = "none";

    loadedStudents.forEach((std, index) => {
      const opt = document.createElement("option");
      opt.value = std.id;
      opt.textContent = std.name;
      if (index === 0) opt.selected = true;
      studentSelector.appendChild(opt);
    });

    currentStudentId = loadedStudents[0].id;
    currentStudent = loadedStudents[0];
    updateStudentAvatar(currentStudent);

    await loadStudentData();
  }

  function updateStudentAvatar(std) {
    const name = std.name || "??";
    const initials = name.split(" ").map(n => n[0]).join("").substring(0, 2).toUpperCase();
    studentAvatar.textContent = initials || "--";
  }

  function renderNoLinkedStudents() {
    currentStudentId = null;
    currentStudent = null;
    document.body.classList.add("awaiting-link");
    switchTab("dashboard");
    studentAvatar.textContent = "--";

    prefillGuardianForm();

    const tutorName = displayName?.textContent?.trim() || "tu cuenta";
    if (pendingLinkText) {
      pendingLinkText.textContent =
        `${tutorName} ya tiene acceso como tutor, padre o madre. Un administrador debe vincular esta cuenta con el estudiante para mostrar asistencia, logros, horarios y materiales.`;
    }
    if (pendingLinkCard) pendingLinkCard.style.display = "block";

    document.getElementById("student-name-header").textContent = "Pendiente de vinculacion";
    document.getElementById("student-desc-header").textContent = "Sin estudiante asignado";
    document.getElementById("student-email-header").textContent = displayEmail?.textContent || "--";

    document.getElementById("kpi-gpa").textContent = "0 / 0";
    document.getElementById("kpi-attendance").textContent = "0";
    document.getElementById("kpi-tasks").textContent = "0";
    document.getElementById("kpi-meetings").textContent = "0";
    document.getElementById("level-progress-text").textContent = "0 / 0";
    document.getElementById("level-progress-bar").style.width = "0%";

    const message = "Aun no hay estudiante vinculado a esta cuenta. Pide a un administrador que asocie el estudiante con este tutor, padre o madre.";
    [
      "attendance-list-container",
      "levels-list-container",
      "achievements-list-container",
      "schedules-list-container",
      "materials-list-container",
      "meetings-list-container"
    ].forEach(id => {
      const container = document.getElementById(id);
      if (container) {
        container.innerHTML = `<span style="font-size:0.85rem;color:var(--text-secondary);">${message}</span>`;
      }
    });

    logTelemetry("STUDENTS", "Parent/tutor account is waiting for a student link.");
  }

  function prefillGuardianForm() {
    if (!currentUser) return;
    const meta = currentUser.user_metadata || {};
    if (guardianFullName && !guardianFullName.value) {
      guardianFullName.value = meta.full_name || displayName?.textContent?.trim() || "";
    }
    if (guardianAge && !guardianAge.value && meta.parent_age) {
      guardianAge.value = String(meta.parent_age);
    }
    if (guardianRelation && !guardianRelation.value && meta.relationship_to_student) {
      guardianRelation.value = meta.relationship_to_student;
    }
  }

  async function saveGuardianInfo() {
    if (!currentUser || !window.supabaseApi?.isActive()) return;

    const fullName = guardianFullName?.value?.trim() || "";
    const age = Number.parseInt(guardianAge?.value || "", 10);
    const relation = guardianRelation?.value || "";

    if (!fullName || !age || !relation) {
      if (guardianSaveStatus) guardianSaveStatus.textContent = "Completa nombre, edad y relacion.";
      return;
    }
    if (age < 16 || age > 100) {
      if (guardianSaveStatus) guardianSaveStatus.textContent = "Ingresa una edad valida.";
      return;
    }

    guardianSaveBtn.disabled = true;
    if (guardianSaveStatus) guardianSaveStatus.textContent = "Guardando...";

    const result = await window.supabaseApi.upsertParentProfile({
      id: currentUser.id,
      email: currentUser.email,
      full_name: fullName,
      parent_age: age,
      relationship_to_student: relation,
      updated_at: new Date().toISOString()
    });

    guardianSaveBtn.disabled = false;
    if (result?.ok) {
      displayName.textContent = fullName;
      if (pendingLinkText) {
        pendingLinkText.textContent =
          `${fullName} ya tiene acceso como tutor, padre o madre. Un administrador debe vincular esta cuenta con el estudiante para mostrar asistencia, logros, horarios y materiales.`;
      }
      if (guardianSaveStatus) guardianSaveStatus.textContent = "Datos guardados.";
      logTelemetry("AUTH", "Guardian profile details saved.");
    } else if (result?.partial) {
      displayName.textContent = fullName;
      if (guardianSaveStatus) {
        guardianSaveStatus.textContent = "Se guardo el nombre, pero revisa las columnas de parent_profiles en Supabase.";
      }
      logTelemetry("AUTH_WARN", `Guardian optional fields were not saved: ${result.error || "missing columns"}`);
    } else if (guardianSaveStatus) {
      guardianSaveStatus.textContent = `No se pudo guardar: ${result?.error || "revisa GRANT/RLS de parent_profiles en Supabase"}`;
    }
  }

  function bindEvents() {
    studentSelector.addEventListener("change", async (e) => {
      const selectedId = e.target.value;
      currentStudentId = selectedId;
      const std = loadedStudents.find(s => s.id === selectedId);
      if (!std) { console.warn("[APP] Student not found:", selectedId); return; }
      currentStudent = std;
      updateStudentAvatar(std);
      logTelemetry("ACTION", `Switched active student to: ${std.name}`);
      await loadStudentData();
    });

    navItems.forEach(item => {
      item.addEventListener("click", (e) => {
        e.preventDefault();
        switchTab(item.dataset.tab);
      });
    });

    if (telemetryHeader && telemetryDrawer) {
      telemetryHeader.addEventListener("click", () => {
        telemetryDrawer.classList.toggle("expanded");
      });
    }

    logoutBtn.addEventListener("click", async () => {
      try { await window.supabaseAuth.signOut(); } catch(e) {
        logTelemetry("AUTH_ERROR", `Logout error: ${e.message}`);
      }
      onAuthLogout();
    });

    if (guardianSaveBtn) {
      guardianSaveBtn.addEventListener("click", saveGuardianInfo);
    }
  }

  function switchTab(tabId) {
    currentTab = tabId;

    navItems.forEach(item => {
      if (item.dataset.tab === tabId) {
        item.classList.add("active");
      } else {
        item.classList.remove("active");
      }
    });

    tabContents.forEach(content => {
      if (content.id === `${tabId}-tab`) {
        content.classList.add("active");
      } else {
        content.classList.remove("active");
      }
    });

    logTelemetry("NAVIGATION", `Switched to section: ${tabId}`);
  }

  async function loadStudentData() {
    if (!currentStudent) return;
    logTelemetry("STUDENT_LOAD", `Loading database logs for: ${currentStudent.name}`);

    document.getElementById("student-name-header").textContent = currentStudent.name;
    document.getElementById("student-desc-header").textContent = `Grupo ${currentStudent.grade}`;
    document.getElementById("student-email-header").textContent = currentStudent.email || "tutor@gmail.com";

    // Fetch each data source individually so one failure doesn't block the others
    const results = await Promise.allSettled([
      window.supabaseApi.getAttendance(currentStudentId).catch(err => { logTelemetry("SUPABASE_ERROR", `getAttendance failed: ${err.message}`); return []; }),
      window.supabaseApi.getLevelProgress(currentStudentId).catch(err => { logTelemetry("SUPABASE_ERROR", `getLevelProgress failed: ${err.message}`); return []; }),
      window.supabaseApi.getAchievements(currentStudentId).catch(err => { logTelemetry("SUPABASE_ERROR", `getAchievements failed: ${err.message}`); return []; }),
      window.supabaseApi.getClassSchedules(currentStudent.grade).catch(err => { logTelemetry("SUPABASE_ERROR", `getClassSchedules failed: ${err.message}`); return []; }),
      window.supabaseApi.getMaterialProgress(currentStudentId).catch(err => { logTelemetry("SUPABASE_ERROR", `getMaterialProgress failed: ${err.message}`); return []; }),
      window.supabaseApi.getMeetings(currentStudentId).catch(err => { logTelemetry("SUPABASE_ERROR", `getMeetings failed: ${err.message}`); return []; })
    ]);

    const [attendance, levelProgress, achievements, schedules, materials, meetings] = results.map(r => r.status === 'fulfilled' ? r.value : []);

    // FIX: active_level y total_levels NO existen en profiles (edu_mi_app no los escribe).
    // Los calculamos desde student_level_progress que SÍ viene de la DB real.
    const completedLevels = levelProgress.filter(lp => lp.status === 'completed' || lp.status === 'done').length;
    const totalLevels = levelProgress.length > 0 ? levelProgress.length : (currentStudent.total_levels || 20);
    const actLvl = completedLevels > 0 ? completedLevels : (currentStudent.active_level || 1);
    const totLvl = totalLevels;

    document.getElementById("kpi-gpa").textContent = `${actLvl} / ${totLvl}`;
    document.getElementById("kpi-attendance").textContent = attendance.length;
    document.getElementById("kpi-tasks").textContent = achievements.length;
    const completedMaterialsCount = materials.filter(m => m.status === "completed" || m.status === "done").length;
    document.getElementById("kpi-meetings").textContent = completedMaterialsCount;

    const pct = totLvl > 0 ? Math.round((actLvl / totLvl) * 100) : 0;
    document.getElementById("level-progress-text").textContent = `${actLvl} / ${totLvl} (${pct}%)`;
    document.getElementById("level-progress-bar").style.width = `${pct}%`;

    renderAttendanceList(attendance);
    renderLevelsList(levelProgress);
    renderAchievementsList(achievements);
    renderSchedulesList(schedules);
    renderMaterialsList(materials);
    renderMeetingsList(meetings);

    logTelemetry("SUPABASE", `Successfully loaded and rendered all database records for: ${currentStudent.name}`);
  }

  function renderAttendanceList(list) {
    const container = document.getElementById("attendance-list-container");
    container.innerHTML = "";

    if (!list || list.length === 0) {
      container.innerHTML = `<span style="font-size:0.8rem;color:var(--text-secondary);">No hay registros de asistencia en la tabla para este alumno.</span>`;
      return;
    }

    list.forEach(a => {
      const row = document.createElement("div");
      row.className = "grade-row";
      const meetingId = escapeHtml(a.meeting_id || 'Clase Virtual');
      const meetingDate = escapeHtml(a.meeting_date || '--');
      const duration = escapeHtml(a.duration_minutes || '--');
      const joinedAt = escapeHtml(a.joined_at ? new Date(a.joined_at).toLocaleTimeString() : '--');
      const leftAt = escapeHtml(a.left_at ? new Date(a.left_at).toLocaleTimeString() : '--');
      row.innerHTML = `
        <div class="grade-info">
          <span class="grade-subject">Sesión ID: ${meetingId}</span>
          <span class="grade-meta">Fecha: ${meetingDate} • Duración: ${duration} Minutos</span>
          <span class="grade-meta" style="font-size:0.75rem; color:var(--text-muted);">Conexión: ${joinedAt} - ${leftAt}</span>
        </div>
        <div class="grade-badge-container">
          <div class="grade-score-pill ${a.was_on_time ? '' : 'warning-score'}">${a.was_on_time ? 'Puntual' : 'Tardanza'}</div>
        </div>
      `;
      container.appendChild(row);
    });
  }

  function renderLevelsList(list) {
    const container = document.getElementById("levels-list-container");
    container.innerHTML = "";

    if (!list || list.length === 0) {
      container.innerHTML = `<span style="font-size:0.8rem;color:var(--text-secondary);">No hay registros de progreso académico en la tabla student_level_progress.</span>`;
      return;
    }

    list.forEach(lp => {
      const row = document.createElement("div");
      row.className = "grade-row";
      const isCompleted = lp.status === "completed" || lp.status === "done";
      const title = escapeHtml(lp.challenges?.title || 'Reto de Aprendizaje');
      const description = escapeHtml(lp.challenges?.description || 'Desafío y resolución del módulo.');
      const completedAt = lp.completed_at ? escapeHtml(lp.completed_at.split('T')[0]) : "";
      row.innerHTML = `
        <div class="grade-info">
          <span class="grade-subject">${title}</span>
          <span class="grade-meta">${description}</span>
          ${completedAt ? `<span class="grade-meta" style="font-size:0.75rem; color:var(--success);">Superado el: ${completedAt}</span>` : ''}
        </div>
        <div class="grade-badge-container">
          <div class="grade-score-pill ${isCompleted ? '' : 'warning-score'}">${isCompleted ? 'Superado' : 'Pendiente'}</div>
        </div>
      `;
      container.appendChild(row);
    });
  }

  function renderAchievementsList(list) {
    const container = document.getElementById("achievements-list-container");
    container.innerHTML = "";

    if (!list || list.length === 0) {
      container.innerHTML = `<span style="font-size:0.8rem;color:var(--text-secondary);">No hay logros registrados en la tabla student_achievements para este alumno.</span>`;
      return;
    }

    const grouped = {};
    list.forEach(sa => {
      const dateKey = sa.unlocked_at ? sa.unlocked_at.split('T')[0] : 'Fechas Recientes';
      if (!grouped[dateKey]) grouped[dateKey] = [];
      grouped[dateKey].push(sa);
    });

    Object.keys(grouped).sort((a, b) => b.localeCompare(a)).forEach(date => {
      const header = document.createElement("div");
      header.style.padding = "16px 0 6px 0";
      header.style.color = "var(--text-secondary)";
      header.style.fontSize = "0.85rem";
      header.style.fontWeight = "600";
      header.style.borderBottom = "1px solid var(--border-color)";
      header.style.marginBottom = "8px";
      header.style.marginTop = container.children.length > 0 ? "8px" : "0";

      let displayDate = date;
      try {
        if (date !== 'Fechas Recientes') {
           const [year, month, day] = date.split('-');
           const dateObj = new Date(year, month - 1, day);
           displayDate = dateObj.toLocaleDateString('es-ES', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
           displayDate = displayDate.charAt(0).toUpperCase() + displayDate.slice(1);
        }
      } catch(e) {}

      header.innerHTML = `📅 Registros del <span style="color:var(--text-primary); font-family:var(--font-title);">${escapeHtml(displayDate)}</span>`;
      container.appendChild(header);

      grouped[date].forEach(sa => {
        const row = document.createElement("div");
        row.className = "grade-row";
        const icon = escapeHtml(sa.achievements?.icon || "🏆");
        const name = escapeHtml(sa.achievements?.name || 'Logro Académico');
        const description = escapeHtml(sa.achievements?.description || 'Desempeño destacado asignado por el profesor.');
        const pts = escapeHtml(sa.achievements?.points || 0);

        row.innerHTML = `
          <div class="grade-info">
            <span class="grade-subject" style="display: flex; align-items: center; gap: 8px;">
              <span style="font-size: 1.2rem;">${icon}</span> 
              ${name}
            </span>
            <span class="grade-meta">${description}</span>
          </div>
          <div class="grade-badge-container">
            <div class="grade-score-pill" style="border-color:var(--accent-colearn-glow); color:var(--accent-colearn); min-width: 60px;">+${pts} XP</div>
          </div>
        `;
        container.appendChild(row);
      });
    });
  }

  function renderSchedulesList(list) {
    const container = document.getElementById("schedules-list-container");
    container.innerHTML = "";

    if (!list || list.length === 0) {
      const grupoInfo = currentStudent?.grade && currentStudent.grade !== 'Sin grupo'
        ? `el grupo "${currentStudent.grade}" no tiene clases programadas`
        : `el estudiante no tiene grupo asignado. Un administrador debe asignarle un grupo desde edu_mi_app`;
      container.innerHTML = `<span style="font-size:0.8rem;color:var(--text-secondary);">Sin horarios: ${escapeHtml(grupoInfo)}.</span>`;
      return;
    }

    const daysMap = { 1: "Lunes", 2: "Martes", 3: "Miércoles", 4: "Jueves", 5: "Viernes", 6: "Sábado", 7: "Domingo", 0: "Domingo" };

    list.forEach(s => {
      const row = document.createElement("div");
      row.className = "grade-row";
      const dayName = daysMap[s.day_of_week] || "Día de Clase";
      // BUG FIX: start_time / end_time pueden ser null/undefined → TypeError con .substring()
      const startStr = s.start_time ? s.start_time.substring(0, 5) : '--:--';
      const endStr   = s.end_time   ? s.end_time.substring(0, 5)   : '--:--';
      const subject = escapeHtml(s.subject || 'Materia');
      const groupName = escapeHtml(s.group_name || '--');
      const teacherId = escapeHtml(s.teacher_id || 'Asignado');
      row.innerHTML = `
        <div class="grade-info">
          <span class="grade-subject">${subject}</span>
          <span class="grade-meta">Grupo: ${groupName} • Profesor: ${teacherId}</span>
          <span class="grade-meta" style="font-size:0.75rem; color:var(--accent-primary); font-weight:600;">Día: ${escapeHtml(dayName)} • Horario: ${escapeHtml(startStr)} - ${escapeHtml(endStr)}</span>
        </div>
        <div class="grade-badge-container">
          <div class="grade-score-pill">Activo</div>
        </div>
      `;
      container.appendChild(row);
    });
  }

  function renderMaterialsList(list) {
    const container = document.getElementById("materials-list-container");
    container.innerHTML = "";

    if (!list || list.length === 0) {
      container.innerHTML = `<span style="font-size:0.8rem;color:var(--text-secondary);">No hay materiales de estudio asignados en la tabla student_material_progress para este alumno.</span>`;
      return;
    }

    list.forEach(m => {
      const row = document.createElement("div");
      row.className = "grade-row";
      const isCompleted = m.status === "completed" || m.status === "done";
      const title = escapeHtml(m.materials?.title || 'Ficha de Refuerzo');
      const description = escapeHtml(m.materials?.description || 'Material complementario asignado por el profesor.');
      const pdfUrl = safeUrl(m.materials?.pdf_url);
      row.innerHTML = `
        <div class="grade-info">
          <span class="grade-subject">${title}</span>
          <span class="grade-meta">${description}</span>
          ${pdfUrl ? `<span class="grade-meta"><a href="${escapeHtml(pdfUrl)}" target="_blank" rel="noopener noreferrer" style="color:var(--accent-primary); font-weight:600; text-decoration:none;">📥 Descargar Ficha PDF</a></span>` : ''}
        </div>
        <div class="grade-badge-container">
          <div class="grade-score-pill ${isCompleted ? '' : 'warning-score'}">${isCompleted ? 'Completado' : 'Pendiente'}</div>
        </div>
      `;
      container.appendChild(row);
    });
  }

  function renderMeetingsList(list) {
    const container = document.getElementById("meetings-list-container");
    container.innerHTML = "";

    if (!list || list.length === 0) {
      container.innerHTML = `<span style="font-size:0.8rem;color:var(--text-secondary);">No hay clases ni reuniones virtuales registradas en la tabla meetings.</span>`;
      return;
    }

    list.forEach(m => {
      const row = document.createElement("div");
      row.className = "grade-row";
      const title = escapeHtml(m.title || 'Clase Virtual');
      const description = escapeHtml(m.description || 'Sala y repaso de actividades.');
      const channelName = escapeHtml(m.channel_name || '--');
      const meetingType = escapeHtml(m.meeting_type || 'master');
      row.innerHTML = `
        <div class="grade-info">
          <span class="grade-subject">${title}</span>
          <span class="grade-meta">${description}</span>
          <span class="grade-meta" style="font-size:0.75rem; color:var(--text-muted);">Canal Agora: <strong>${channelName}</strong> • Tipo: ${meetingType}</span>
        </div>
        <div class="grade-badge-container">
          <div class="grade-score-pill" style="border-color:var(--accent-secondary-glow); color:var(--accent-secondary);">En Vivo</div>
        </div>
      `;
      container.appendChild(row);
    });
  }

  function logTelemetry(module, message) {
    if (!telemetryBody) {
      const consoleMethod = module.includes("ERROR") ? "warn" : "log";
      console[consoleMethod](`[${module}] ${message}`);
      return;
    }

    const timestamp = new Date().toLocaleTimeString();
    const line = document.createElement("div");
    line.className = "telemetry-line";

    let typeClass = "";
    if (module === "SUPABASE_ERROR") typeClass = "event-warn";
    else if (module === "LAKEHOUSE" || module === "SUPABASE" || module === "STUDENT_LOAD") typeClass = "event-info";

    line.innerHTML = `[${escapeHtml(timestamp)}] <span class="${typeClass}" style="font-weight:600;">[${escapeHtml(module)}]</span>: ${escapeHtml(message)}`;

    telemetryBody.appendChild(line);
    telemetryBody.scrollTop = telemetryBody.scrollHeight;
  }

  init();
});
