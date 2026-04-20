package com.recordapp

enum class VoiceCommand {
    START_RECORDING, STOP_RECORDING, CONVERT_TO_TEXT,
    APPEND_TO_LAST, PLAYBACK_LATEST, PLAYBACK_TODAY,
    DELETE_LATEST, WHERE_SAVED, HOW_MANY_TODAY
}

object VoiceCommandParser {
    fun parse(text: String): VoiceCommand? {
        val t = text.lowercase()
            .replace(",", "")
            .replace(".", "")
            .replace("!", "")

        val hasWake = t.contains("hey recorder") || t.contains("hey record")
                   || t.contains("he recorder")  || t.contains("he record")
                   || t.contains("recorder")
                   || t.contains("genie")  || t.contains("jeanie") || t.contains("jeannie")
                   || t.contains("ginny")  || t.contains("jenny")  || t.contains("jinny")
                   || t.contains("rrr")
        if (!hasWake) return null

        if (t.contains("stop")  || t.contains("close"))                           return VoiceCommand.STOP_RECORDING
        if (t.contains("convert"))                                                  return VoiceCommand.CONVERT_TO_TEXT
        if (t.contains("start") || t.contains("chart") || t.contains("guard"))    return VoiceCommand.START_RECORDING
        if (t.contains("append"))                                                   return VoiceCommand.APPEND_TO_LAST
        if (t.contains("play")  && t.contains("today"))                            return VoiceCommand.PLAYBACK_TODAY
        if (t.contains("play")  && t.contains("latest"))                           return VoiceCommand.PLAYBACK_LATEST
        if (t.contains("delete"))                                                   return VoiceCommand.DELETE_LATEST
        if (t.contains("where") && t.contains("saved"))                            return VoiceCommand.WHERE_SAVED
        if (t.contains("how many"))                                                 return VoiceCommand.HOW_MANY_TODAY
        return null
    }
}
