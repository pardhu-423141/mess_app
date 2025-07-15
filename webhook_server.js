const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const fs = require('fs');

// 🔐 Load Firebase service account credentials
const serviceAccount = require('./firebase_service_account.json');

// 🔧 Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// 📦 Firestore instance
const db = admin.firestore();

// 🚀 Express app setup
const app = express();
app.use(bodyParser.json());

// 🔔 Send FCM notification to all 'regular' users
const sendNotificationToRegularUsers = async (title, body) => {
  const snapshot = await db.collection('users').where('role', '==', 'regular').get();

  const tokens = snapshot.docs
    .map(doc => doc.data().fcm_token)
    .filter(token => !!token); // remove null/undefined

  if (tokens.length === 0) return;

  const message = {
    notification: { title, body },
    tokens: tokens,
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  console.log(`✅ Sent to ${response.successCount}, failed: ${response.failureCount}`);
};

// 🔘 Endpoint: Trigger mess start notification
app.post('/messStart', async (req, res) => {
  await sendNotificationToRegularUsers('Mess Started', 'Mess service has started.');
  res.send({ status: 'Mess Start notification sent' });
});

// 🔘 Endpoint: Trigger mess end notification
app.post('/messEnd', async (req, res) => {
  await sendNotificationToRegularUsers('Mess Ended', 'Mess service has ended.');
  res.send({ status: 'Mess End notification sent' });
});

// 🔔 Endpoint: Receive webhook from Cashfree
app.post('/cashfree-webhook', (req, res) => {
  console.log('🔔 Webhook received from Cashfree:');
  console.log(req.body);

  // TODO: Optional: Verify x-cashfree-signature for security

  res.sendStatus(200); // acknowledge receipt
});

// 🟢 Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
