package com.example.screenjail

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * アプリの入口画面。
 * まだサーバーにはつながない。手元でロック画面の表示・非表示だけを試すための最小の画面。
 * 見た目の本体は Rails のページ。ここは LockOverlay を呼び出すだけ。
 */
class MainActivity : Activity() {

    private val previewUrl =
        BuildConfig.DEFAULT_SERVER_URL + "/lock_preview?theme=jail"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val hint = TextView(this).apply {
            text = "ステップ1: 表示の確認\n下のボタンで動きを試せます。"
            textSize = 16f
            setPadding(0, 0, 0, 40)
        }

        val grantButton = Button(this).apply {
            text = "重ね表示を許可する"
            setOnClickListener { openOverlaySettings() }
        }

        val showButton = Button(this).apply {
            text = "ロック画面を表示"
            setOnClickListener { LockOverlay.show(this@MainActivity, previewUrl, 100) }
        }

        val hideButton = Button(this).apply {
            text = "ロック画面を閉じる"
            setOnClickListener { LockOverlay.hide(this@MainActivity) }
        }

        val pinnedButton = Button(this).apply {
            text = "画面固定ロック（ホーム・タスク管理を無効）"
            setOnClickListener { startLock(LockActivity.MODE_PINNING) }
        }

        val fullButton = Button(this).apply {
            text = "最強ロック（画面固定＋重ね表示）"
            setOnClickListener { startLock(LockActivity.MODE_FULL) }
        }

        val pinnedHint = TextView(this).apply {
            text = "どちらも 30 秒で自動解除します（テスト用）。\n" +
                "手動解除は「戻る」と「タスク管理」を同時に長押し。\n" +
                "固定が効かないときは 設定→セキュリティ→アプリ固定 を ON に。"
            textSize = 13f
            setPadding(0, 16, 0, 0)
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 96, 48, 48)
            addView(hint)
            addView(grantButton)
            addView(showButton)
            addView(hideButton)
            addView(pinnedButton)
            addView(fullButton)
            addView(pinnedHint)
        }

        setContentView(layout)
    }

    private fun startLock(mode: String) {
        val intent = Intent(this, LockActivity::class.java).apply {
            putExtra(LockActivity.EXTRA_MODE, mode)
            putExtra(LockActivity.EXTRA_AUTO_RELEASE, 30)
        }
        startActivity(intent)
    }

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        startActivity(intent)
    }
}
