package dev.fatsoenlijk.carplay

import org.json.JSONArray
import org.json.JSONObject

class CarFailure(val code: String, override val message: String) : RuntimeException(message)

object CarContract {
    val icons = listOf("list", "grid", "search", "map", "pin", "parking", "charging", "food", "music", "play", "pause", "info", "star", "home")
    val types = listOf("list", "grid", "information", "message", "search", "tabs", "poi", "alert", "nowPlaying")
    private fun fail(message: String): Nothing = throw CarFailure("INVALID_PARAMETERS", message)
    fun text(o: JSONObject, key: String, empty: Boolean = false): String {
        val s = o.opt(key) as? String ?: fail("$key requires text.")
        if (s.toByteArray(Charsets.UTF_8).size > 512 || (!empty && s.isBlank())) fail("$key requires text up to 512 UTF-8 bytes.")
        return s
    }
    fun id(v: Any?): String {
        val s = v as? String ?: fail("Invalid identifier.")
        if (!s.matches(Regex("[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}"))) fail("Invalid identifier.")
        return s
    }
    private fun unique(v: Any?, ids: MutableSet<String>) { if (!ids.add(id(v))) fail("Duplicate ID.") }
    fun objects(o: JSONObject, key: String, min: Int, max: Int): List<JSONObject> {
        val a = o.opt(key) as? JSONArray ?: fail("$key requires an array.")
        if (a.length() !in min..max) fail("$key requires $min..$max objects.")
        return (0 until a.length()).map { a.opt(it) as? JSONObject ?: fail("Expected an object.") }
    }
    private fun keys(o: JSONObject, allowed: List<String>) { if (o.keys().asSequence().any { it !in allowed }) fail("Unknown field.") }
    private fun optionalText(o: JSONObject, key: String) { if (o.has(key)) text(o, key, true) }
    private fun boolean(o: JSONObject, key: String) { if (o.has(key) && o.opt(key) !is Boolean) fail("$key requires boolean.") }
    fun coordinate(o: JSONObject): Pair<Double, Double> {
        val lat = (o.opt("latitude") as? Number)?.toDouble() ?: fail("Latitude must be numeric.")
        val lon = (o.opt("longitude") as? Number)?.toDouble() ?: fail("Longitude must be numeric.")
        if (!lat.isFinite() || !lon.isFinite() || lat !in -90.0..90.0 || lon !in -180.0..180.0) fail("Invalid geographic coordinates.")
        return lat to lon
    }
    fun actions(o: JSONObject, required: Boolean = false): List<JSONObject> {
        if (!o.has("actions") && !required) return emptyList()
        val a = objects(o, "actions", if (required) 1 else 0, 2)
        val ids = mutableSetOf<String>()
        a.forEach { keys(it, listOf("id", "title", "style")); unique(it.opt("id"), ids); text(it, "title")
            if (it.has("style") && it.opt("style") !in listOf("normal", "cancel", "destructive")) fail("Unknown action style.") }
        return a
    }
    private fun item(r: JSONObject, ids: MutableSet<String>, grid: Boolean = false) {
        keys(r, listOf("id", "title", "detail", "icon", "action", "enabled")); unique(r.opt("id"), ids); text(r, "title")
        optionalText(r, "detail"); boolean(r, "enabled")
        if (r.has("action")) id(r.opt("action"))
        if ((grid || r.has("icon")) && r.opt("icon") !in icons) fail("Unknown icon.")
    }
    fun validate(t: JSONObject) {
        if (t.toString().toByteArray(Charsets.UTF_8).size > 262144) fail("Template exceeds 256 KiB.")
        node(t, mutableSetOf(), false)
    }
    private fun node(t: JSONObject, ids: MutableSet<String>, tab: Boolean) {
        unique(t.opt("id"), ids); text(t, "title")
        val type = t.opt("type") as? String ?: fail("Unknown template type.")
        if (type !in types) fail("Unknown template type.")
        if (tab && type !in listOf("list", "grid")) fail("Tab children must be list or grid.")
        if (t.has("icon") && t.opt("icon") !in icons) fail("Unknown icon.")
        val fields = when (type) {
            "list" -> listOf("sections", "loading")
            "grid" -> listOf("items")
            "information" -> listOf("items", "actions")
            "message" -> listOf("message", "actions")
            "search" -> listOf("items", "hint")
            "tabs" -> listOf("tabs")
            "poi" -> listOf("points")
            "alert" -> listOf("actions")
            else -> emptyList()
        }
        keys(t, listOf("id", "title", "type", "icon") + fields)
        actions(t, type == "alert")
        val rowIds = mutableSetOf<String>()
        when (type) {
            "list" -> {
                boolean(t, "loading"); var count = 0
                objects(t, "sections", 1, 10).forEach { s ->
                    keys(s, listOf("title", "items")); optionalText(s, "title")
                    val rows = objects(s, "items", 0, 100); count += rows.size
                    rows.forEach { item(it, rowIds) }
                }
                if (count > 100) fail("At most 100 list items.")
            }
            "grid", "search", "information" -> {
                objects(t, "items", if (type == "search") 0 else 1, when(type) { "grid" -> 8; "information" -> 4; else -> 100 }).forEach {
                    if (type == "information") { keys(it, listOf("title", "detail")); text(it, "title"); optionalText(it, "detail") }
                    else item(it, rowIds, type == "grid")
                }
                if (t.has("hint")) text(t, "hint")
            }
            "message" -> text(t, "message")
            "tabs" -> objects(t, "tabs", 2, 4).forEach { node(it, ids, true) }
            "poi" -> objects(t, "points", 1, 6).forEach {
                keys(it, listOf("id", "title", "subtitle", "summary", "latitude", "longitude", "actions"))
                unique(it.opt("id"), rowIds); text(it, "title"); coordinate(it); optionalText(it, "subtitle"); optionalText(it, "summary"); actions(it)
            }
        }
    }
}
