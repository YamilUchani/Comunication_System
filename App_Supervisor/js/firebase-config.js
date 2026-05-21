// Firebase Auth & Cloud Messaging API SDK
// Priority 3: Authentication and Parent Alerts

// Set your Firebase Credentials here (refer to INSTRUCCIONES_DETALLADAS.md)
const firebaseConfig = {
  apiKey: "TU_API_KEY",
  authDomain: "TU_AUTH_DOMAIN",
  projectId: "TU_PROJECT_ID",
  storageBucket: "TU_STORAGE_BUCKET",
  messagingSenderId: "TU_MESSAGING_SENDER_ID",
  appId: "TU_APP_ID"
};

let firebaseApp = null;
let firebaseAuth = null;
let isFirebaseActive = false;

try {
  if (
    firebaseConfig.apiKey && 
    firebaseConfig.apiKey !== "TU_API_KEY"
  ) {
    // Loaded via CDN script tags (v9+ compat or bundle)
    if (typeof firebase !== 'undefined') {
      firebaseApp = firebase.initializeApp(firebaseConfig);
      firebaseAuth = firebase.auth();
      isFirebaseActive = true;
      console.log("[FIREBASE] Authenticated cloud client instantiated.");
    }
  }
} catch (error) {
  console.error("[FIREBASE ERROR] Connection initialization failed:", error);
}

// Wrapper APIs with local auth simulation
const firebaseApi = {
  isActive: () => isFirebaseActive,

  // Simulate or execute email password signin
  signIn: async (email, password) => {
    if (isFirebaseActive && firebaseAuth) {
      try {
        const userCredential = await firebaseAuth.signInWithEmailAndPassword(email, password);
        return { success: true, user: userCredential.user };
      } catch (err) {
        return { success: false, error: err.message };
      }
    } else {
      // Mock Sign In
      console.log(`[FIREBASE MOCK] Signing in user: ${email}`);
      if (email && password) {
        return { 
          success: true, 
          user: { 
            email: email, 
            displayName: "Yamil Martinez (Familiar)", 
            uid: "mock-user-123" 
          } 
        };
      }
      return { success: false, error: "Please enter email and password." };
    }
  },

  // Log out
  signOut: async () => {
    if (isFirebaseActive && firebaseAuth) {
      await firebaseAuth.signOut();
    }
    console.log("[FIREBASE] User session terminated.");
    return { success: true };
  },

  // Setup Web Push Notification permissions (FCM)
  requestNotificationPermission: async () => {
    if (isFirebaseActive) {
      try {
        const messaging = firebase.messaging();
        const token = await messaging.getToken({ vapidKey: 'YOUR_VAPID_KEY_HERE' });
        console.log(`[FIREBASE FCM] Notification token acquired: ${token}`);
        return token;
      } catch (err) {
        console.warn("[FIREBASE FCM] Notifications registration failed or rejected:", err.message);
        return null;
      }
    } else {
      // Mock permission request
      console.log("[FIREBASE MOCK] Requesting notification permission...");
      const permission = await Notification.requestPermission();
      console.log(`[FIREBASE MOCK] Browser permission response: ${permission}`);
      return permission === "granted" ? "mock_token_12345" : null;
    }
  }
};

// Export to global window object
window.firebaseApi = firebaseApi;
