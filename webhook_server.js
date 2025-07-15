const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const fs = require('fs');

// Replace with path to your downloaded service account key
const serviceAccount = require('./firebase_service_account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const app = express();
app.use(bodyParser.json());

const sendNotificationToRegularUsers = async (title, body) => {
  const snapshot = await db.collection('users').where('role', '==', 'regular').get();

  const tokens = snapshot.docs
    .map(doc => doc.data().fcm_token)
    .filter(token => !!token); // Remove null/undefined

  if (tokens.length === 0) return;

  const message = {
    notification: { title, body },
    tokens: tokens,
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  console.log(`✅ Sent to ${response.successCount}, failed: ${response.failureCount}`);
};

app.post('/messStart', async (req, res) => {
  await sendNotificationToRegularUsers('Mess Started', 'Mess service has started.');
  res.send({ status: 'Mess Start notification sent' });
});

app.post('/messEnd', async (req, res) => {
  await sendNotificationToRegularUsers('Mess Ended', 'Mess service has ended.');
  res.send({ status: 'Mess End notification sent' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
