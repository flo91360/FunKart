// Circuit : courbe fermée (spline de Catmull-Rom) paramétrée par la distance.
// Coordonnées « design » : x dans [0, aspect], y dans [0, 1].
const TRACK_POINTS = [
  [0.10, 0.55], [0.12, 0.25], [0.28, 0.12], [0.45, 0.22], [0.55, 0.40],
  [0.68, 0.20], [0.85, 0.15], [0.92, 0.40], [0.85, 0.70], [0.70, 0.85],
  [0.45, 0.88], [0.25, 0.85], [0.12, 0.75],
];

class Track {
  constructor(points = TRACK_POINTS, aspect = 1.6, width = 0.12) {
    this.aspect = aspect;
    this.width = width;
    const P = points.map(([x, y]) => [x * aspect, y]);
    const n = P.length;
    const steps = 40;
    this.samples = [];
    for (let i = 0; i < n; i++) {
      const p0 = P[(i - 1 + n) % n], p1 = P[i], p2 = P[(i + 1) % n], p3 = P[(i + 2) % n];
      for (let s = 0; s < steps; s++) {
        const t = s / steps, t2 = t * t, t3 = t2 * t;
        const c = (k) => 0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t
          + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
          + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3);
        this.samples.push({ x: c(0), y: c(1) });
      }
    }
    const N = this.samples.length;
    this.cum = [0];
    for (let i = 1; i < N; i++) this.cum[i] = this.cum[i - 1] + dist(this.samples[i - 1], this.samples[i]);
    this.total = this.cum[N - 1] + dist(this.samples[N - 1], this.samples[0]);
  }

  // u : progression en tours (la partie entière est ignorée).
  // lateral : décalage perpendiculaire à la piste (couloirs).
  at(u, lateral = 0) {
    u -= Math.floor(u);
    const d = u * this.total;
    const N = this.samples.length;
    let lo = 0, hi = N - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (this.cum[mid] <= d) lo = mid; else hi = mid - 1;
    }
    const a = this.samples[lo], b = this.samples[(lo + 1) % N];
    const segEnd = lo + 1 < N ? this.cum[lo + 1] : this.total;
    const t = (d - this.cum[lo]) / (segEnd - this.cum[lo] || 1);
    const angle = Math.atan2(b.y - a.y, b.x - a.x);
    return {
      x: a.x + (b.x - a.x) * t - Math.sin(angle) * lateral,
      y: a.y + (b.y - a.y) * t + Math.cos(angle) * lateral,
      angle,
    };
  }

  distanceTo(x, y) {
    let best = Infinity;
    for (const s of this.samples) best = Math.min(best, Math.hypot(s.x - x, s.y - y));
    return best;
  }
}

function dist(a, b) {
  return Math.hypot(b.x - a.x, b.y - a.y);
}
