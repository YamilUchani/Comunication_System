// Express Backend Server for Render - De Supervisor a Co-Aprendiz
const express = require("express");
const cors = require("cors");
const { createClient } = require("@supabase/supabase-js");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 10000;

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
    environment: process.env.NODE_ENV || "development"
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
  
  console.log(`[PCI DSS PAYMENT GATEWAY] Received transaction request for $${amount}...`);
  
  if (!cardToken || !cardToken.startsWith("tok_stripe_")) {
    console.error("[PCI DSS SECURITY ALERT] Transaction rejected: Non-tokenized/sensitive card payload detected.");
    return res.status(400).json({
      error: "PCI DSS Violation: direct credit card data processing is forbidden. Please provide a gateway token."
    });
  }
  
  // Safe payment processing (Masked log)
  console.log(`[STRIPE CHARGE API] Token authorized. Amount charged: $${amount}. Course: "${courseTitle}".`);
  
  const transactionId = "tx_live_" + Math.random().toString(36).substring(2, 15);
  
  res.json({
    success: true,
    transactionId: transactionId,
    amount: amount,
    status: "succeeded",
    tokenUsed: cardToken,
    date: new Date().toISOString(),
    receiptUrl: `https://stripe.com/receipts/simulation/${transactionId}`
  });
});

// Start listening
app.listen(PORT, () => {
  console.log(`[SYSTEM] Express server running on port ${PORT}`);
});
