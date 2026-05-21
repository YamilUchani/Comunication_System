// Educational Platform - Core Controller
// Integrates client routing, dynamic SVG, Supabase data fetching, Firebase Auth, and Render Express API evaluation.

document.addEventListener("DOMContentLoaded", () => {
  // State variables
  let currentStudentId = "std-01";
  let currentTab = "dashboard";
  let currentMode = "supervisor"; // "supervisor" or "colearn"
  let selectedTeacherId = "tch-1";
  let currentGrades = [];
  
  // Canvas drawing variables for Whiteboard
  let isDrawing = false;
  let lastX = 0;
  let lastY = 0;
  let drawColor = "#8b5cf6"; // Violet as default
  
  // Cache DOM Elements
  const studentSelector = document.getElementById("student-select");
  const studentAvatar = document.getElementById("header-avatar");
  const roleToggleSlider = document.querySelector(".role-slider");
  const roleOptions = document.querySelectorAll(".role-option");
  const navItems = document.querySelectorAll(".nav-links li");
  const tabContents = document.querySelectorAll(".tab-content");
  const alertBannerContainer = document.getElementById("alert-banner-container");
  const telemetryBody = document.querySelector(".telemetry-body");
  const telemetryDrawer = document.querySelector(".telemetry-drawer");
  const telemetryHeader = document.querySelector(".telemetry-header");
  const cloudBadge = document.getElementById("cloud-status-badge");
  
  // Auth Elements
  const profileMenu = document.getElementById("user-profile-menu");
  const authModal = document.getElementById("auth-modal");
  const closeAuthBtn = document.getElementById("close-auth");
  const authForm = document.getElementById("auth-form");
  const userDisplayName = document.getElementById("user-display-name");
  const userDisplayEmail = document.getElementById("user-display-email");

  // Local/Render server endpoint configuration
  // Render URL placeholder (Change this to your actual Render service URL, e.g., https://app-supervisor.onrender.com)
  const BACKEND_API_BASE = "http://localhost:10000"; 
  
  // Initialize App
  function init() {
    logTelemetry("SYSTEM", "Initializing educational platform core v1.0.0 (MVP)...");
    
    // Check Supabase Cloud SDK Status
    if (window.supabaseApi && window.supabaseApi.isActive()) {
      cloudBadge.innerHTML = `<span style="width:8px; height:8px; border-radius:50%; background:#10b981; display:inline-block;"></span>CONECTADO A SUPABASE`;
      cloudBadge.style.background = "rgba(16, 185, 129, 0.1)";
      cloudBadge.style.borderColor = "rgba(16, 185, 129, 0.3)";
      cloudBadge.style.color = "#10b981";
      logTelemetry("SUPABASE", "Linked successfully to Supabase Database Tables (Priority 1).");
    } else {
      logTelemetry("SUPABASE", "Credentials missing. Standing by in Graceful Fallback Local Mode.");
    }
    
    // Check Firebase SDK Status
    if (window.firebaseApi && window.firebaseApi.isActive()) {
      logTelemetry("FIREBASE", "Connected to Firebase Authentication client (Priority 3).");
    } else {
      logTelemetry("FIREBASE", "Authentication operating under client simulation.");
    }
    
    bindEvents();
    loadStudentData();
    renderCalendar();
    renderTeachers();
    renderStore();
    initWhiteboard();
    
    logTelemetry("SYSTEM", "Platform ready. Logged in as parent: Mrs. Yamil Martinez.");
  }
  
  // Bind UI Events
  function bindEvents() {
    // Student switch
    studentSelector.addEventListener("change", (e) => {
      currentStudentId = e.target.value;
      const std = mockDb.students.find(s => s.id === currentStudentId);
      studentAvatar.textContent = std.avatar;
      
      logTelemetry("ACTION", `Switched active student profile to: ${std.name}`);
      
      loadStudentData();
      renderCalendar();
    });
    
    // Role switcher
    roleOptions.forEach(opt => {
      opt.addEventListener("click", () => {
        const mode = opt.dataset.role;
        switchMode(mode);
      });
    });
    
    // Navigation Tabs
    navItems.forEach(item => {
      item.addEventListener("click", (e) => {
        e.preventDefault();
        const tab = item.dataset.tab;
        switchTab(tab);
      });
    });
    
    // Telemetry drawer expand/collapse
    telemetryHeader.addEventListener("click", () => {
      telemetryDrawer.classList.toggle("expanded");
    });
    
    // Auth Modal triggers
    profileMenu.addEventListener("click", () => {
      authModal.style.display = "flex";
    });
    
    closeAuthBtn.addEventListener("click", () => {
      authModal.style.display = "none";
    });
    
    authForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      const email = document.getElementById("auth-email").value.trim();
      const pass = document.getElementById("auth-password").value.trim();
      
      logTelemetry("FIREBASE", `Executing authentication request for: ${email}`);
      const res = await window.firebaseApi.signIn(email, pass);
      
      if (res.success) {
        userDisplayName.textContent = res.user.displayName || "Parent Account";
        userDisplayEmail.textContent = res.user.email;
        logTelemetry("FIREBASE", `Logged in user: ${res.user.email} (UID: ${res.user.uid})`);
        authModal.style.display = "none";
        
        // Request Web Push permissions (Priority 3 FCM)
        logTelemetry("FIREBASE", "Registering client service-worker for Firebase Cloud Messaging notifications...");
        const pushToken = await window.firebaseApi.requestNotificationPermission();
        if (pushToken) {
          logTelemetry("FIREBASE", `Cloud messaging registered. Device push token: ${pushToken}`);
        }
      } else {
        alert(`Login failed: ${res.error}`);
        logTelemetry("FIREBASE_ERROR", `Failed login attempt for ${email}: ${res.error}`);
      }
    });
    
    // Message send listener
    document.getElementById("send-chat-btn").addEventListener("click", sendChatMessage);
    document.getElementById("chat-input").addEventListener("keypress", (e) => {
      if (e.key === "Enter") sendChatMessage();
    });
    
    // Discussion board post
    document.getElementById("post-btn").addEventListener("click", submitDiscussionPost);
    document.getElementById("discussion-input").addEventListener("keypress", (e) => {
      if (e.key === "Enter") submitDiscussionPost();
    });
    
    // Meeting scheduler form
    document.getElementById("scheduler-form").addEventListener("submit", bookMeeting);
    
    // NPS score selection
    const npsBtns = document.querySelectorAll(".nps-btn");
    npsBtns.forEach(btn => {
      btn.addEventListener("click", () => {
        npsBtns.forEach(b => b.classList.remove("selected"));
        btn.classList.add("selected");
        const score = btn.dataset.score;
        submitNPS(score);
      });
    });
    
    // Checkout modal actions
    document.getElementById("close-checkout").addEventListener("click", closeCheckout);
    document.getElementById("cancel-checkout").addEventListener("click", closeCheckout);
    document.getElementById("checkout-form").addEventListener("submit", processMockPayment);

    // Responsive SVG Chart resize binding
    window.addEventListener("resize", () => {
      if (currentTab === "dashboard" && currentGrades.length > 0) {
        renderPerformanceChart(currentGrades);
      }
    });
  }
  
  // Switch Navigation Tab
  function switchTab(tabId) {
    currentTab = tabId;
    
    // Update nav layout
    navItems.forEach(item => {
      if (item.dataset.tab === tabId) {
        item.classList.add("active");
      } else {
        item.classList.remove("active");
      }
    });
    
    // Update view container
    tabContents.forEach(content => {
      if (content.id === `${tabId}-tab`) {
        content.classList.add("active");
      } else {
        content.classList.remove("active");
      }
    });
    
    logTelemetry("NAVIGATION", `Navigated to section: ${tabId}`);
    
    // Refresh graphics or views if needed
    if (tabId === "dashboard") {
      loadStudentData(); // Refresh and re-evaluate
    } else if (tabId === "tasks") {
      renderTasks();
    }
  }
  
  // Switch Dual Role Mode (Supervisor vs Co-Aprendiz)
  function switchMode(mode) {
    if (currentMode === mode) return;
    currentMode = mode;
    
    // Update switcher UI
    roleOptions.forEach(opt => opt.classList.remove("active"));
    const activeOpt = document.querySelector(`.role-option[data-role="${mode}"]`);
    activeOpt.classList.add("active");
    
    if (mode === "supervisor") {
      roleToggleSlider.style.transform = "translateX(0%)";
      roleToggleSlider.style.background = "linear-gradient(135deg, var(--accent-primary), #4f46e5)";
      roleToggleSlider.style.boxShadow = "0 4px 12px var(--accent-primary-glow)";
      document.documentElement.style.setProperty("--accent-primary", "#6366f1");
      
      logTelemetry("MODE_SWITCH", "User swiped role to: [SUPERVISOR]. Direct academic data synchronization enabled.");
    } else {
      // Co-aprendiz mode
      roleToggleSlider.style.transform = "translateX(100%)";
      roleToggleSlider.style.background = "linear-gradient(135deg, var(--accent-colearn), #7c3aed)";
      roleToggleSlider.style.boxShadow = "0 4px 12px var(--accent-colearn-glow)";
      document.documentElement.style.setProperty("--accent-primary", "#8b5cf6");
      
      logTelemetry("MODE_SWITCH", "User swiped role to: [CO-APRENDIZ]. Activation of at-home reinforcement panel.");
    }
    
    // Toggle dashboard sections
    document.querySelectorAll(".mode-dependent-section").forEach(sec => {
      if (sec.dataset.mode === mode) {
        sec.classList.add("active");
      } else {
        sec.classList.remove("active");
      }
    });
    
    // Rerender performance graph under new colors
    loadStudentData();
  }
  
  // Load Active Student Stats, evaluate Rules Engine via Render server
  async function loadStudentData() {
    const student = mockDb.students.find(s => s.id === currentStudentId);
    
    // Update top info
    document.getElementById("student-name-header").textContent = student.name;
    document.getElementById("student-desc-header").textContent = student.grade;
    
    // Fetch grades list (direct from Supabase Cloud if configured, else fallback)
    const grades = await window.supabaseApi.getGrades(currentStudentId);
    currentGrades = grades;
    
    // 2. RULES ENGINE EVALUATION (Priority 2: Render Server connection)
    logTelemetry("RULES_ENGINE", `Sending grades to Express Rules-Engine running at ${BACKEND_API_BASE}...`);
    let alertData = null;
    
    try {
      const response = await fetch(`${BACKEND_API_BASE}/api/rules-engine/evaluate`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          studentId: currentStudentId,
          studentName: student.name,
          grades: grades
        })
      });
      
      if (response.ok) {
        const result = await response.json();
        logTelemetry("RENDER_SERVER", `Rules-Engine returned status. Alert match: ${result.alertTriggered}`);
        if (result.alertTriggered) {
          alertData = result.alert;
        }
      }
    } catch (err) {
      logTelemetry("RULES_ENGINE", "Render Express Server offline. Running evaluation engine locally (fallback mode).");
      
      // Fallback local rule: Score < 70 triggers Alert
      const lowGrade = grades.find(g => g.score < 70);
      if (lowGrade) {
        alertData = {
          type: "warning",
          message: `Alerta Académica: Sophia obtuvo una baja calificación en ${lowGrade.subject} (${lowGrade.score}/100) en ${lowGrade.category}.`,
          action: "schedule_meeting",
          teacherId: "tch-1"
        };
      }
    }
    
    // Render the Warning Alerts
    renderAlerts(alertData);
    
    // Calculate and update GPA dynamically based on active grades
    if (grades.length > 0) {
      const sum = grades.reduce((acc, g) => acc + Number(g.score), 0);
      const avg = (sum / grades.length).toFixed(1);
      student.gpa = avg;
    }
    
    document.getElementById("kpi-gpa").textContent = `${student.gpa}%`;
    document.getElementById("kpi-attendance").textContent = `${student.attendance}%`;
    
    // Calculate pending tasks from Supabase (Priority 1) or mock
    const tasks = await window.supabaseApi.getTasks(currentStudentId);
    const pendingTasksCount = tasks.filter(t => t.status === "pending").length;
    document.getElementById("kpi-tasks").textContent = pendingTasksCount;
    
    // Load student specific meetings counter
    const meetingsCount = mockDb.calendarEvents.filter(e => e.type === "meeting").length;
    document.getElementById("kpi-meetings").textContent = meetingsCount;
    
    // Render dynamic SVG chart
    renderPerformanceChart(grades);
  }
  
  // Render Alerts Notification Banner based on rules evaluation
  function renderAlerts(alertData) {
    alertBannerContainer.innerHTML = "";
    
    if (alertData) {
      const banner = document.createElement("div");
      banner.className = "alert-banner";
      
      banner.innerHTML = `
        <div class="alert-banner-content">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
          <div class="alert-banner-text">
            <h4>Alerta de Rendimiento</h4>
            <p>${alertData.message}</p>
          </div>
        </div>
        <button class="alert-banner-btn" id="alert-action-btn">Agendar Cita</button>
      `;
      
      alertBannerContainer.appendChild(banner);
      
      document.getElementById("alert-action-btn").addEventListener("click", () => {
        logTelemetry("ACTION", `User clicked warning banner. Redirecting to schedule a meeting.`);
        triggerMeetingPreselect(alertData.teacherId || "tch-1");
      });
      
      document.querySelector(".icon-badge-btn .badge").textContent = "1";
      document.querySelector(".icon-badge-btn .badge").style.display = "flex";
    } else {
      document.querySelector(".icon-badge-btn .badge").style.display = "none";
    }
  }
  
  // Transition View to Meeting Scheduler with specific Teacher Selected
  function triggerMeetingPreselect(teacherId) {
    selectedTeacherId = teacherId;
    switchTab("social");
    
    const select = document.getElementById("meeting-teacher");
    select.value = teacherId;
    
    selectTeacherChat(teacherId);
    document.getElementById("meeting-date").focus();
    logTelemetry("UI_FLOW", `Automated transition: pre-selected teacher [${teacherId}] in meeting scheduler.`);
  }
  
  // Render Interactive Performance Chart (SVG Based)
  function renderPerformanceChart(grades) {
    const container = document.getElementById("performance-chart-container");
    container.innerHTML = "";
    
    if (!grades || grades.length === 0) return;
    
    // Sort chronologically (date ascending)
    const sortedGrades = [...grades].sort((a,b) => new Date(a.date) - new Date(b.date));
    
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("class", "chart-svg");
    
    const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs");
    const gradient = document.createElementNS("http://www.w3.org/2000/svg", "linearGradient");
    gradient.setAttribute("id", "chart-gradient");
    gradient.setAttribute("x1", "0");
    gradient.setAttribute("y1", "0");
    gradient.setAttribute("x2", "0");
    gradient.setAttribute("y2", "1");
    
    const stop1 = document.createElementNS("http://www.w3.org/2000/svg", "stop");
    stop1.setAttribute("offset", "0%");
    stop1.setAttribute("stop-color", currentMode === "supervisor" ? "var(--accent-primary)" : "var(--accent-colearn)");
    stop1.setAttribute("stop-opacity", "0.25");
    
    const stop2 = document.createElementNS("http://www.w3.org/2000/svg", "stop");
    stop2.setAttribute("offset", "100%");
    stop2.setAttribute("stop-color", currentMode === "supervisor" ? "var(--accent-primary)" : "var(--accent-colearn)");
    stop2.setAttribute("stop-opacity", "0.0");
    
    gradient.appendChild(stop1);
    gradient.appendChild(stop2);
    defs.appendChild(gradient);
    svg.appendChild(defs);
    
    const paddingLeft = 40;
    const paddingRight = 20;
    const paddingTop = 20;
    const paddingBottom = 40;
    
    const width = container.clientWidth || 550;
    const height = 230;
    
    // Draw Y-axis markers
    for (let i = 0; i <= 5; i++) {
      const scoreValue = i * 20;
      const y = height - paddingBottom - (scoreValue / 100) * (height - paddingTop - paddingBottom);
      
      const grid = document.createElementNS("http://www.w3.org/2000/svg", "line");
      grid.setAttribute("class", "chart-grid-line");
      grid.setAttribute("x1", paddingLeft);
      grid.setAttribute("y1", y);
      grid.setAttribute("x2", width - paddingRight);
      grid.setAttribute("y2", y);
      svg.appendChild(grid);
      
      const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
      text.setAttribute("class", "chart-label");
      text.setAttribute("x", paddingLeft - 10);
      text.setAttribute("y", y + 4);
      text.setAttribute("text-anchor", "end");
      text.textContent = scoreValue;
      svg.appendChild(text);
    }
    
    // Calculate points
    const points = [];
    const count = sortedGrades.length;
    
    sortedGrades.forEach((g, idx) => {
      const x = paddingLeft + (idx / (count - 1 || 1)) * (width - paddingLeft - paddingRight);
      const y = height - paddingBottom - (g.score / 100) * (height - paddingTop - paddingBottom);
      points.push({ x, y, grade: g });
    });
    
    // Draw Area below the line
    if (points.length > 1) {
      let areaPathD = `M ${points[0].x} ${height - paddingBottom} `;
      points.forEach(p => {
        areaPathD += `L ${p.x} ${p.y} `;
      });
      areaPathD += `L ${points[points.length - 1].x} ${height - paddingBottom} Z`;
      
      const area = document.createElementNS("http://www.w3.org/2000/svg", "path");
      area.setAttribute("class", "chart-area");
      area.setAttribute("d", areaPathD);
      svg.appendChild(area);
    }
    
    // Draw Connection Line
    if (points.length > 1) {
      let linePathD = `M ${points[0].x} ${points[0].y} `;
      for (let i = 1; i < points.length; i++) {
        linePathD += `L ${points[i].x} ${points[i].y} `;
      }
      
      const line = document.createElementNS("http://www.w3.org/2000/svg", "path");
      line.setAttribute("class", "chart-line");
      line.setAttribute("d", linePathD);
      if (currentMode === "colearn") {
        line.style.stroke = "var(--accent-colearn)";
        line.style.filter = "drop-shadow(0px 4px 10px var(--accent-colearn-glow))";
      }
      svg.appendChild(line);
    }
    
    const tooltip = document.createElement("div");
    tooltip.setAttribute("class", "chart-tooltip");
    container.appendChild(tooltip);
    
    // Draw dots and interactive trigger
    points.forEach(p => {
      const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle");
      circle.setAttribute("class", "chart-point");
      circle.setAttribute("cx", p.x);
      circle.setAttribute("cy", p.y);
      circle.setAttribute("r", "5");
      if (currentMode === "colearn") {
        circle.style.stroke = "var(--accent-colearn)";
      }
      
      circle.addEventListener("mouseenter", () => {
        tooltip.innerHTML = `<strong>${p.grade.subject}</strong><br>${p.grade.category}: ${p.grade.score}/100<br><span style="font-size:0.65rem;color:var(--text-secondary);">${p.grade.date}</span>`;
        tooltip.style.opacity = "1";
        tooltip.style.left = `${p.x - 50}px`;
        tooltip.style.top = `${p.y - 65}px`;
      });
      
      circle.addEventListener("mouseleave", () => {
        tooltip.style.opacity = "0";
      });
      
      svg.appendChild(circle);
      
      const dateText = document.createElementNS("http://www.w3.org/2000/svg", "text");
      dateText.setAttribute("class", "chart-label");
      dateText.setAttribute("x", p.x);
      dateText.setAttribute("y", height - 15);
      dateText.setAttribute("text-anchor", "middle");
      
      const parts = p.grade.date.split("-");
      dateText.textContent = `${parts[1]}/${parts[2]}`;
      svg.appendChild(dateText);
      
      const helperLine = document.createElementNS("http://www.w3.org/2000/svg", "line");
      helperLine.setAttribute("class", "chart-grid-line");
      helperLine.setAttribute("x1", p.x);
      helperLine.setAttribute("y1", p.y);
      helperLine.setAttribute("x2", p.x);
      helperLine.setAttribute("y2", height - paddingBottom);
      svg.appendChild(helperLine);
    });
    
    const axisY = document.createElementNS("http://www.w3.org/2000/svg", "line");
    axisY.setAttribute("class", "chart-axis-line");
    axisY.setAttribute("x1", paddingLeft);
    axisY.setAttribute("y1", paddingTop);
    axisY.setAttribute("x2", paddingLeft);
    axisY.setAttribute("y2", height - paddingBottom);
    svg.appendChild(axisY);
    
    const axisX = document.createElementNS("http://www.w3.org/2000/svg", "line");
    axisX.setAttribute("class", "chart-axis-line");
    axisX.setAttribute("x1", paddingLeft);
    axisX.setAttribute("y1", height - paddingBottom);
    axisX.setAttribute("x2", width - paddingRight);
    axisX.setAttribute("y2", height - paddingBottom);
    svg.appendChild(axisX);
    
    container.appendChild(svg);
    renderGradesList(sortedGrades);
  }
  
  // Render Grades Detailed List (Supervisor Dashboard)
  function renderGradesList(grades) {
    const list = document.getElementById("grades-list-container");
    list.innerHTML = "";
    
    const reversed = [...grades].reverse();
    
    reversed.forEach(g => {
      const row = document.createElement("div");
      row.className = "grade-row";
      
      let scoreClass = "";
      if (g.score >= 85) scoreClass = "success-score";
      else if (g.score >= 70) scoreClass = "warning-score";
      else scoreClass = "danger-score";
      
      row.innerHTML = `
        <div class="grade-info">
          <span class="grade-subject">${g.subject} <span style="font-size:0.75rem;font-weight:normal;color:var(--text-muted);">(${g.category})</span></span>
          <span class="grade-meta">${g.teacher || 'Prof. Carter'} • ${g.date}</span>
          <span style="font-size:0.75rem;color:var(--text-secondary);margin-top:2px;">"${g.comments || ''}"</span>
        </div>
        <div class="grade-badge-container">
          <div class="grade-score-pill ${scoreClass}">${Math.round(g.score)}</div>
        </div>
      `;
      list.appendChild(row);
    });
  }
  
  // Render Calendar view
  function renderCalendar() {
    const calendarContainer = document.getElementById("calendar-grid-container");
    calendarContainer.innerHTML = "";
    
    const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    weekdays.forEach(day => {
      const cell = document.createElement("div");
      cell.className = "calendar-header-day";
      cell.textContent = day;
      calendarContainer.appendChild(cell);
    });
    
    const prevMonthDays = 5;
    const totalDays = 31;
    let dayCounter = 1;
    
    for (let i = 0; i < 35; i++) {
      const cell = document.createElement("div");
      cell.className = "calendar-day-cell";
      
      const dayNum = document.createElement("span");
      dayNum.className = "day-number";
      
      if (i >= prevMonthDays && dayCounter <= totalDays) {
        dayNum.textContent = dayCounter;
        dayNum.classList.add("current-month");
        
        if (dayCounter === 21) {
          dayNum.classList.add("today-highlight");
        }
        
        const dayStr = dayCounter < 10 ? `0${dayCounter}` : `${dayCounter}`;
        const dateKey = `2026-05-${dayStr}`;
        
        const dayEvents = mockDb.calendarEvents.filter(ev => ev.date === dateKey);
        dayEvents.forEach(ev => {
          const evBadge = document.createElement("div");
          evBadge.className = `calendar-cell-event type-${ev.type}`;
          evBadge.textContent = ev.title;
          evBadge.title = `${ev.title} (${ev.time})\n${ev.note}`;
          
          evBadge.addEventListener("click", () => {
            logTelemetry("UI_FLOW", `Clicked calendar event: "${ev.title}"`);
            alert(`Evento: ${ev.title}\nHora: ${ev.time}\nDetalles: ${ev.note}`);
          });
          
          cell.appendChild(evBadge);
        });
        
        dayCounter++;
      } else {
        dayNum.textContent = "";
      }
      
      cell.insertBefore(dayNum, cell.firstChild);
      calendarContainer.appendChild(cell);
    }
    
    // Upcoming side list
    const sidebarContainer = document.getElementById("calendar-upcoming-list");
    sidebarContainer.innerHTML = "";
    
    const upcoming = [...mockDb.calendarEvents].sort((a,b) => new Date(a.date) - new Date(b.date));
    upcoming.forEach(ev => {
      const card = document.createElement("div");
      let borderClass = "";
      if (ev.type === "exam") borderClass = "event-danger";
      else if (ev.type === "meeting") borderClass = "event-warning";
      else borderClass = "event-colearn";
      
      card.className = `sidebar-event-card ${borderClass}`;
      card.innerHTML = `
        <div class="sidebar-event-title">${ev.title}</div>
        <div class="sidebar-event-time">${ev.date} @ ${ev.time}</div>
        <div class="sidebar-event-note">${ev.note}</div>
      `;
      sidebarContainer.appendChild(card);
    });
  }
  
  // Render Tasks & Resources View
  async function renderTasks() {
    const pendingList = document.getElementById("tasks-pending-container");
    const completedList = document.getElementById("tasks-completed-container");
    
    pendingList.innerHTML = "";
    completedList.innerHTML = "";
    
    // Pull list from Supabase/Mock
    const tasks = await window.supabaseApi.getTasks(currentStudentId);
    
    tasks.forEach(t => {
      const card = document.createElement("div");
      card.className = "task-card";
      
      let resourcesHtml = "";
      if (t.resources && t.resources.length > 0) {
        resourcesHtml = `
          <div class="task-resources-list">
            <span style="font-size:0.7rem;color:var(--text-muted);font-weight:600;text-transform:uppercase;">Recursos Asíncronos</span>
            ${t.resources.map(r => `
              <a href="${r.url}" class="resource-link-item">
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                ${r.name} ${r.duration ? `(${r.duration})` : ""} ${r.size ? `[${r.size}]` : ""}
              </a>
            `).join("")}
          </div>
        `;
      }
      
      card.innerHTML = `
        <div class="task-header">
          <div>
            <div class="task-title">${t.title}</div>
            <span style="font-size:0.7rem;color:var(--text-secondary);">Dificultad: <strong>${t.difficulty}</strong></span>
          </div>
          <span class="task-subject-tag">${t.subject}</span>
        </div>
        <div class="task-details">
          <span>Fecha de entrega: <strong>${t.dueDate}</strong></span>
          <span>Status: <strong style="color:${t.status === "completed" ? "var(--success)" : "var(--warning)"}">${t.status.toUpperCase()}</strong></span>
        </div>
        ${resourcesHtml}
      `;
      
      if (t.status === "completed") {
        completedList.appendChild(card);
      } else {
        pendingList.appendChild(card);
      }
    });
    renderDiscussionsThread();
  }
  
  // Render Co-Learn Homework Discussions
  function renderDiscussionsThread() {
    const list = document.getElementById("discussion-board-list");
    list.innerHTML = "";
    
    const studentTasks = mockDb.tasks[currentStudentId] || [];
    const taskWithDiscussion = studentTasks.find(t => t.coLearnDiscussions && t.coLearnDiscussions.length > 0) || studentTasks[0];
    
    if (!taskWithDiscussion) {
      list.innerHTML = `<span style="font-size:0.8rem;color:var(--text-muted);">Ningún foro de discusión activo.</span>`;
      return;
    }
    
    document.getElementById("discussion-title-label").textContent = taskWithDiscussion.title;
    
    const posts = taskWithDiscussion.coLearnDiscussions || [];
    posts.forEach(p => {
      const card = document.createElement("div");
      let typeClass = "parent-post";
      if (p.author === "Teacher") typeClass = "teacher-post";
      else if (p.author.includes("Sophia") || p.author.includes("Leo")) typeClass = "student-post";
      
      card.className = `discussion-post ${typeClass}`;
      card.innerHTML = `
        <div class="post-meta">
          <span>${p.author}</span>
          <span class="post-time">Reciente</span>
        </div>
        <div>${p.text}</div>
      `;
      list.appendChild(card);
    });
  }
  
  // Submit discussion board post
  async function submitDiscussionPost() {
    const input = document.getElementById("discussion-input");
    const text = input.value.trim();
    if (!text) return;
    
    const studentTasks = mockDb.tasks[currentStudentId] || [];
    const activeTask = studentTasks.find(t => t.coLearnDiscussions) || studentTasks[0];
    
    if (activeTask) {
      if (!activeTask.coLearnDiscussions) {
        activeTask.coLearnDiscussions = [];
      }
      
      activeTask.coLearnDiscussions.push({
        author: "Tú (Padre)",
        text: text
      });
      
      // Sync discussion to Supabase (Priority 1) if active
      await window.supabaseApi.sendChatMessage({
        sender_id: "mock-parent-id",
        receiver_id: "teacher-class-channel",
        text: `Discussion note added to task [${activeTask.title}]: ${text}`
      });
      
      logTelemetry("LAKEHOUSE", `Discussion logged for task ID: ${activeTask.id}. RLS checked.`);
      input.value = "";
      renderDiscussionsThread();
    }
  }
  
  // Render Teacher list in Social Panel
  function renderTeachers() {
    const sidebar = document.getElementById("chat-teachers-container");
    sidebar.innerHTML = "";
    
    mockDb.teachers.forEach(tch => {
      const row = document.createElement("div");
      row.className = `teacher-chat-row ${tch.id === selectedTeacherId ? "active" : ""}`;
      row.dataset.teacherId = tch.id;
      
      row.innerHTML = `
        <div class="student-avatar" style="background:${tch.color};">${tch.name.split(" ").pop()[0]}</div>
        <div>
          <div style="font-size:0.85rem;font-weight:600;">${tch.name}</div>
          <div style="font-size:0.7rem;color:var(--text-secondary);">${tch.subject}</div>
        </div>
      `;
      
      row.addEventListener("click", () => {
        selectTeacherChat(tch.id);
      });
      
      sidebar.appendChild(row);
    });
    
    const select = document.getElementById("meeting-teacher");
    select.innerHTML = "";
    mockDb.teachers.forEach(tch => {
      const opt = document.createElement("option");
      opt.value = tch.id;
      opt.textContent = `${tch.name} (${tch.subject})`;
      select.appendChild(opt);
    });
    
    renderChatMessages();
  }
  
  // Select active teacher chat
  function selectTeacherChat(teacherId) {
    selectedTeacherId = teacherId;
    
    const rows = document.querySelectorAll(".teacher-chat-row");
    rows.forEach(r => {
      if (r.dataset.teacherId === teacherId) {
        r.classList.add("active");
      } else {
        r.classList.remove("active");
      }
    });
    
    logTelemetry("CHAT", `Loaded conversation logs with teacher ID: ${teacherId}`);
    renderChatMessages();
  }
  
  // Render chat messages
  function renderChatMessages() {
    const container = document.getElementById("chat-messages-box");
    container.innerHTML = "";
    
    const teacher = mockDb.teachers.find(t => t.id === selectedTeacherId);
    document.getElementById("chat-with-label").textContent = `Chat con ${teacher.name}`;
    
    const messages = mockDb.chats[selectedTeacherId] || [];
    
    if (messages.length === 0) {
      container.innerHTML = `<span style="font-size:0.8rem;color:var(--text-muted);text-align:center;margin-top:20px;">No hay historial de chat. Escribe abajo para enviar un mensaje.</span>`;
      return;
    }
    
    messages.forEach(m => {
      const bubble = document.createElement("div");
      const isTeacher = m.sender === "teacher";
      
      bubble.className = `chat-bubble ${isTeacher ? "teacher-message" : "parent-message"}`;
      bubble.innerHTML = `
        <div>${m.text}</div>
        <div class="chat-bubble-time">${m.timestamp}</div>
      `;
      container.appendChild(bubble);
    });
    
    container.scrollTop = container.scrollHeight;
  }
  
  // Send message in chat
  async function sendChatMessage() {
    const input = document.getElementById("chat-input");
    const text = input.value.trim();
    if (!text) return;
    
    if (!mockDb.chats[selectedTeacherId]) {
      mockDb.chats[selectedTeacherId] = [];
    }
    
    const timestampStr = new Date().toISOString().replace('T', ' ').substring(0, 16);
    const messagePayload = {
      sender: "parent",
      text: text,
      timestamp: timestampStr
    };
    
    mockDb.chats[selectedTeacherId].push(messagePayload);
    
    // Sync chat payload to Supabase Database (Priority 1)
    await window.supabaseApi.sendChatMessage({
      sender_id: "parent-user-uid",
      receiver_id: selectedTeacherId,
      text: text
    });
    
    input.value = "";
    renderChatMessages();
    logTelemetry("CHAT_SEND", `Logged outgoing message to secure gateway. Recipient: ${selectedTeacherId}`);
    
    // Simulate auto response from teacher
    setTimeout(() => {
      const replies = [
        "Muchas gracias por el mensaje. Mañana por la mañana lo reviso en clase con ella y te comento.",
        "Perfecto, me parece muy bien. Lo conversamos a detalle en nuestra cita programada.",
        "Agradezco mucho tu apoyo. Sigamos monitoreando el avance de las fichas de Matemáticas en Co-Aprendiz.",
        "Hola. Sí, el trabajo de Leo se ve muy prolijo. Sigan repasando juntos en casa."
      ];
      
      const randomReply = replies[Math.floor(Math.random() * replies.length)];
      const responseTime = new Date().toISOString().replace('T', ' ').substring(0, 16);
      
      mockDb.chats[selectedTeacherId].push({
        sender: "teacher",
        text: randomReply,
        timestamp: responseTime
      });
      
      renderChatMessages();
      logTelemetry("CHAT_RECV", "Received encrypted message payload response from Teacher.");
    }, 1500);
  }
  
  // Book virtual parent-teacher meeting
  async function bookMeeting(e) {
    e.preventDefault();
    
    const teacherSelect = document.getElementById("meeting-teacher");
    const dateInput = document.getElementById("meeting-date");
    const timeInput = document.getElementById("meeting-time");
    
    const selectedTch = mockDb.teachers.find(t => t.id === teacherSelect.value);
    
    const newMeeting = {
      title: `Cita Virtual: ${selectedTch.subject}`,
      type: "meeting",
      date: dateInput.value,
      time: timeInput.value,
      note: `Aula Virtual: Prof. ${selectedTch.name.split(" ").pop()}`
    };
    
    // Write new meeting to Supabase Calendar table (Priority 1)
    await window.supabaseApi.addCalendarEvent({
      parent_id: "mock-parent-id",
      title: newMeeting.title,
      type: "meeting",
      event_date: newMeeting.date,
      event_time: newMeeting.time,
      note: newMeeting.note
    });
    
    // Append locally for visual rendering immediately
    mockDb.calendarEvents.push(newMeeting);
    
    // Resolve math warnings if we scheduled math meeting
    if (selectedTch.id === "tch-1") {
      mockDb.alerts.forEach(al => {
        if (al.studentId === currentStudentId && al.teacherId === "tch-1") {
          al.resolved = true;
        }
      });
    }
    
    logTelemetry("LAKEHOUSE", `Committed new meeting slot on ${dateInput.value} at ${timeInput.value} with ${selectedTch.name} to unified calendar.`);
    
    dateInput.value = "";
    
    renderCalendar();
    loadStudentData(); // Updates alerts and stats
    
    alert(`Cita agendada exitosamente con ${selectedTch.name}.\nFecha: ${newMeeting.date} a las ${newMeeting.time}.`);
  }
  
  // Canvas Whiteboard Simulator Logic
  function initWhiteboard() {
    const canvas = document.getElementById("whiteboard-drawing-board");
    if (!canvas) return;
    
    const ctx = canvas.getContext("2d");
    
    canvas.width = canvas.parentElement.clientWidth || 300;
    canvas.height = 180;
    
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    ctx.lineWidth = 3;
    
    canvas.addEventListener("mousedown", (e) => {
      isDrawing = true;
      [lastX, lastY] = [e.offsetX, e.offsetY];
    });
    
    canvas.addEventListener("mousemove", (e) => {
      if (!isDrawing) return;
      ctx.beginPath();
      ctx.moveTo(lastX, lastY);
      ctx.lineTo(e.offsetX, e.offsetY);
      ctx.strokeStyle = drawColor;
      ctx.stroke();
      [lastX, lastY] = [e.offsetX, e.offsetY];
    });
    
    canvas.addEventListener("mouseup", () => isDrawing = false);
    canvas.addEventListener("mouseout", () => isDrawing = false);
    
    document.querySelectorAll(".whiteboard-btn[data-color]").forEach(btn => {
      btn.addEventListener("click", () => {
        document.querySelectorAll(".whiteboard-btn[data-color]").forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        drawColor = btn.dataset.color;
      });
    });
    
    document.getElementById("clear-board-btn").addEventListener("click", () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      logTelemetry("ACTION", "Cleared Offline Whiteboard drawing board.");
    });
  }
  
  // Submit NPS Feedback
  function submitNPS(score) {
    logTelemetry("TELEMETRY", `NPS Survey submitted. Score: ${score}/10. User satisfaction logged.`);
    alert(`¡Gracias por tu retroalimentación! Calificación registrada: ${score}/10.`);
    
    setTimeout(() => {
      document.querySelectorAll(".nps-btn").forEach(btn => btn.classList.remove("selected"));
    }, 1000);
  }
  
  // Render Courses in Store
  function renderStore() {
    const store = document.getElementById("store-catalog-grid");
    store.innerHTML = "";
    
    mockDb.storeCourses.forEach(c => {
      const card = document.createElement("div");
      card.className = "store-card";
      
      card.innerHTML = `
        <div class="store-card-banner ${c.image}">
          ${c.subject}
        </div>
        <div class="store-card-content">
          <div>
            <div class="store-card-title">${c.title}</div>
            <div class="store-card-meta">Instructor: ${c.tutor} • ⭐ ${c.rating}</div>
          </div>
          <div class="store-card-footer">
            <div class="store-card-price">$${c.price}</div>
            <button class="buy-btn" data-course-id="${c.id}">Adquirir</button>
          </div>
        </div>
      `;
      
      card.querySelector(".buy-btn").addEventListener("click", () => {
        openCheckout(c);
      });
      
      store.appendChild(card);
    });
  }
  
  // Open checkout modal simulation
  let courseToBuy = null;
  function openCheckout(course) {
    courseToBuy = course;
    document.getElementById("checkout-course-title").textContent = course.title;
    document.getElementById("checkout-course-price").textContent = `$${course.price}`;
    document.getElementById("checkout-modal").style.display = "flex";
    
    logTelemetry("TRANSACTION", `Opened Stripe Tokenized checkout screen for course: [${course.title}]`);
  }
  
  function closeCheckout() {
    document.getElementById("checkout-modal").style.display = "none";
    courseToBuy = null;
  }
  
  // Process Mock PCI DSS Tokenized Payment (Priority 2 API simulation)
  async function processMockPayment(e) {
    e.preventDefault();
    
    const cardNum = document.getElementById("card-number").value.trim();
    if (cardNum.length < 16) {
      alert("Por favor introduce una tarjeta válida (16 dígitos).");
      return;
    }
    
    logTelemetry("PCI_DSS", "PCI DSS Compliance check: Direct credit card parameters masked.");
    
    // Generate Stripe Token Mock on client
    const mockToken = `tok_stripe_` + Math.floor(Math.random() * 900000 + 100000);
    logTelemetry("STRIPE_GATEWAY", `Client tokenized payload created successfully: ${mockToken}`);
    
    // Send charge payload to Render Backend API (Priority 2)
    try {
      const response = await fetch(`${BACKEND_API_BASE}/api/payment/charge`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          cardToken: mockToken,
          amount: courseToBuy.price,
          courseTitle: courseToBuy.title
        })
      });
      
      if (response.ok) {
        const receipt = await response.json();
        logTelemetry("RENDER_SERVER", `Stripe token approved. Charged $${receipt.amount} successfully. TxID: ${receipt.transactionId}`);
        alert(`¡Compra procesada con éxito!\nID de transacción: ${receipt.transactionId}\nEl curso "${courseToBuy.title}" ha sido desbloqueado.`);
      } else {
        throw new Error("Server rejected card authorization.");
      }
    } catch (err) {
      logTelemetry("TRANSACTION", `Render API server offline. processing payment locally with fallback token [${mockToken}]`);
      logTelemetry("TRANSACTION", `Successfully charged $${courseToBuy.price} to card. Course [${courseToBuy.title}] unlocked!`);
      alert(`Compra simulada con éxito.\nEl curso "${courseToBuy.title}" ha sido añadido a tu biblioteca familiar.`);
    }
    
    closeCheckout();
  }
  
  // Log telemetry events directly in the drawer console
  function logTelemetry(module, message) {
    const timestamp = new Date().toLocaleTimeString();
    const line = document.createElement("div");
    line.className = "telemetry-line";
    
    let typeClass = "";
    if (module === "RULES_ENGINE" || module === "PCI_DSS" || module === "FIREBASE_ERROR") typeClass = "event-warn";
    else if (module === "TRANSACTION" || module === "STRIPE_GATEWAY" || module === "RENDER_SERVER") typeClass = "event-info";
    else if (module === "LAKEHOUSE" || module === "SUPABASE") typeClass = "event-info";
    
    line.innerHTML = `[${timestamp}] <span class="${typeClass}" style="font-weight:600;">[${module}]</span>: ${message}`;
    
    telemetryBody.appendChild(line);
    telemetryBody.scrollTop = telemetryBody.scrollHeight;
  }
  
  // Boot
  init();
});
