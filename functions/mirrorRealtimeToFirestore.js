const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize admin if not already initialized
try {
  admin.initializeApp();
} catch (e) {
  // already initialized
}

const db = admin.database();
const firestore = admin.firestore();

// DISABLED: Function untuk mirror warning ke Firestore sudah tidak digunakan
// karena aplikasi sekarang hanya membaca langsung dari Realtime Database
// dan tidak memerlukan data tersimpan di Firestore notifications collection
