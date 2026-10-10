package dev.fatsoenlijk.carplay

import android.content.Context
import androidx.fragment.app.FragmentActivity
import com.nativephp.mobile.bridge.BridgeFunction
import com.nativephp.mobile.bridge.BridgeResponse
import org.json.JSONArray
import org.json.JSONObject

object CarPlayFunctions {
    private fun map(o: JSONObject): Map<String, Any> = o.keys().asSequence().associateWith { key -> convert(o.get(key)) }
    private fun convert(v: Any): Any = when(v) {
        is JSONObject -> map(v)
        is JSONArray -> (0 until v.length()).map { convert(v.get(it)) }
        else -> v
    }
    fun call(context: Context, command: String, parameters: Map<String, Any>): Map<String, Any> = try {
        val store = CarEventStore.get(context); val p = JSONObject(parameters)
        when (command) {
            "Capabilities" -> {
                val status = store.status(); val api = status.optInt("carAppApiLevel", 0)
                mapOf("platform" to "androidAuto", "category" to "poi", "carAppApiLevel" to api, "templates" to CarRuntime.supportedTypes(api), "replace" to CarRuntime.supportedTypes(api).filter { it != "tabs" }, "modalAlerts" to false, "navigationHandoff" to true, "embeddedNavigation" to false, "audioPlayback" to false, "durableEvents" to true, "maxDepth" to 5, "icons" to CarContract.icons, "requiresCarApi" to mapOf("tabs" to 6))
            }
            "Status" -> map(store.status())
            "Events" -> {
                val number = if (p.has("limit")) p.opt("limit") as? Number ?: throw CarFailure("INVALID_PARAMETERS", "Invalid event limit.") else 100
                val numeric = number.toDouble()
                if (!numeric.isFinite() || numeric != kotlin.math.floor(numeric) || numeric !in 1.0..256.0) throw CarFailure("INVALID_PARAMETERS", "Event limit must be an integer 1..256.")
                val limit = number.toInt()
                map(store.events(limit))
            }
            "Acknowledge" -> {
                val a = p.optJSONArray("ids") ?: throw CarFailure("INVALID_PARAMETERS", "Expected event ID array.")
                if (a.length() > 256) throw CarFailure("INVALID_PARAMETERS", "At most 256 event IDs.")
                val ids = (0 until a.length()).map { (a.opt(it) as? String)?.takeIf { s -> s.isNotEmpty() && s.toByteArray().size <= 128 } ?: throw CarFailure("INVALID_PARAMETERS", "Invalid event ID.") }
                map(store.acknowledge(ids.toSet()))
            }
            "Present", "Dismiss" -> throw CarFailure("UNSUPPORTED", "Android Auto has no equivalent modal alert. Use a message screen and push/pop explicitly.")
            else -> {
                when (command) {
                    "SetRoot", "Push", "Replace" -> {
                        val t = p.optJSONObject("template") ?: throw CarFailure("INVALID_PARAMETERS", "Expected template object.")
                        CarContract.validate(t); CarRuntime.validateSupport(t, command, 8)
                    }
                    "Navigate" -> { CarContract.coordinate(p); if (p.has("name")) CarContract.text(p, "name", true) }
                    "Clear", "Pop", "PopToRoot" -> Unit
                    else -> throw CarFailure("INVALID_PARAMETERS", "Unknown command.")
                }
                CarRuntime.enqueue(context, command, p)
            }
        }
    } catch (e: Exception) { BridgeResponse.error((e as? CarFailure)?.code ?: "INVALID_PARAMETERS", e.message ?: "Bridge failed.") }

    class BindEvents(private val activity: FragmentActivity) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> {
            CarEventStore.get(activity).bind(activity)
            return mapOf("bound" to true)
        }
    }

    class Capabilities(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "Capabilities", parameters)
    }

    class Status(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "Status", parameters)
    }

    class SetRoot(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "SetRoot", parameters)
    }

    class Push(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "Push", parameters)
    }

    class Replace(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "Replace", parameters)
    }

    class Pop(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "Pop", parameters)
    }

    class PopToRoot(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "PopToRoot", parameters)
    }

    class Present(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "Present", parameters)
    }

    class Dismiss(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "Dismiss", parameters)
    }

    class Clear(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "Clear", parameters)
    }

    class Navigate(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "Navigate", parameters)
    }

    class Events(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "Events", parameters)
    }

    class Acknowledge(private val context: Context) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> = call(context, "Acknowledge", parameters)
    }
}
