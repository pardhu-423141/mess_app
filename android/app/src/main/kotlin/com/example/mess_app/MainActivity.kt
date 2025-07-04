package com.example.mess_app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.*

class MainActivity: FlutterActivity() {
    private val LAUNCHER_CHANNEL = "upi_launcher"
    private val PAYMENT_CHANNEL = "upi_payment_channel"
    private val CALLBACK_SCHEME = "messapp"
    
    // UPI Configuration matching your intent
    private val UPI_ID = "Q612775677@ybl"
    private val MERCHANT_NAME = "PhonePeMerchant"
    private val MERCHANT_CATEGORY = "0000"
    private val MODE = "02" // P2P mode as per your intent
    private val PURPOSE = "00" // General purpose as per your intent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchUpiTransaction" -> {
                    val upiId = call.argument<String>("upiId") ?: UPI_ID
                    val name = call.argument<String>("name") ?: MERCHANT_NAME
                    val amount = call.argument<Double>("amount") ?: 0.0
                    val packageName = call.argument<String>("packageName") ?: ""
                    val note = call.argument<String>("note") ?: "Mess Payment"
                    
                    launchUpiTransaction(upiId, name, amount, packageName, note, result)
                }
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    result.success(isAppInstalled(packageName))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handlePaymentResponse(intent)
    }

    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun launchUpiTransaction(
        upiId: String,
        name: String,
        amount: Double,
        packageName: String,
        note: String,
        result: MethodChannel.Result
    ) {
        try {
            // Generate transaction reference
            val transactionRef = generateTransactionId()
            
            // Create UPI URL matching your intent format
            val uri = generateUpiUrl(upiId, name, amount, transactionRef, note)

            // Create intent
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                if (packageName.isNotEmpty()) {
                    setPackage(packageName)
                }
                
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                
                addCategory(Intent.CATEGORY_DEFAULT)
                addCategory(Intent.CATEGORY_BROWSABLE)
            }

            // Launch UPI app
            val resolveInfos = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            if (resolveInfos.isNotEmpty()) {
                startActivity(intent)
                result.success(mapOf(
                    "status" to "INITIATED",
                    "txnId" to transactionRef,
                    "amount" to amount,
                    "upiId" to upiId,
                    "timestamp" to System.currentTimeMillis()
                ))
            } else {
                // Try without package specification
                intent.setPackage(null)
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    result.success(mapOf(
                        "status" to "INITIATED", 
                        "txnId" to transactionRef,
                        "fallback" to true
                    ))
                } else {
                    result.error("NO_UPI_APP", "No UPI app available to handle payment", null)
                }
            }
        } catch (e: SecurityException) {
            result.error("SECURITY_ERROR", "Payment blocked: ${e.message}", null)
        } catch (e: Exception) {
            result.error("LAUNCH_FAILED", "Payment launch failed: ${e.message}", null)
        }
    }

    // Generate UPI URL matching your intent format
    private fun generateUpiUrl(
        upiId: String,
        name: String,
        amount: Double,
        transactionRef: String,
        note: String
    ): Uri {
        return Uri.parse("upi://pay").buildUpon()
            .appendQueryParameter("pa", upiId) // Payee address
            .appendQueryParameter("pn", name) // Payee name
            .appendQueryParameter("mc", MERCHANT_CATEGORY) // Merchant category (0000)
            .appendQueryParameter("mode", MODE) // Mode (02 as per your intent)
            .appendQueryParameter("purpose", PURPOSE) // Purpose (00 as per your intent)
            .appendQueryParameter("am", String.format("%.2f", amount)) // Amount
            .appendQueryParameter("cu", "INR") // Currency
            .appendQueryParameter("tn", note) // Transaction note
            .appendQueryParameter("tr", transactionRef) // Transaction reference
            .appendQueryParameter("tid", transactionRef) // Transaction ID
            .appendQueryParameter("url", "$CALLBACK_SCHEME://payment") // Callback URL
            .build()
    }

    // Generate transaction ID
    private fun generateTransactionId(): String {
        val timestamp = System.currentTimeMillis()
        val random = (100000..999999).random()
        return "MESS${timestamp}${random}"
    }

    private fun handlePaymentResponse(intent: Intent) {
        intent.data?.let { uri ->
            if (uri.scheme == CALLBACK_SCHEME || uri.toString().contains("payment")) {
                val status = extractPaymentStatus(uri)
                val txnId = uri.getQueryParameter("txnId") ?: 
                          uri.getQueryParameter("txnRef") ?: 
                          uri.getQueryParameter("transactionId") ?: ""
                val responseCode = uri.getQueryParameter("responseCode") ?: 
                                 uri.getQueryParameter("Status") ?: ""
                val approvalRef = uri.getQueryParameter("ApprovalRefNo") ?: 
                                uri.getQueryParameter("approvalRef") ?: ""
                
                val response = mapOf(
                    "status" to status,
                    "txnId" to txnId,
                    "responseCode" to responseCode,
                    "approvalRef" to approvalRef,
                    "timestamp" to System.currentTimeMillis().toString(),
                    "verified" to validatePaymentResponse(status, txnId, responseCode),
                    "rawUri" to uri.toString()
                )

                flutterEngine?.dartExecutor?.let { executor ->
                    MethodChannel(executor.binaryMessenger, PAYMENT_CHANNEL).invokeMethod(
                        "onPaymentResponse", 
                        response
                    )
                }
            }
        }
    }

    // Extract payment status from various possible parameters
    private fun extractPaymentStatus(uri: Uri): String {
        return uri.getQueryParameter("Status") ?: 
               uri.getQueryParameter("status") ?: 
               uri.getQueryParameter("txnStatus") ?: 
               uri.getQueryParameter("paymentStatus") ?: 
               "UNKNOWN"
    }

    // Validate payment response
    private fun validatePaymentResponse(status: String, txnId: String, responseCode: String): Boolean {
        return when {
            status.uppercase() == "SUCCESS" -> true
            status.uppercase() == "SUBMITTED" -> true
            responseCode == "00" -> true
            responseCode.uppercase() == "SUCCESS" -> true
            txnId.startsWith("MESS") && txnId.length > 10 -> true
            else -> false
        }
    }

    override fun onResume() {
        super.onResume()
        // Handle case where user returns from UPI app without callback
        val intent = intent
        if (intent != null && intent.data != null) {
            handlePaymentResponse(intent)
        }
    }
}