package com.example.screenjail

import android.os.Handler
import android.os.Looper
import okhttp3.Call
import okhttp3.Callback
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import org.json.JSONObject
import java.io.IOException

/** サーバーに端末を登録し、token を受け取る（POST /api/devices） */
object DeviceRegistrar {
    private val client = OkHttpClient()
    private val main = Handler(Looper.getMainLooper())

    fun register(baseUrl: String, name: String, clientId: String, onResult: (token: String?, error: String?) -> Unit) {
        val url = baseUrl.trimEnd('/') + "/api/devices"
        // client_id（ANDROID_ID）を送ると、再インストールでも同じ端末として扱われる
        val body = FormBody.Builder().add("name", name).add("client_id", clientId).build()
        val request = Request.Builder()
            .url(url)
            .addHeader("ngrok-skip-browser-warning", "1")
            .post(body)
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                main.post { onResult(null, e.message) }
            }

            override fun onResponse(call: Call, response: Response) {
                val text = response.body?.string().orEmpty()
                val token = runCatching { JSONObject(text).optString("token").ifBlank { null } }.getOrNull()
                main.post {
                    if (token != null) onResult(token, null)
                    else onResult(null, "登録に失敗しました（${response.code}）")
                }
            }
        })
    }
}
