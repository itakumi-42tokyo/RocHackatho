package com.example.screenjail

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/**
 * アプリの入口画面。
 * サーバーに参加（登録）してサービスを開始するほか、手元でロック画面の表示を試すボタンも置く。
 * ロック画面の見た目の本体は Rails のページ。ここはそれを呼び出すだけ。
 */
class MainActivity : Activity() {

    private lateinit var prefs: android.content.SharedPreferences
    private lateinit var status: TextView
    private lateinit var serverUrlField: EditText
    private lateinit var nameField: EditText

    private val previewUrl get() = BuildConfig.DEFAULT_SERVER_URL + "/lock_preview?theme=jail"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = getSharedPreferences(Prefs.NAME, MODE_PRIVATE)
        requestNotificationPermission()

        status = TextView(this).apply { textSize = 14f; setPadding(0, 0, 0, 24) }

        serverUrlField = EditText(this).apply {
            inputType = InputType.TYPE_TEXT_VARIATION_URI
            setText(prefs.getString(Prefs.SERVER_URL, BuildConfig.DEFAULT_SERVER_URL))
        }
        nameField = EditText(this).apply {
            hint = "あなたの名前"
            setText(prefs.getString(Prefs.DEVICE_NAME, ""))
        }

        val joinButton = Button(this).apply {
            text = "サーバーに参加する"
            setOnClickListener { join() }
        }

        val resetButton = Button(this).apply {
            text = "参加をやり直す（新しい端末として登録）"
            setOnClickListener {
                prefs.edit().remove(Prefs.TOKEN).apply()
                join()
            }
        }

        val grantButton = Button(this).apply {
            text = "重ね表示を許可する（最初に 1 回）"
            setOnClickListener { openOverlaySettings() }
        }

        val sectionTest = TextView(this).apply {
            text = "── 手元で表示だけ試す ──"
            setPadding(0, 40, 0, 8)
        }
        val showButton = Button(this).apply {
            text = "ロック画面を表示"
            setOnClickListener { LockOverlay.show(this@MainActivity, previewUrl, 100) }
        }
        val hideButton = Button(this).apply {
            text = "ロック画面を閉じる"
            setOnClickListener { LockOverlay.hide(this@MainActivity) }
        }
        val fullButton = Button(this).apply {
            text = "最強ロックを試す（30 秒で自動解除）"
            setOnClickListener { startTestLock(LockActivity.MODE_FULL) }
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 96, 48, 48)
            addView(status)
            addView(grantButton)
            addView(serverUrlField)
            addView(nameField)
            addView(joinButton)
            addView(resetButton)
            addView(sectionTest)
            addView(showButton)
            addView(hideButton)
            addView(fullButton)
        }
        setContentView(layout)
        updateStatus()
    }

    private fun join() {
        val baseUrl = serverUrlField.text.toString().trim().ifBlank { BuildConfig.DEFAULT_SERVER_URL }
        val name = nameField.text.toString().trim().ifBlank { "名無し端末" }
        prefs.edit().putString(Prefs.SERVER_URL, baseUrl).putString(Prefs.DEVICE_NAME, name).apply()

        // すでに参加済みなら登録し直さない（重複登録を防ぐ）。接続だけ始める
        if (!prefs.getString(Prefs.TOKEN, null).isNullOrBlank()) {
            LockService.start(this)
            updateStatus()
            Toast.makeText(this, "接続しました（登録済み）", Toast.LENGTH_SHORT).show()
            return
        }

        status.text = "登録中…"
        DeviceRegistrar.register(baseUrl, name) { token, error ->
            if (token != null) {
                prefs.edit().putString(Prefs.TOKEN, token).apply()
                LockService.start(this)
                updateStatus()
                Toast.makeText(this, "参加しました", Toast.LENGTH_SHORT).show()
            } else {
                status.text = "参加に失敗: $error"
            }
        }
    }

    private fun updateStatus() {
        val joined = !prefs.getString(Prefs.TOKEN, null).isNullOrBlank()
        status.text = if (joined) "参加済み。管理者の操作を待っています。" else "未参加です。"
    }

    private fun startTestLock(mode: String) {
        val intent = Intent(this, LockActivity::class.java).apply {
            putExtra(LockActivity.EXTRA_MODE, mode)
            putExtra(LockActivity.EXTRA_AUTO_RELEASE, 30)
        }
        startActivity(intent)
    }

    private fun openOverlaySettings() {
        startActivity(
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
        )
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }
}
