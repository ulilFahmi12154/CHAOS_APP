/**
 * Sinkronisasi otomatis varietas Firestore → Realtime Database
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Sinkronisasi dokumen varietas_config ke Realtime Database
exports.syncVarietasToRealtime = functions.firestore
  .document("varietas_config/{varietasId}")
  .onWrite(async (change, context) => {
    const varietasId = context.params.varietasId;
    const afterData = change.after.exists ? change.after.data() : null;
    const ref = admin.database().ref(`smartfarm/varietas_config/${varietasId}`);

    if (afterData) {
      // Dokumen dibuat/diupdate
      await ref.set(afterData);
      console.log(
        `✅ Data varietas ${varietasId} disalin ke Realtime Database`
      );
    } else {
      // Dokumen dihapus
      await ref.remove();
      console.log(
        `🗑️ Data varietas ${varietasId} dihapus dari Realtime Database`
      );
    }
  });

// Sinkronisasi varietas aktif ke Realtime Database
exports.syncActiveVarietas = functions.firestore
  .document("active_varietas/current")
  .onWrite(async (change, context) => {
    const activeData = change.after.exists ? change.after.data() : null;
    const ref = admin.database().ref("smartfarm/active_varietas");

    if (activeData && activeData.varietasId) {
      await ref.set(activeData.varietasId);
      console.log(
        `🌱 Varietas aktif diupdate menjadi ${activeData.varietasId}`
      );
    } else if (!activeData) {
      await ref.remove();
      console.log(`🌱 Varietas aktif dihapus dari Realtime Database`);
    }
  });
