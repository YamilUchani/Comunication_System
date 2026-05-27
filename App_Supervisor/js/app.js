document.addEventListener("DOMContentLoaded", () => {
  let currentStudentId = null;
  let currentStudent = null;
  let currentTab = "dashboard";
  let loadedStudents = [];

  const studentSelector = document.getElementById("student-select");
  const studentAvatar = document.getElementById("header-avatar");
  const navItems = document.querySelectorAll(".nav-links li");
  const tabContents = document.querySelectorAll(".tab-content");
  const telemetryBody   = document.getElementById("telemetry-body");
  const telemetryDrawer  = document.getElementById("telemetry-drawer");
  const telemetryHeader  = document.getElementById("telemetry-header");
  const cloudBadge       = document.getElementById("cloud-status-badge");
  const displayName      = document.getElementById("user-display-name");
  const displayEmail     = document.getElementById("user-display-email");
  const loginModal       = document.getElementById("login-modal");
  const loginError       = document.getElementById("login-error");
  const authTabBtns      = document.querySelectorAll(".auth-tab-btn");
  const authForms        = document.querySelectorAll(".auth-form");
  const loginBtn         = document.getElementById("login-btn");
  const registerBtn      = document.getElementById("register-btn");
  const logoutBtn        = document.getElementById("logout-btn");
  const loginEmail       = document.getElementById("login-email");
  const loginPassword    = document.getElementById("login-password");
  const regName          = document.getElementById("reg-name");
  const regEmail         = document.getElementById("reg-email");
  const regPassword      = document.getElementById("reg-password");
  const authLoader       = document.getElementById("auth-loader");
  const authBtnText      = document.querySelectorAll(".auth-btn-text");
  const loginSpinner     = document.getElementById("login-spinner");
  const registerSpinner  = document.getElementById("register-spinner");

  async function init() {
    logTelemetry("SYSTEM", "Initializing parents database explorer...");

    if (window.supabaseApi && window.supabaseApi.isActive()) {
      cloudBadge.innerHTML = `<span style="width:8px; height:8px; border-radius:50%; background:#10b981; display:inline-block;"></span>CONECTADO A SUPABASE CLOUD`;
      cloudBadge.style.background = "rgba(16, 185, 129, 0.1)";
      cloudBadge.style.borderColor = "rgba(16, 185, 129, 0.3)";
      cloudBadge.style.color = "#10b981";
      logTelemetry("SUPABASE", "Connected directly to live database server.");
    } else {
      logTelemetry("SUPABASE", "Credentials missing. Standing by in Local Database Fallback.");
    }

    // Check existing session
    const session = await window.supabaseAuth.getSession();
    if (session) {
      const user = window.supabaseAuth.getCurrentUser();
      if (user) {
        onAuthSuccess(user);
        return;
      }
    }

    // Listen for auth changes (login from another tab, etc.)
    window.supabaseAuth.onAuthChange((event, session) => {
      if (event === "SIGNED_IN" && session) {
        const user = window.supabaseAuth.getCurrentUser();
        if (user) onAuthSuccess(user);
      } else if (event === "SIGNED_OUT") {
        onAuthLogout();
      }
    });

    // Show login modal
    loginModal.classList.add("active");
    bindAuthEvents();
    bindEvents();
  }

  // ===== AUTH =====

  function bindAuthEvents() {
    authTabBtns.forEach(btn => {
      btn.addEventListener("click", () => {
        const tab = btn.dataset.authTab;
        authTabBtns.forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        authForms.forEach(f => f.classList.remove("active"));
        document.getElementById(`${tab}-form`).classList.add("active");
        loginError.textContent = "";
      });
    });

    loginBtn.addEventListener("click", handleLogin);
    loginPassword.addEventListener("keydown", (e) => {
      if (e.key === "Enter") handleLogin();
    });
    loginEmail.addEventListener("keydown", (e) => {
      if (e.key === "Enter") handleLogin();
    });

    registerBtn.addEventListener("click", handleRegister);
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

  async function handleLogin() {
    const email = loginEmail.value.trim();
    const password = loginPassword.value.trim();
    if (!email || !password) {
      loginError.textContent = "Completa todos los campos";
      return;
    }
    loginError.textContent = "";
    loginBtn.disabled = true;
    loginSpinner.style.display = "inline-block";
    document.querySelector("#login-form .auth-btn-text").textContent = "Entrando...";

    try {
      await window.supabaseAuth.signIn(email, password);
      const user = window.supabaseAuth.getCurrentUser();
      if (user) onAuthSuccess(user);
    } catch (e) {
      loginError.textContent = e.message;
    } finally {
      loginBtn.disabled = false;
      loginSpinner.style.display = "none";
      document.querySelector("#login-form .auth-btn-text").textContent = "Entrar";
    }
  }

  async function handleRegister() {
    const name = regName.value.trim();
    const email = regEmail.value.trim();
    const password = regPassword.value.trim();
    if (!name || !email || !password) {
      loginError.textContent = "Completa todos los campos";
      return;
    }
    if (password.length < 6) {
      loginError.textContent = "La contraseña debe tener al menos 6 caracteres";
      return;
    }
    loginError.textContent = "";
    registerBtn.disabled = true;
    registerSpinner.style.display = "inline-block";
    document.querySelector("#register-form .auth-btn-text").textContent = "Registrando...";

    try {
      await window.supabaseAuth.signUp(email, password, name);
      loginError.style.color = "var(--success)";
      loginError.textContent = "Registro exitoso. Revisa tu correo para confirmar la cuenta.";
      document.querySelector("#register-form .auth-btn-text").textContent = "Registrado ✓";
    } catch (e) {
      loginError.style.color = "var(--danger)";
      loginError.textContent = e.message;
      document.querySelector("#register-form .auth-btn-text").textContent = "Registrarse";
    } finally {
      registerBtn.disabled = false;
      registerSpinner.style.display = "none";
    }
  }

  async function onAuthSuccess(user) {
    loginModal.classList.remove("active");
    displayName.textContent = user.user_metadata?.full_name || "Padre Acompañante";
    displayEmail.textContent = user.email || "";
    logoutBtn.style.display = "flex";
    logTelemetry("AUTH", `Logged in as: ${user.email}`);

    // Asegurar que existe un perfil role='parent' (sobre todo para OAuth)
    try {
      const { data: existing } = await supabaseClient
        .from("profiles")
        .select("id")
        .eq("id", user.id)
        .maybeSingle();
      if (!existing && window.supabaseApi.isActive()) {
        await supabaseClient.from("profiles").upsert({
          id: user.id,
          user_id: user.id,
          email: user.email,
          full_name: user.user_metadata?.full_name || "",
          role: "parent"
        }, { onConflict: "id" });
        logTelemetry("AUTH", "Profile created for OAuth user");
      }
    } catch (e) {
      console.warn("[AUTH] Could not verify/create profile:", e.message);
    }

    loadStudents();
  }

  function onAuthLogout() {
    displayName.textContent = "Cerrando sesión...";
    displayEmail.textContent = "";
    logoutBtn.style.display = "none";
    currentStudentId = null;
    currentStudent = null;
    loadedStudents = [];
    studentSelector.innerHTML = '<option value="" disabled selected>Cargando...</option>';
    studentAvatar.textContent = "--";
    document.getElementById("student-name-header").textContent = "--";
    document.getElementById("student-desc-header").textContent = "--";
    document.getElementById("student-email-header").textContent = "--";
    document.getElementById("kpi-gpa").textContent = "--";
    document.getElementById("kpi-attendance").textContent = "--";
    document.getElementById("kpi-tasks").textContent = "--";
    document.getElementById("kpi-meetings").textContent = "--";
    document.getElementById("level-progress-text").textContent = "0 / 0";
    document.getElementById("level-progress-bar").style.width = "0%";
    document.getElementById("attendance-list-container").innerHTML = "";
    document.getElementById("levels-list-container").innerHTML = "";
    document.getElementById("achievements-list-container").innerHTML = "";
    document.getElementById("schedules-list-container").innerHTML = "";
    document.getElementById("materials-list-container").innerHTML = "";
    document.getElementById("meetings-list-container").innerHTML = "";
    loginModal.classList.add("active");
    loginError.textContent = "";
    loginError.style.color = "var(--danger)";
    loginEmail.value = "";
    loginPassword.value = "";
    logTelemetry("AUTH", "Logged out");
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

    // Fallback to getStudents if parent_students empty or fails
    if (!rawStudents || rawStudents.length === 0) {
      logTelemetry("STUDENTS", "No linked students found, trying all students...");
      try {
        rawStudents = await window.supabaseApi.getStudents();
      } catch (err) {
        logTelemetry("SUPABASE_ERROR", `Failed to query profiles: ${err.message}`);
      }
    }

    const isRealSupabase = rawStudents && rawStudents.length > 0 && rawStudents.some(s => s.role === "student" && (s.user_id || s.id));

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
        _source: isRealSupabase ? "supabase" : "mock"
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
      opt.textContent = "Sin estudiantes disponibles";
      opt.disabled = true;
      studentSelector.appendChild(opt);
      return;
    }

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
    const initials = std.name.split(" ").map(n => n[0]).join("").substring(0, 2).toUpperCase();
    studentAvatar.textContent = initials;
  }

  function bindEvents() {
    studentSelector.addEventListener("change", async (e) => {
      currentStudentId = e.target.value;
      const std = loadedStudents.find(s => s.id === currentStudentId);
      if (!std) return;
      currentStudent = std;
      updateStudentAvatar(std);

      logTelemetry("ACTION", `Switched active student to: ${std.name}`);
      await loadStudentData();
    });

    navItems.forEach(item => {
      item.addEventListener("click", (e) => {
        e.preventDefault();
        const tab = item.dataset.tab;
        switchTab(tab);
      });
    });

    telemetryHeader.addEventListener("click", () => {
      telemetryDrawer.classList.toggle("expanded");
    });
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

    const [attendance, levelProgress, achievements, schedules, materials, meetings] = await Promise.all([
      window.supabaseApi.getAttendance(currentStudentId),
      window.supabaseApi.getLevelProgress(currentStudentId),
      window.supabaseApi.getAchievements(currentStudentId),
      window.supabaseApi.getClassSchedules(currentStudent.grade),
      window.supabaseApi.getMaterialProgress(currentStudentId),
      window.supabaseApi.getMeetings(currentStudentId)
    ]);

    const actLvl = currentStudent.active_level || 1;
    const totLvl = currentStudent.total_levels || 20;
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
      row.innerHTML = `
        <div class="grade-info">
          <span class="grade-subject">Sesión ID: ${a.meeting_id || 'Clase Virtual'}</span>
          <span class="grade-meta">Fecha: ${a.meeting_date} • Duración: ${a.duration_minutes || '--'} Minutos</span>
          <span class="grade-meta" style="font-size:0.75rem; color:var(--text-muted);">Conexión: ${a.joined_at ? new Date(a.joined_at).toLocaleTimeString() : '--'} - ${a.left_at ? new Date(a.left_at).toLocaleTimeString() : '--'}</span>
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
      row.innerHTML = `
        <div class="grade-info">
          <span class="grade-subject">${lp.challenges?.title || 'Reto de Aprendizaje'}</span>
          <span class="grade-meta">${lp.challenges?.description || 'Desafío y resolución del módulo.'}</span>
          ${lp.completed_at ? `<span class="grade-meta" style="font-size:0.75rem; color:var(--success);">Superado el: ${lp.completed_at.split('T')[0]}</span>` : ''}
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

      header.innerHTML = `📅 Registros del <span style="color:var(--text-primary); font-family:var(--font-title);">${displayDate}</span>`;
      container.appendChild(header);

      grouped[date].forEach(sa => {
        const row = document.createElement("div");
        row.className = "grade-row";
        const icon = sa.achievements?.icon || "🏆";
        const pts = sa.achievements?.points || 0;

        row.innerHTML = `
          <div class="grade-info">
            <span class="grade-subject" style="display: flex; align-items: center; gap: 8px;">
              <span style="font-size: 1.2rem;">${icon}</span> 
              ${sa.achievements?.name || 'Logro Académico'}
            </span>
            <span class="grade-meta">${sa.achievements?.description || 'Desempeño destacado asignado por el profesor.'}</span>
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
      container.innerHTML = `<span style="font-size:0.8rem;color:var(--text-secondary);">No hay horarios de clase registrados en la tabla class_schedules para el grupo de este alumno.</span>`;
      return;
    }

    const daysMap = { 1: "Lunes", 2: "Martes", 3: "Miércoles", 4: "Jueves", 5: "Viernes", 6: "Sábado", 7: "Domingo", 0: "Domingo" };

    list.forEach(s => {
      const row = document.createElement("div");
      row.className = "grade-row";
      const dayName = daysMap[s.day_of_week] || "Día de Clase";
      row.innerHTML = `
        <div class="grade-info">
          <span class="grade-subject">${s.subject}</span>
          <span class="grade-meta">Grupo: ${s.group_name} • Profesor ID: ${s.teacher_id || 'Profesor asignado'}</span>
          <span class="grade-meta" style="font-size:0.75rem; color:var(--accent-primary); font-weight:600;">Día: ${dayName} • Horario: ${s.start_time.substring(0, 5)} - ${s.end_time.substring(0, 5)}</span>
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
      row.innerHTML = `
        <div class="grade-info">
          <span class="grade-subject">${m.materials?.title || 'Ficha de Refuerzo'}</span>
          <span class="grade-meta">${m.materials?.description || 'Material complementario asignado por el profesor.'}</span>
          ${m.materials?.pdf_url ? `<span class="grade-meta"><a href="${m.materials.pdf_url}" style="color:var(--accent-primary); font-weight:600; text-decoration:none;">📥 Descargar Ficha PDF</a></span>` : ''}
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
      row.innerHTML = `
        <div class="grade-info">
          <span class="grade-subject">${m.title || 'Clase Virtual'}</span>
          <span class="grade-meta">${m.description || 'Sala y repaso de actividades.'}</span>
          <span class="grade-meta" style="font-size:0.75rem; color:var(--text-muted);">Canal Agora: <strong>${m.channel_name || '--'}</strong> • Tipo: ${m.meeting_type || 'master'}</span>
        </div>
        <div class="grade-badge-container">
          <div class="grade-score-pill" style="border-color:var(--accent-secondary-glow); color:var(--accent-secondary);">En Vivo</div>
        </div>
      `;
      container.appendChild(row);
    });
  }

  function logTelemetry(module, message) {
    const timestamp = new Date().toLocaleTimeString();
    const line = document.createElement("div");
    line.className = "telemetry-line";

    let typeClass = "";
    if (module === "SUPABASE_ERROR") typeClass = "event-warn";
    else if (module === "LAKEHOUSE" || module === "SUPABASE" || module === "STUDENT_LOAD") typeClass = "event-info";

    line.innerHTML = `[${timestamp}] <span class="${typeClass}" style="font-weight:600;">[${module}]</span>: ${message}`;

    telemetryBody.appendChild(line);
    telemetryBody.scrollTop = telemetryBody.scrollHeight;
  }

  init();
});