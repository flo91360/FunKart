// Petits sons synthétisés (aucun fichier audio nécessaire).
const Sound = {
  ctx: null,
  enabled: true,

  init() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (AC) this.ctx = new AC();
    }
    if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume();
  },

  beep(freq, duration = 0.08, type = 'sine', volume = 0.15, delay = 0) {
    if (!this.enabled || !this.ctx) return;
    const t0 = this.ctx.currentTime + delay;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t0);
    gain.gain.setValueAtTime(volume, t0);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + duration);
    osc.connect(gain).connect(this.ctx.destination);
    osc.start(t0);
    osc.stop(t0 + duration + 0.02);
  },

  keyOk() { this.beep(880, 0.05, 'triangle', 0.08); },
  keyError() { this.beep(160, 0.15, 'square', 0.05); },
  countdown() { this.beep(440, 0.2, 'square', 0.1); },
  go() { this.beep(880, 0.4, 'square', 0.12); },
  wordComplete() {
    [523, 659, 784, 1047].forEach((f, i) => this.beep(f, 0.12, 'triangle', 0.12, i * 0.06));
  },
  finish() {
    [523, 523, 523, 659, 784, 659, 784].forEach((f, i) => this.beep(f, 0.18, 'square', 0.08, i * 0.15));
  },

  speak(text) {
    if (!('speechSynthesis' in window)) return;
    window.speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.lang = 'fr-FR';
    u.rate = 0.85;
    window.speechSynthesis.speak(u);
  },
};
