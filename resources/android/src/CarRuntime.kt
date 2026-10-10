package dev.fatsoenlijk.carplay

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import java.lang.ref.WeakReference
import java.util.UUID
import java.util.concurrent.Semaphore
import org.json.JSONObject

/** UI state is exclusively accessed by the main looper. Bridge reads use store snapshots. */
object CarRuntime {
    private var root = WeakReference<CarScreen>(null)
    private val slots = Semaphore(64)
    fun placeholder(): JSONObject = JSONObject("""{"id":"nativephp-waiting","type":"list","title":"Open the app to load content","sections":[{"items":[]}]}""")
    fun attach(screen: CarScreen) { root = WeakReference(screen); updateStatus(screen) }
    fun detach(screen: CarScreen) {
        if (root.get() === screen) {
            root.clear(); CarEventStore.get(screen.carContext).updateStatus(JSONObject().put("platform", "androidAuto").put("connected", false).put("depth", 0))
        }
    }
    fun updateStatus(screen: CarScreen) {
        CarEventStore.get(screen.carContext).updateStatus(JSONObject().put("platform", "androidAuto").put("category", "poi").put("connected", true).put("depth", screen.screenManager.stackSize)
            .put("templateId", screen.document.getString("id")).put("carAppApiLevel", screen.carContext.carAppApiLevel))
    }
    fun supportedTypes(api: Int): List<String> = listOf("list", "grid", "information", "message", "search", "poi") + if (api >= 6) listOf("tabs") else emptyList()
    fun validateSupport(t: JSONObject, command: String, api: Int) {
        if (t.getString("type") !in supportedTypes(api)) throw CarFailure("UNSUPPORTED", "Template is unavailable on Android Auto / negotiated Car App API $api.")
        if (t.getString("type") == "tabs" && command != "SetRoot") throw CarFailure("INVALID_PARAMETERS", "Tabs are root-only.")
    }
    fun enqueue(context: Context, command: String, params: JSONObject): Map<String, Any> {
        if (!slots.tryAcquire()) throw CarFailure("QUEUE_FULL", "Maximum pending operations reached.")
        val id = UUID.randomUUID().toString(); val store = CarEventStore.get(context)
        Handler(Looper.getMainLooper()).post {
            try {
                val screen = root.get(); val t = params.optJSONObject("template")
                if (t != null) validateSupport(t, command, screen?.carContext?.carAppApiLevel ?: 8)
                if (command == "SetRoot" && screen == null) { store.setRoot(t) }
                else if (command == "Clear" && screen == null) { store.setRoot(null) }
                else {
                    val active = screen ?: throw CarFailure("NOT_CONNECTED", "Connect Android Auto first.")
                    val manager = active.screenManager
                    when (command) {
                        "SetRoot", "Clear" -> {
                            val doc = if (command == "Clear") placeholder() else t!!
                            active.render(doc) // Validate native model constraints before mutating state.
                            manager.popToRoot(); active.document = doc; active.invalidate()
                            store.setRoot(if (command == "Clear") null else doc)
                        }
                        "Push" -> {
                            if (manager.stackSize >= 5) throw CarFailure("INVALID_PARAMETERS", "Maximum stack depth reached.")
                            val next = CarScreen(active.carContext, t!!); next.render(t); manager.push(next)
                        }
                        "Replace" -> {
                            val visible = manager.top as? CarScreen ?: throw CarFailure("UNSUPPORTED", "Visible screen is not managed by this bridge.")
                            if (visible.document.getString("id") != t!!.getString("id") || visible.document.getString("type") != t.getString("type")) throw CarFailure("INVALID_PARAMETERS", "Replace requires the visible template ID and type.")
                            visible.render(t); visible.document = t; visible.invalidate()
                            if (visible === active) store.setRoot(t)
                        }
                        "Pop" -> { if (manager.stackSize < 2) throw CarFailure("INVALID_PARAMETERS", "Cannot pop the root."); manager.pop() }
                        "PopToRoot" -> manager.popToRoot()
                        "Navigate" -> {
                            val (lat, lon) = CarContract.coordinate(params)
                            // Hand off to the host; never try to launch a handset Activity from the car.
                            active.carContext.startCarApp(Intent(CarContext.ACTION_NAVIGATE, Uri.parse("geo:$lat,$lon?q=$lat,$lon")))
                        }
                        else -> throw CarFailure("UNSUPPORTED", "$command is not available on Android Auto.")
                    }
                    (manager.top as? CarScreen)?.let { updateStatus(it) }
                }
                store.emit("operationCompleted", JSONObject().put("operationId", id).put("command", command).put("success", true).put("code", "OK").put("message", ""))
            } catch (e: Exception) {
                store.emit("operationCompleted", JSONObject().put("operationId", id).put("command", command).put("success", false).put("code", (e as? CarFailure)?.code ?: "HOST_REJECTED").put("message", e.message ?: "Host rejected operation."))
            } finally { slots.release() }
        }
        return mapOf("accepted" to true, "operationId" to id)
    }
}
