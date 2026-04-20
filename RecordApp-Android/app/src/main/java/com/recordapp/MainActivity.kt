package com.recordapp

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.widget.*
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {

    companion object {
        var instance: MainActivity? = null
    }

    private lateinit var statusText: TextView
    private lateinit var noteList: ListView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        instance = this

        statusText = findViewById(R.id.statusText)
        noteList   = findViewById(R.id.noteList)

        findViewById<Button>(R.id.startBtn).setOnClickListener {
            val svc = RecorderService.instance
            if (svc != null) svc.beginRecording()
            else { RecorderService.start(this); startBtn.postDelayed({ RecorderService.instance?.beginRecording() }, 600) }
        }
        findViewById<Button>(R.id.stopBtn).setOnClickListener {
            RecorderService.instance?.endRecording()
        }
        findViewById<Button>(R.id.openFolderBtn).setOnClickListener {
            val dir = NoteStore.openFolder(this)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(dir.absolutePath), "resource/folder")
            }
            runCatching { startActivity(intent) }
        }

        noteList.setOnItemClickListener { _, _, pos, _ ->
            val file = NoteStore.allNotes(this).getOrNull(pos) ?: return@setOnItemClickListener
            val text = file.readText().trim().ifEmpty { "(No transcript — recording was audio only or speech was not recognized)" }

            val tv = TextView(this).apply {
                this.text = text
                textSize = 14f
                setPadding(48, 32, 48, 32)
            }
            val scroll = ScrollView(this).apply { addView(tv) }

            android.app.AlertDialog.Builder(this)
                .setTitle(file.name)
                .setView(scroll)
                .setPositiveButton("OK", null)
                .setNeutralButton("Copy") { _, _ ->
                    val cm = getSystemService(CLIPBOARD_SERVICE) as android.content.ClipboardManager
                    cm.setPrimaryClip(android.content.ClipData.newPlainText("note", text))
                    Toast.makeText(this, "Copied", Toast.LENGTH_SHORT).show()
                }
                .show()
        }

        SpeechFeedback.init(this)
        requestNeededPermissions()
        refreshNotes()
    }

    private val startBtn get() = findViewById<Button>(R.id.startBtn)

    private fun requestNeededPermissions() {
        val needed = arrayOf(Manifest.permission.RECORD_AUDIO, Manifest.permission.POST_NOTIFICATIONS)
            .filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        if (needed.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, needed.toTypedArray(), 1)
        } else {
            RecorderService.start(this)
        }
    }

    override fun onRequestPermissionsResult(req: Int, perms: Array<String>, results: IntArray) {
        super.onRequestPermissionsResult(req, perms, results)
        RecorderService.start(this)
    }

    fun updateStatus(text: String) {
        statusText.text = text
    }

    fun refreshNotes() {
        val notes = NoteStore.allNotes(this)
        noteList.adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, notes.map { it.name })
    }

    override fun onResume() {
        super.onResume()
        instance = this
        updateStatus(RecorderService.statusText)
        refreshNotes()
    }

    override fun onDestroy() {
        if (instance == this) instance = null
        super.onDestroy()
    }
}
