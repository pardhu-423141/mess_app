const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

exports.generateCashfreeToken = functions.https.onCall(async (data, context) => {
  const { orderId, orderAmount, customerEmail, customerPhone } = data;

  try {
    const response = await axios.post(
      'https://sandbox.cashfree.com/pg/orders',
      {
        order_id: orderId,
        order_amount: orderAmount,
        order_currency: 'INR',
        customer_details: {
          customer_id: customerEmail,
          customer_email: customerEmail,
          customer_phone: customerPhone,
        },
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'x-api-version': '2022-09-01',
          'x-client-id': 'TEST1070066112e93ffbe0458667a64116600701',
          'x-client-secret': 'cfsk_ma_test_7094f9e3fdde0c5967e7d33c8e684057_a20d08ad',
        },
      }
    );

    return {
      success: true,
      orderToken: response.data.order_token,
    };
  } catch (error) {
    console.error('Cashfree Token Error:', error.response?.data || error.message);
    return {
      success: false,
      error: error.response?.data || error.message,
    };
  }
});
