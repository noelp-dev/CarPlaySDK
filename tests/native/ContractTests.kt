package dev.fatsoenlijk.carplay

import java.io.File
import org.json.JSONArray

fun main(args: Array<String>) {
    val cases = JSONArray(File(args[0]).readText())
    for (i in 0 until cases.length()) {
        val test = cases.getJSONObject(i)
        val valid = try { CarContract.validate(test.getJSONObject("template")); true } catch (e: CarFailure) { false }
        check(valid == test.getBoolean("valid")) { "Mismatch: ${test.getString("name")}" }
    }
    println("PASS: ${cases.length()} Kotlin contract fixtures")
}
