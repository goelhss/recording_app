package com.recordapp

import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.Locale

object SpeechFeedback {
    private var tts: TextToSpeech? = null
    private var ready = false

    fun init(context: Context) {
        if (tts != null) return
        tts = TextToSpeech(context.applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.US
                ready = true
            }
        }
    }

    fun speak(context: Context, text: String) {
        if (!ready) init(context)
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, null)
    }
}
