package com.recordapp

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object NoteStore {

    private fun notesDir(context: Context): File {
        val dir = File(context.getExternalFilesDir(null), "recordings")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    fun newNoteFile(context: Context): File {
        val fmt = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US)
        return File(notesDir(context), "${fmt.format(Date())}.txt")
    }

    fun allNotes(context: Context): List<File> =
        notesDir(context).listFiles { f -> f.extension == "txt" }
            ?.sortedByDescending { it.name }
            ?: emptyList()

    fun latestNote(context: Context): File? = allNotes(context).firstOrNull()

    fun todayNotes(context: Context): List<File> {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        return allNotes(context).filter { it.name.startsWith(today) }
    }

    fun deleteLatest(context: Context) = latestNote(context)?.delete()

    fun openFolder(context: Context): File = notesDir(context)
}
