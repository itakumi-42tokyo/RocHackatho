import { Controller } from "@hotwired/stimulus"

// 承認待ち件数をタブのタイトルに出し、件数が増えたら短く音を鳴らす。
// 管理画面は morph リフレッシュで更新されるため、要素は保持されたまま
// data-pending-count-value だけが変わる。connect と countValueChanged の両方で反映する。
const BASE_TITLE = "ScreenJail 管理"

export default class extends Controller {
  static values = { count: Number }

  connect() { this.apply() }
  countValueChanged() { this.apply() }

  apply() {
    const n = this.countValue
    document.title = n > 0 ? `(${n}) ${BASE_TITLE}` : BASE_TITLE

    const prev = window.__screenjailPending
    if (typeof prev === "number" && n > prev) this.beep() // 増えたときだけ鳴らす
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
