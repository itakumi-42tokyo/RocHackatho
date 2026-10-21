package com.example.screenjail

import android.annotation.SuppressLint
import android.app.Activity
import android.app.ActivityManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient

/**
 * 全画面のロック画面（Activity 版）。
 * 画面固定（screen pinning / startLockTask）で、ホームとタスク管理ボタンを無効にする。
 * 戻るキーはここで握りつぶす。見た目の中身は Rails のページを WebView で表示するだけ。
 *
 * mode:
 *   "pinning" … 画面固定だけ
 *   "full"    … 画面固定 ＋ 重ね表示（固定を解除しても覆いが残る、一番強いロック）
 * autoReleaseSeconds > 0 なら、その秒数で必ず自動解除する（テスト時に閉じ込められないための安全タイマー）。
 */
class LockActivity : Activity() {

    companion object {
        const val EXTRA_MODE = "mode"
        const val EXTRA_AUTO_RELEASE = "auto_release_seconds"
        const val EXTRA_URL = "url"
        const val MODE_PINNING = "pinning"
        const val MODE_FULL = "full"

        // サービスからロックを解くために、動いている画面への参照を持つ
        @Volatile private var instance: LockActivity? = null
        val isRunning: Boolean get() = instance != null

        fun releaseIfRunning() {
            instance?.let { activity ->
                activity.runOnUiThread { activity.releaseLock() }
            }
        }

        // すでに表示中なら、新しい文言などを反映するためにページを読み直す
        fun reloadIfRunning(url: String) {
            instance?.let { activity ->
                activity.runOnUiThread { activity.loadLock(url) }
            }
        }
    }

    private var webView: WebView? = null

    private val handler = Handler(Looper.getMainLooper())
    private val autoRelease = Runnable { releaseLock() }

    private val lockUrl: String
        get() = intent.getStringExtra(EXTRA_URL)
            ?: (BuildConfig.DEFAULT_SERVER_URL + "/lock_preview?theme=jail")

    private val mode: String
        get() = intent.getStringExtra(EXTRA_MODE) ?: MODE_PINNING

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 画面を常に点灯させ、端末のロック画面より上に出す
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        val wv = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            // 文言などの変更をすぐ反映するため、キャッシュを使わない
            settings.cacheMode = WebSettings.LOAD_NO_CACHE
            // 非ブラウザの UA にすると、ngrok の警告ページを CSS/JS のサブリクエストでも回避できる
            settings.userAgentString = LockOverlay.USER_AGENT
            webViewClient = WebViewClient()
        }
        webView = wv
        setContentView(wv)
        instance = this
        loadLock(lockUrl)

        // 安全タイマー。指定秒後に必ず解除する（既定 30 秒、0 で無効）
        val seconds = intent.getIntExtra(EXTRA_AUTO_RELEASE, 30)
        if (seconds > 0) handler.postDelayed(autoRelease, seconds * 1000L)
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        handler.removeCallbacks(autoRelease)
        super.onDestroy()
    }

    // 無料プランの ngrok が挟む警告ページを飛ばしつつ、ロック画面を読み込む
    private fun loadLock(url: String) {
        webView?.loadUrl(url, mapOf("ngrok-skip-browser-warning" to "1"))
    }

    override fun onResume() {
        super.onResume()
        hideSystemBars()
        startPinning()
        // full モードの重ね表示は LockService が管理する（ここで出すと解除時に競合して黒画面が残るため）
    }

    /** 画面固定を始める。ホームとタスク管理ボタンが無効になる */
    private fun startPinning() {
        // すでに固定中なら何もしない
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val am = getSystemService(ActivityManager::class.java)
            if (am != null && am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE) return
        }
        try {
            startLockTask()
        } catch (_: Exception) {
            // 機種によっては「設定 → セキュリティ → アプリ固定」が必要
        }
    }

    /** ナビゲーションバーとステータスバーを隠す（没入モード） */
    private fun hideSystemBars() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let {
                it.hide(android.view.WindowInsets.Type.systemBars())
                it.systemBarsBehavior =
                    android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                )
        }
    }

    // 戻るキーを無効化する（物理キー・ジェスチャーの両方）
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // 何もしない
    }

    /** ロックを解く（安全タイマー・管理者からの解除・動作確認で呼ぶ） */
    fun releaseLock() {
        handler.removeCallbacks(autoRelease)
        try {
            stopLockTask()
        } catch (_: Exception) {
        }
        LockOverlay.hide(applicationContext, reason = "LockActivity.releaseLock")
        finish()
    }
}
