package com.example.screenjail

import android.os.Handler
import android.os.Looper
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Action Cable の最小クライアント。
 * OkHttp はブラウザではないので Origin を送らない → サーバーに拒否される。
 * そこで Origin と Authorization ヘッダーを自分で付ける（Kaigi on Rails の講演の肝）。
 */
class CableClient(
    private val baseUrl: String,   // 例: https://xxxx.ngrok-free.dev
    private val token: String,
    private val listener: Listener
) {
    interface Listener {
        /** サーバーから届いた現在の状態（locked / mode / opacity / message） */
        fun onState(state: JSONObject)
        fun onConnected()
        fun onDisconnected()
    }

    private val client = OkHttpClient.Builder()
        .pingInterval(10, TimeUnit.SECONDS)
        .build()

    private val main = Handler(Looper.getMainLooper())
    private var socket: WebSocket? = null
    private var closedByUser = false
    private var retryMs = 1000L

    // DeviceChannel の購読識別子
    private val identifier = JSONObject().put("channel", "DeviceChannel").toString()

    fun connect() {
        closedByUser = false
        openSocket()
    }

    fun disconnect() {
        closedByUser = true
        socket?.close(1000, "bye")
        socket = null
    }

    /** 3 秒ごとに呼ぶ生存通知 */
    fun sendHeartbeat() = perform("heartbeat")

    /** 覆いが実際に出ているかを報告する */
    fun reportOverlay(shown: Boolean) = perform("report", JSONObject().put("overlay_shown", shown))

    private fun perform(action: String, extra: JSONObject = JSONObject()) {
        val data = extra.put("action", action)
        val msg = JSONObject()
            .put("command", "message")
            .put("identifier", identifier)
            .put("data", data.toString())
        socket?.send(msg.toString())
    }

    private fun openSocket() {
        val wsUrl = baseUrl.replaceFirst("http", "ws").trimEnd('/') + "/cable"
        val request = Request.Builder()
            .url(wsUrl)
            .addHeader("Origin", baseUrl.trimEnd('/'))
            .addHeader("Authorization", "Bearer $token")
            .addHeader("ngrok-skip-browser-warning", "1")
            .build()

        socket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(ws: WebSocket, response: Response) {
                retryMs = 1000L
                // DeviceChannel を購読する
                ws.send(JSONObject().put("command", "subscribe").put("identifier", identifier).toString())
                main.post { listener.onConnected() }
            }

            override fun onMessage(ws: WebSocket, text: String) {
                handleMessage(text)
            }

            override fun onClosed(ws: WebSocket, code: Int, reason: String) {
                main.post { listener.onDisconnected() }
                scheduleReconnect()
            }

            override fun onFailure(ws: WebSocket, t: Throwable, response: Response?) {
                main.post { listener.onDisconnected() }
                scheduleReconnect()
            }
        })
    }

    private fun handleMessage(text: String) {
        val json = runCatching { JSONObject(text) }.getOrNull() ?: return
        // Action Cable の制御メッセージ（welcome / ping / confirm_subscription）は無視
        if (json.has("type")) return
        val message = json.optJSONObject("message") ?: return
        if (message.optString("type") == "state") {
            main.post { listener.onState(message) }
        }
    }

    private fun scheduleReconnect() {
        socket = null
        if (closedByUser) return
        val delay = retryMs
        retryMs = (retryMs * 2).coerceAtMost(10000L)
        main.postDelayed({ if (!closedByUser) openSocket() }, delay)
    }
}
