package com.nativephp.mobile.bridge

// Only the NativePHP bridge boundary is substituted; all AndroidX APIs are real jars.
interface BridgeFunction { fun execute(parameters: Map<String, Any>): Map<String, Any> }
object BridgeResponse {
    fun error(code: String, message: String): Map<String, Any> = mapOf("status" to "error", "code" to code, "message" to message)
}
