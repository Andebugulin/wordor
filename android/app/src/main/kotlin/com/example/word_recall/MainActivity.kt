package com.example.wordor

import android.speech.tts.TextToSpeech
import android.speech.tts.TextToSpeech.OnInitListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity: FlutterActivity(), OnInitListener {
    private val CHANNEL = "word_recall/tts"
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        tts = TextToSpeech(this, this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text")
                    val language = call.argument<String>("language")
                    
                    if (ttsReady && text != null && language != null) {
                        val locale = Locale(language)
                        tts?.language = locale
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, null)
                        result.success(null)
                    } else {
                        result.error("TTS_ERROR", "TTS not ready", null)
                    }
                }
                "stop" -> {
                    tts?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            ttsReady = true
        }
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }
}