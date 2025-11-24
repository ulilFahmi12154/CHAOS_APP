const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize admin if not already initialized
try {
  admin.initializeApp();
} catch (e) {
  // already initialized
}

const db = admin.database();
const firestore = admin.firestore();

// Example: Mirror warning entries from Realtime DB path /warnings/{deviceId}/{pushId}
// into Firestore collection `notifications`. Adjust the path & field mappings to
// match your DB shape.

exports.mirrorWarningsToFirestore = functions.database
  .ref('/warnings/{deviceId}/{pushId}')
  .onCreate(async (snapshot, context) => {
    const payload = snapshot.val();
    const deviceId = context.params.deviceId;
    const pushId = context.params.pushId;

    // Build a normalized document for Firestore
    const doc = {
      title: payload.title || `Warning from ${deviceId}`,
      message: payload.message || payload.msg || '',
      level: payload.level || 'warning',
      sensor: payload.sensor || deviceId,
      source: payload.source || deviceId,
      data: payload.data || payload,
      // prefer device timestamp if provided, otherwise server timestamp
      timestamp:
        payload.device_timestamp || payload.ts || admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
      await firestore.collection('notifications').add(doc);
      console.log('Mirrored warning to Firestore', deviceId, pushId);
    } catch (err) {
      console.error('Failed writing notification', err);
    }
  });
