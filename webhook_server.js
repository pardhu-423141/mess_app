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
app.post('/cashfree-webhook', async (req, res) => {
  console.log('🔔 Webhook received from Cashfree:');
  const data = req.body;
  console.log(data);

  const { orderId, txStatus } = data;

  // Basic validation
  if (!orderId || !txStatus) {
    console.error('❌ Missing orderId or txStatus in webhook');
    return res.status(400).send({ error: 'Invalid webhook data' });
  }

  try {
    const orderRef = db.collection('orders').doc(orderId);

    // Update payment_status field
    if (txStatus === 'SUCCESS') {
      await orderRef.update({ payment_status: 'success' });
      console.log(`✅ Payment success for order ${orderId}`);
    } else {
      await orderRef.update({ payment_status: 'failed' });
      console.log(`❌ Payment failed for order ${orderId}`);
    }

    res.sendStatus(200); // Acknowledge webhook
  } catch (error) {
    console.error('🔥 Firestore update error:', error);
    res.status(500).send({ error: 'Internal server error' });
  }
});


// 🟢 Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
