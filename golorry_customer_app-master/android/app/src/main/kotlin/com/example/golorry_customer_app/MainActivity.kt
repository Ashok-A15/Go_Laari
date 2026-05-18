package com.example.golorry_customer_app

import android.os.Bundle
import com.google.android.gms.maps.MapsInitializer
import com.google.android.gms.maps.MapsInitializer.Renderer
import com.google.android.gms.maps.OnMapsSdkInitializedCallback
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Force the Legacy Google Maps Renderer to prevent blank/green screen crashes on budget devices like A015
        MapsInitializer.initialize(applicationContext, Renderer.LEGACY, object : OnMapsSdkInitializedCallback {
            override fun onMapsSdkInitialized(renderer: Renderer) {
                when (renderer) {
                    Renderer.LATEST -> android.util.Log.d("MapsRenderer", "The latest version of the renderer is used.")
                    Renderer.LEGACY -> android.util.Log.d("MapsRenderer", "The legacy version of the renderer is used.")
                }
            }
        })
    }
}
