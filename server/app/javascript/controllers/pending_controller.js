import { Controller } from "@hotwired/stimulus"

// 承認待ち件数をタブのタイトルに出し、増えたら短く音を鳴らす。
// バナーは Turbo Stream で丸ごと差し替わるので、件数は要素ごとに connect で読み直す。
const BASE_TITLE = "ScreenJail 管理"

export default class extends Controller {
  static values = { count: Number }

  connect() {
    const n = this.countValue
    document.title = n > 0 ? `(${n}) ${BASE_TITLE}` : BASE_TITLE

    const prev = window.__screenjailPending
    if (typeof prev === "number" && n > prev) this.beep()
    window.__screenjailPending = n
  }

  // 新着時の短い音（WebAudio）。iOS Safari は一度画面を触るまで鳴らないことがある
  beep() {
    try {
      const Ctx = window.AudioContext || window.webkitAudioContext
      if (!Ctx) return
      const ctx = new Ctx()
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.connect(gain)
      gain.connect(ctx.destination)
      osc.type = "sine"
      osc.frequency.value = 880
      gain.gain.value = 0.08
      osc.start()
      setTimeout(() => { osc.stop(); ctx.close() }, 150)
    } catch (e) {
      // 音が出せない環境は黙って無視する
    }
  }
}
