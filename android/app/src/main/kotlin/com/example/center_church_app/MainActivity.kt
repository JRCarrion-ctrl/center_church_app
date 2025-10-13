package com.jcarriondev.ccfapp

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // This ensures AppAuth receives the redirect intent
    }
}
