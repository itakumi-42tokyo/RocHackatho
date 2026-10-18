package com.example.screenjail

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.KeyEvent
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout

/**
 * 全画面のロック画面（他のアプリの上に重ねるウィンドウ）。
 * 見た目は Rails が描画したページを WebView で表示するだけ。ネイティブ側は「覆う」「戻るを無効にする」「不透明度」だけを受け持つ。
 */
object LockOverlay {
    private var root: FrameLayout? = null
    private var webView: WebView? = null
    private var params: WindowManager.LayoutParams? = null

    private val handler = Handler(Looper.getMainLooper())
    private val autoHide = Runnable { appContext?.let { hide(it) } }
    private var appContext: Context? = null

    val isShown: Boolean
        get() = root != null

    fun canDraw(context: Context): Boolean = Settings.canDrawOverlays(context)

    /**
     * ロック画面を表示する。すでに表示中なら URL と不透明度だけ更新する。
     * autoHideSeconds > 0 なら、その秒数で自動的に消える（テスト時の安全タイマー。0 で無効）。
     */
    @SuppressLint("SetJavaScriptEnabled")
    fun show(context: Context, url: String, opacityPercent: Int, autoHideSeconds: Int = 0) {
        if (!canDraw(context)) return
        appContext = context.applicationContext
        scheduleAutoHide(autoHideSeconds)
        if (root != null) {
            load(url)
            setOpacity(context, opacityPercent)
            return
        }

        val app = context.applicationContext
        val container = object : FrameLayout(app) {
            // 戻るキー（ジェスチャーの「戻る」も含む）を握りつぶす
            override fun dispatchKeyEvent(event: KeyEvent): Boolean {
                if (event.keyCode == KeyEvent.KEYCODE_BACK) return true
                return super.dispatchKeyEvent(event)
            }
        }
        val wv = WebView(app).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            // 文言などの変更をすぐ反映するため、キャッシュを使わない
            settings.cacheMode = android.webkit.WebSettings.LOAD_NO_CACHE
            webViewClient = WebViewClient()
            setBackgroundColor(Color.BLACK)
        }
        container.addView(wv, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            // FLAG_NOT_FOCUSABLE と FLAG_NOT_TOUCHABLE は付けない: キーとタッチをすべてこのウィンドウで受け取る
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            alpha = opacityPercent.coerceIn(0, 100) / 100f
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }

        windowManager(app).addView(container, lp)
        root = container
        webView = wv
        params = lp
        load(url)
    }

    fun hide(context: Context) {
        handler.removeCallbacks(autoHide)
        val view = root ?: return
        windowManager(context.applicationContext).removeView(view)
        webView?.destroy()
        root = null
        webView = null
        params = null
    }

    /** テスト時の安全タイマー。指定秒後に自動で消す。0 以下なら設定しない */
    private fun scheduleAutoHide(seconds: Int) {
        handler.removeCallbacks(autoHide)
        if (seconds > 0) handler.postDelayed(autoHide, seconds * 1000L)
    }

    fun setOpacity(context: Context, opacityPercent: Int) {
        val view = root ?: return
        val lp = params ?: return
        lp.alpha = opacityPercent.coerceIn(0, 100) / 100f
        windowManager(context.applicationContext).updateViewLayout(view, lp)
    }

    private fun load(url: String) {
        val wv = webView ?: return
        // 文言などが変わることがあるので、同じ URL でも読み直す
        // 無料プランの ngrok が挟む警告ページを飛ばす
        wv.loadUrl(url, mapOf("ngrok-skip-browser-warning" to "1"))
    }

    private fun windowManager(context: Context): WindowManager =
        context.getSystemService(WindowManager::class.java)
}
