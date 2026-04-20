package com.recordapp

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

class RecorderService : Service() {

    enum class State { IDLE, RECORDING }

    private var state = State.IDLE
    private var recognizer: SpeechRecognizer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var currentNoteFile: java.io.File? = null
    private var recognizerBusy = false
    private var restartPending = false

    companion object {
        const val NOTIF_ID = 1
        const val CHANNEL_ID = "recordapp"
        var statusText = "Listening for Genie…"
        var instance: RecorderService? = null

        fun start(context: Context) {
            context.startForegroundService(Intent(context, RecorderService::class.java))
        }
    }

    // MARK: - Lifecycle

    override fun onCreate() {
        super.onCreate()
        instance = this
        createChannel()
        startForeground(NOTIF_ID, buildNotification(statusText))
        SpeechFeedback.init(this)
        createRecognizer()
        listen()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        recognizer?.destroy()
        instance = null
        super.onDestroy()
    }

    // MARK: - SpeechRecognizer

    private fun createRecognizer() {
        recognizer?.destroy()
        recognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(recognitionListener)
        }
    }

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(p: Bundle?) { recognizerBusy = true }
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rms: Float) {}
        override fun onBufferReceived(b: ByteArray?) {}
        override fun onEndOfSpeech() {}

        override fun onPartialResults(b: Bundle?) {
            val text = b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: return
            // Partial: only use for idle wake word detection (fast response)
            if (state == State.IDLE) {
                val cmd = VoiceCommandParser.parse(text)
                if (cmd == VoiceCommand.START_RECORDING) beginRecording()
            }
        }

        override fun onResults(b: Bundle?) {
            val text = b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
            recognizerBusy = false
            handleFinalText(text)
            scheduleRestart(300)
        }

        override fun onError(error: Int) {
            recognizerBusy = false
            // ERROR_NO_MATCH / ERROR_SPEECH_TIMEOUT = silence — restart quickly
            val delay = if (error == SpeechRecognizer.ERROR_NO_MATCH ||
                            error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) 300L else 1500L
            scheduleRestart(delay)
        }

        override fun onEvent(type: Int, b: Bundle?) {}
    }

    private fun listen() {
        if (recognizerBusy || restartPending) return
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        try {
            recognizer?.startListening(intent)
        } catch (e: Exception) {
            scheduleRestart(1000)
        }
    }

    private fun scheduleRestart(delayMs: Long) {
        if (restartPending) return
        restartPending = true
        handler.postDelayed({
            restartPending = false
            listen()
        }, delayMs)
    }

    // MARK: - Command handling

    private fun handleFinalText(text: String) {
        val cmd = VoiceCommandParser.parse(text)
        when (state) {
            State.IDLE -> when (cmd) {
                VoiceCommand.START_RECORDING -> beginRecording()
                else -> {}
            }
            State.RECORDING -> when (cmd) {
                VoiceCommand.STOP_RECORDING -> endRecording()
                else -> {
                    // Append speech to note, stripping any accidental wake word prefix
                    val clean = stripWakeWord(text).trim()
                    if (clean.isNotBlank()) {
                        currentNoteFile?.appendText(clean + "\n")
                    }
                }
            }
        }
    }

    // MARK: - Recording

    fun beginRecording() {
        state = State.RECORDING
        currentNoteFile = NoteStore.newNoteFile(this)
        currentNoteFile?.writeText("Recorded: ${java.util.Date()}\n\n")
        updateStatus("● Recording…")
        SpeechFeedback.speak(this, "Starting recording")
    }

    fun endRecording() {
        if (state != State.RECORDING) return
        state = State.IDLE
        val saved = currentNoteFile
        currentNoteFile = null
        updateStatus("Listening for Genie…")
        SpeechFeedback.speak(this, "Recording saved")
        if (saved != null) {
            MainActivity.instance?.runOnUiThread { MainActivity.instance?.refreshNotes() }
        }
    }

    // MARK: - Helpers

    private fun stripWakeWord(text: String): String {
        val lower = text.lowercase()
        val wakes = listOf("hey recorder", "hey record", "he recorder", "he record",
                           "recorder", "genie", "jeanie", "jeannie", "ginny", "jenny", "jinny")
        for (wake in wakes) {
            val idx = lower.indexOf(wake)
            if (idx >= 0) {
                return text.substring(idx + wake.length)
                    .replace(Regex("(?i)^\\s*(start recording|start|stop recording|stop)\\s*"), "")
                    .trim()
            }
        }
        return text
    }

    private fun updateStatus(text: String) {
        statusText = text
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIF_ID, buildNotification(text))
        MainActivity.instance?.runOnUiThread { MainActivity.instance?.updateStatus(text) }
    }

    private fun buildNotification(text: String): Notification {
        val pi = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("RecordApp")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    private fun createChannel() {
        val ch = NotificationChannel(CHANNEL_ID, "RecordApp", NotificationManager.IMPORTANCE_LOW)
        getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
    }
}
