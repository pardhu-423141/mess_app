const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const fs = require('fs');

// 🔐 Load Firebase service account credentials
let serviceAccount;
try {
  // Try to load from file first
  serviceAccount = require('./firebase_service_account.json');
  console.log('✅ Firebase service account loaded from file successfully');
} catch (error) {
  console.warn('⚠️ Could not load service account from file:', error.message);
  
  // Try to use environment variables as fallback
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
      console.log('✅ Firebase service account loaded from environment variable');
    } catch (parseError) {
      console.error('❌ Failed to parse FIREBASE_SERVICE_ACCOUNT environment variable:', parseError.message);
    }
  }
  
  if (!serviceAccount) {
    console.error('❌ No Firebase service account found. Please provide either:');
    console.error('   1. firebase_service_account.json file');
    console.error('   2. FIREBASE_SERVICE_ACCOUNT environment variable');
    process.exit(1);
  }
}

// 🔧 Initialize Firebase Admin
try {
  const initConfig = {
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id, // Explicitly set project ID
  };
  
  // Add additional config for production environments
  if (process.env.NODE_ENV === 'production') {
    console.log('🔧 Running in production mode');
  }
  
  admin.initializeApp(initConfig);
  console.log(`✅ Firebase Admin initialized successfully for project: ${serviceAccount.project_id}`);
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin:', error.message);
  console.error('💡 This might be due to:');
  console.error('   1. Invalid service account credentials');
  console.error('   2. Network connectivity issues');
  console.error('   3. Incorrect project configuration');
  process.exit(1);
}

// 📦 Firestore instance
const db = admin.firestore();

// Test Firestore connection
async function testFirestoreConnection() {
  try {
    // Try to read from a collection to test the connection
    await db.collection('test').limit(1).get();
    console.log('✅ Firestore connection test successful');
  } catch (error) {
    console.error('❌ Firestore connection test failed:', error.message);
    if (error.code === 16) {
      console.error('🔐 Authentication Error: Please check your Firebase service account credentials');
    }
  }
}

// Test connection on startup
testFirestoreConnection();

// 🚀 Express app setup
const app = express();
app.use(bodyParser.json());

// 🔔 Send FCM notification to all 'regular' users
const sendNotificationToRegularUsers = async (title, body) => {
  try {
    console.log(`📤 Sending notification: ${title} - ${body}`);
    const snapshot = await db.collection('users').where('role', '==', 'regular').get();

    const tokens = snapshot.docs
      .map(doc => doc.data().fcm_token)
      .filter(token => !!token); // remove null/undefined

    if (tokens.length === 0) {
      console.log('ℹ️ No FCM tokens found for regular users');
      return;
    }

    const message = {
      notification: { title, body },
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`✅ Sent to ${response.successCount}, failed: ${response.failureCount}`);
    
    if (response.failureCount > 0) {
      console.log('❌ Failed tokens:', response.responses.filter(r => !r.success).map(r => r.error?.message));
    }
  } catch (error) {
    console.error('❌ Error sending notifications:', error.message);
    if (error.code === 16) {
      console.error('🔐 Authentication Error: Cannot access Firestore to get user tokens');
    }
  }
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

// 🔔 Endpoint: Receive webhook from Cashfree (new endpoint)
app.post('/webhook', async (req, res) => {
  console.log('🔔 Webhook received at /webhook');
  console.log('📦 Raw Request Body:', JSON.stringify(req.body, null, 2));
  
  try {
    const data = req.body;
    
    // Validate webhook type
    if (data.type !== 'PAYMENT_SUCCESS_WEBHOOK') {
      console.log(`ℹ️ Skipping webhook type: ${data.type}`);
      return res.status(200).send({ status: 'acknowledged' });
    }
    
    // Extract order and payment information
    const orderData = data.data?.order;
    const paymentData = data.data?.payment;
    
    if (!orderData || !paymentData) {
      console.error('❌ Missing order or payment data in webhook');
      return res.status(400).send({ error: 'Invalid webhook data structure' });
    }
    
    const orderId = orderData.order_id;
    const paymentStatus = paymentData.payment_status;
    const paymentAmount = paymentData.payment_amount;
    
    if (!orderId || !paymentStatus) {
      console.error('❌ Missing orderId or paymentStatus in webhook');
      return res.status(400).send({ error: 'Missing required fields' });
    }
    
    console.log(`📋 Processing order: ${orderId}, status: ${paymentStatus}, amount: ${paymentAmount}`);
    
    // Update Firestore
    const orderRef = db.collection('orders').doc(orderId);
    
    if (paymentStatus === 'SUCCESS') {
      await orderRef.update({ 
        payment_status: 'success',
        payment_amount: paymentAmount,
        payment_time: paymentData.payment_time,
        cf_payment_id: paymentData.cf_payment_id,
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`✅ Payment success for order ${orderId} - Amount: ₹${paymentAmount}`);
      
      // Send notification to regular users about successful payment
      await sendNotificationToRegularUsers(
        'Payment Successful', 
        `Your payment of ₹${paymentAmount} has been processed successfully.`
      );
    } else {
      await orderRef.update({ 
        payment_status: 'failed',
        payment_message: paymentData.payment_message || 'Payment failed',
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`❌ Payment failed for order ${orderId}`);
    }
    
    res.status(200).send({ status: 'success', message: 'Webhook processed successfully' });
    
  } catch (error) {
    console.error('❌ Error processing webhook:', error);
    
    // Log more details about the error
    if (error.code === 16) {
      console.error('🔐 Authentication Error: Firestore credentials may be invalid or expired');
      console.error('💡 Please check your Firebase service account credentials');
    }
    
    res.status(500).send({ error: 'Internal server error', details: error.message });
  }
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
