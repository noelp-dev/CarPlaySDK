package dev.fatsoenlijk.carplay

import android.content.Intent
import android.content.pm.ApplicationInfo
import androidx.car.app.CarAppService
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import org.json.JSONObject

class NativeCarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator {
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        // Google's signed host list from androidx.car.app 1.7.0; arbitrary packages are rejected.
        val builder = HostValidator.Builder(this)
        listOf("fdb00c43dbde8b51cb312aa81d3b5fa17713adb94b28f598d77f8eb89daceedf", "70811a3eacfd2e83e18da9bfede52df16ce91f2e69a44d21f18ab66991130771", "1975b2f17177bc89a5dff31f9e64a6cae281a53dc1d1d59b1d147fe1c82afa00").forEach {
            builder.addAllowedHost("com.google.android.projection.gearhead", it)
        }
        return builder.build()
    }
    override fun onCreateSession(): Session = object : Session() {
        override fun onCreateScreen(intent: Intent): Screen {
            val store = CarEventStore.get(carContext)
            val cached = store.root()
            val initial = try {
                if (cached != null) { CarContract.validate(cached); CarRuntime.validateSupport(cached, "SetRoot", carContext.carAppApiLevel); cached }
                else CarRuntime.placeholder()
            } catch (e: Exception) {
                store.emit("error", JSONObject().put("code", "INVALID_CACHE").put("message", e.message)); CarRuntime.placeholder()
            }
            val screen = CarScreen(carContext, initial)
            CarRuntime.attach(screen)
            store.emit("connected", JSONObject().put("carAppApiLevel", carContext.carAppApiLevel))
            lifecycle.addObserver(object : DefaultLifecycleObserver {
                override fun onDestroy(owner: LifecycleOwner) { CarRuntime.detach(screen); store.emit("disconnected") }
            })
            return screen
        }
    }
}
