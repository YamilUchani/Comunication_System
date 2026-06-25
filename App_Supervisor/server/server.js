// Express Backend Server for Render + Local Dev - De Supervisor a Co-Aprendiz
const express = require("express");
const cors = require("cors");
const path = require("path");
const { createClient } = require("@supabase/supabase-js");
require("dotenv").config();

const app = express();

// ── CORS & JSON parsing ──
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",").map(origin => origin.trim()).filter(Boolean)
  : [
      "http://localhost:8000",
      "http://127.0.0.1:8000",
      "https://educoparent-callback.web.app",
      "https://app-supervisor-backend.onrender.com"
    ];

app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    return callback(new Error("Origin not allowed by CORS"), false);
  }
}));
app.use(express.json());

// ── Serve App_Supervisor static files ──
// Path to App_Supervisor root (parent of the /server directory)
const appRoot = path.join(__dirname, "..");
app.use(express.static(appRoot));

const PORT = process.env.PORT || 8000;

// Initialize Supabase Client if envs are available
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
let supabase = null;

if (supabaseUrl && supabaseAnonKey) {
  supabase = createClient(supabaseUrl, supabaseAnonKey);
  console.log("[SYSTEM] Connected to Supabase Cloud Instance.");
} else {
  console.warn("[WARNING] Supabase environment variables are missing. API running in Local Mock Mode.");
}

// 1. Health endpoint
app.get("/api/health", (req, res) => {
  res.json({
    status: "online",
    timestamp: new Date(),
    supabaseConnected: !!supabase,
    environment: process.env.NODE_ENV || "development",
    port: PORT,
    serving: "App_Supervisor"
  });
});

// 2. Rules Engine Endpoint: Evaluate student grades and trigger automated meeting alerts
app.post("/api/rules-engine/evaluate", async (req, res) => {
  const { studentId, studentName, grades } = req.body;
  
  console.log(`[RULES ENGINE] Evaluating performance parameters for ${studentName || studentId}...`);
  
  if (!grades || !Array.isArray(grades)) {
    return res.status(400).json({ error: "Grades array is required for evaluation." });
  }

  // Define critical rule logic: Score < 70 triggers Warning alert suggestion
  const lowGrade = grades.find(g => g.score < 70);
  
  if (lowGrade) {
    const alertMessage = `Low performance detected in ${lowGrade.subject}: ${lowGrade.score}/100 in ${lowGrade.category}.`;
    console.log(`[ALERT TRIGGERED] Rule match: Score ${lowGrade.score} < 70. Suggesting parent action.`);
    
    let dbStatus = "mocked";
    
    // If Supabase is connected, attempt to write/update database alert
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from("alerts")
          .insert([
            {
              student_id: studentId,
              type: "warning",
              message: alertMessage,
              action: "schedule_meeting",
              teacher_id: lowGrade.teacher_id || null,
              resolved: false
            }
          ]);
        
        if (error) throw error;
        dbStatus = "inserted_to_supabase";
      } catch (err) {
        console.error("[DATABASE ERROR] Failed to insert alert to Supabase:", err.message);
        dbStatus = "failed_db_fallback_local";
      }
    }
    
    return res.json({
      alertTriggered: true,
      alert: {
        type: "warning",
        message: alertMessage,
        action: "schedule_meeting",
        teacherId: lowGrade.teacher_id || "tch-1",
        comments: `Recommended action: Schedule a parent-teacher session with teacher.`
      },
      dbStatus: dbStatus
    });
  }
  
  res.json({
    alertTriggered: false,
    message: "Performance indexes stable. No alerts triggered.",
    dbStatus: "evaluated_no_match"
  });
});

// 3. Financial PCI DSS Compliant Payment Tokenization Simulation Endpoint
app.post("/api/payment/charge", (req, res) => {
  const { cardToken, amount, courseTitle, familyProfileId } = req.body;
  const numericAmount = Number(amount);
  
  console.log(`[PCI DSS PAYMENT GATEWAY] Received transaction request for $${amount}...`);
  
  if (!cardToken || !cardToken.startsWith("tok_stripe_")) {
    console.error("[PCI DSS SECURITY ALERT] Transaction rejected: Non-tokenized/sensitive card payload detected.");
    return res.status(400).json({
      error: "PCI DSS Violation: direct credit card data processing is forbidden. Please provide a gateway token."
    });
  }

  if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
    return res.status(400).json({
      error: "Invalid amount. Provide a positive numeric amount."
    });
  }
  
  // Safe payment processing (Masked log)
  console.log(`[STRIPE CHARGE API] Token authorized. Amount charged: $${numericAmount}. Course: "${courseTitle}".`);
  
  const transactionId = "tx_live_" + Math.random().toString(36).substring(2, 15);
  
  res.json({
    success: true,
    transactionId: transactionId,
    amount: numericAmount,
    status: "succeeded",
    tokenUsed: `${cardToken.slice(0, 11)}...${cardToken.slice(-4)}`,
    date: new Date().toISOString(),
    receiptUrl: `https://stripe.com/receipts/simulation/${transactionId}`
  });
});

// ── SPA fallback: serve app.html for any non-API, non-static routes ──
app.get("*", (req, res) => {
  // If the request looks like an API path, return 404
  if (req.path.startsWith("/api/")) {
    return res.status(404).json({ error: "API endpoint not found" });
  }
  // Otherwise serve app.html (SPA entry point)
  res.sendFile(path.join(appRoot, "app.html"));
});

// Start listening
app.listen(PORT, () => {
  const supabaseStatus = supabase ? "CONECTADO" : "MOCK (sin credenciales)";
  console.log(`
╔══════════════════════════════════════════════════════╗
║                                                      ║
║   EduCoParent - App_Supervisor                       ║
║   ─────────────────────────────                      ║
║   Servidor Express corriendo en:                     ║
║   http://localhost:${PORT}                           ║
║                                                      ║
║   Frontend:  http://localhost:${PORT}/app.html       ║
║   Landing:   http://localhost:${PORT}/index.html     ║
║   API Health: http://localhost:${PORT}/api/health    ║
║                                                      ║
║   Supabase: ${supabaseStatus.padEnd(38, " ")}║
║                                                      ║
╚══════════════════════════════════════════════════════╝
  `);
});
