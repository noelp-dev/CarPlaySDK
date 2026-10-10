package dev.fatsoenlijk.carplay

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.AtomicFile
import androidx.fragment.app.FragmentActivity
import com.nativephp.mobile.utils.NativeActionCoordinator
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.lang.ref.WeakReference
import java.util.UUID

class CarEventStore private constructor(context: Context) {
    private val file = AtomicFile(File(context.noBackupFilesDir, "nativephp-carplay-state.json"))
    private var state = JSONObject().put("events", JSONArray()).put("dropped", 0)
    private var connection = JSONObject().put("connected", false).put("platform", "androidAuto").put("depth", 0)
    private var persistenceError: String? = null
    private var activity = WeakReference<FragmentActivity>(null)
    companion object {
        @Volatile private var instance: CarEventStore? = null
        fun get(context: Context): CarEventStore = instance ?: synchronized(this) {
            instance ?: CarEventStore(context.applicationContext).also { instance = it }
        }
    }
    init {
        try { if (file.baseFile.exists() && file.baseFile.length() <= 1048576) state = JSONObject(String(file.readFully(), Charsets.UTF_8)) }
        catch (e: Exception) { persistenceError = e.message }
    }
    private fun save() {
        var stream: java.io.FileOutputStream? = null
        try {
            stream = file.startWrite(); stream.write(state.toString().toByteArray(Charsets.UTF_8)); file.finishWrite(stream)
            persistenceError = null
        } catch (e: Exception) { if (stream != null) file.failWrite(stream); persistenceError = e.message ?: "Persistence failed." }
    }
    @Synchronized fun bind(value: FragmentActivity) { activity = WeakReference(value) }
    @Synchronized fun emit(type: String, payload: JSONObject = JSONObject()) {
        val event = JSONObject().put("id", UUID.randomUUID().toString()).put("type", type).put("platform", "androidAuto").put("timestamp", System.currentTimeMillis() / 1000.0).put("payload", payload)
        val old = state.optJSONArray("events") ?: JSONArray(); val events = JSONArray()
        val offset = if (old.length() >= 256) 1 else 0
        for (i in offset until old.length()) events.put(old.getJSONObject(i))
        if (offset > 0) state.put("dropped", state.optInt("dropped") + 1)
        events.put(event); state.put("events", events); save()
        Handler(Looper.getMainLooper()).post {
            activity.get()?.takeUnless { it.isFinishing || it.isDestroyed }?.let {
                try { NativeActionCoordinator.dispatchEvent(it, "Fatsoenlijk\\CarPlay\\Events\\CarEvent", event.toString()) }
                catch (_: Exception) { android.util.Log.w("NativeCarPlay", "Immediate event forwarding unavailable; use the stored queue.") }
            }
        }
    }
    @Synchronized fun events(limit: Int): JSONObject {
        val events = JSONArray(); val queue = state.optJSONArray("events") ?: JSONArray()
        for (i in 0 until minOf(queue.length(), limit)) events.put(queue.getJSONObject(i))
        return JSONObject().put("events", events).put("dropped", state.optInt("dropped"))
    }
    @Synchronized fun acknowledge(ids: Set<String>): JSONObject {
        val queue = state.optJSONArray("events") ?: JSONArray(); val remaining = JSONArray()
        for (i in 0 until queue.length()) { val e = queue.getJSONObject(i); if (e.optString("id") !in ids) remaining.put(e) }
        state.put("events", remaining); save()
        return JSONObject().put("acknowledged", queue.length() - remaining.length()).put("persisted", persistenceError == null)
    }
    @Synchronized fun root(): JSONObject? = state.optJSONObject("root")?.let { JSONObject(it.toString()) }
    @Synchronized fun setRoot(root: JSONObject?) { if (root == null) state.remove("root") else state.put("root", JSONObject(root.toString())); save() }
    @Synchronized fun updateStatus(status: JSONObject) { connection = status }
    @Synchronized fun status(): JSONObject = JSONObject(connection.toString()).put("cachedRoot", state.has("root")).put("persistenceError", persistenceError ?: JSONObject.NULL)
}

fun initializeCarPlay(context: Context) { CarEventStore.get(context) }
