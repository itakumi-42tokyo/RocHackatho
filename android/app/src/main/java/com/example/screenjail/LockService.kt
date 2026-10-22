package com.example.screenjail

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import org.json.JSONObject

/**
 * サーバーとの接続を保ち続けるフォアグラウンドサービス。
 * ハートビートを送り、届いた状態（locked / mode / opacity）に合わせてロック画面を出し入れする。
 */
class LockService : Service(), CableClient.Listener {

    companion object {
        private const val CHANNEL_ID = "screenjail_service"
        private const val NOTE_ID = 1
        private const val HEARTBEAT_MS = 30_000L // 30 秒。電池と通信量を抑える（サーバーの死活しきい値もこれに合わせてある）
        private const val SAFETY_AUTO_RELEASE = 180 // 通信断でも最後は戻れるようにする保険（秒）
        private const val TAG = "LockService"

        fun start(context: Context) {
            val intent = Intent(context, LockService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent)
            else context.startService(intent)
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private var cable: CableClient? = null
    private var currentToken: String? = null
    private var currentlyLocked = false

    private val heartbeat = object : Runnable {
        override fun run() {
            cable?.sendHeartbeat()
            cable?.reportOverlay(LockOverlay.isShown || currentlyLocked)
            main.postDelayed(this, HEARTBEAT_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTE_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = getSharedPreferences(Prefs.NAME, MODE_PRIVATE)
        val baseUrl = prefs.getString(Prefs.SERVER_URL, BuildConfig.DEFAULT_SERVER_URL)!!
        val token = prefs.getString(Prefs.TOKEN, null)

        if (token.isNullOrBlank()) {
            stopSelf()
            return START_NOT_STICKY
        }

        // 未接続、またはトークンが変わった（参加し直した）ら、つなぎ直す
        if (cable == null || token != currentToken) {
            cable?.disconnect()
            main.removeCallbacks(heartbeat)
            currentToken = token
            cable = CableClient(baseUrl, token, this).also { it.connect() }
            main.postDelayed(heartbeat, HEARTBEAT_MS)
        }
        return START_STICKY
    }

    // ---- CableClient.Listener ----

    override fun onState(state: JSONObject) {
        val baseUrl = getSharedPreferences(Prefs.NAME, MODE_PRIVATE)
            .getString(Prefs.SERVER_URL, BuildConfig.DEFAULT_SERVER_URL)!!
        val locked = state.optBoolean("locked", false)
        val mode = state.optString("mode", "full")
        val opacity = state.optInt("opacity", 100)
        val lockUrl = baseUrl.trimEnd('/') + state.optString("lock_path", "/lock")

        android.util.Log.d(TAG, "onState locked=$locked mode=$mode opacity=$opacity")
        currentlyLocked = locked
        if (locked) applyLock(mode, opacity, lockUrl) else releaseLock()
    }

    override fun onConnected() {}
    override fun onDisconnected() {}

    // ---- ロックの適用 ----

    private fun applyLock(mode: String, opacity: Int, lockUrl: String) {
        android.util.Log.d(TAG, "applyLock mode=$mode opacity=$opacity")
        when (mode) {
            "overlay" -> {
                LockActivity.releaseIfRunning()
                LockOverlay.show(this, lockUrl, opacity, reason = "state:locked/overlay")
            }
            "pinning" -> {
                LockOverlay.hide(this, reason = "state:locked/pinning")
                launchLockActivity(LockActivity.MODE_PINNING, lockUrl)
            }
            else -> { // full: 画面固定（ホーム・タスク管理を無効）＋ 重ね表示（固定を解いても覆いが残る）
                launchLockActivity(LockActivity.MODE_FULL, lockUrl)
                LockOverlay.show(this, lockUrl, opacity, reason = "state:locked/full")
            }
        }
    }

    private fun releaseLock() {
        android.util.Log.d(TAG, "releaseLock (state:unlocked)")
        LockActivity.releaseIfRunning()
        LockOverlay.hide(this, reason = "state:unlocked")
    }

    private fun launchLockActivity(mode: String, lockUrl: String) {
        if (LockActivity.isRunning) {
            // すでに表示中なら、新しい文言などを反映するため読み直すだけ
            LockActivity.reloadIfRunning(lockUrl)
            return
        }
        val intent = Intent(this, LockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra(LockActivity.EXTRA_MODE, mode)
            putExtra(LockActivity.EXTRA_AUTO_RELEASE, SAFETY_AUTO_RELEASE)
            putExtra(LockActivity.EXTRA_URL, lockUrl)
        }
        startActivity(intent)
    }

    override fun onDestroy() {
        main.removeCallbacks(heartbeat)
        cable?.disconnect()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): android.app.Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "ScreenJail", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ScreenJail")
            .setContentText("サーバーに接続中")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()
    }
}
