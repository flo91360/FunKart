// Dessin du circuit et des karts (vue de dessus, sur un <canvas>).

class Renderer {
  constructor(canvas, track) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.track = track;
    this.bg = document.createElement('canvas');
    this.effects = [];
    this.trees = this.makeTrees();
  }

  resize() {
    const rect = this.canvas.parentElement.getBoundingClientRect();
    this.dpr = window.devicePixelRatio || 1;
    this.cw = Math.max(1, rect.width);
    this.ch = Math.max(1, rect.height);
    for (const c of [this.canvas, this.bg]) {
      c.width = Math.round(this.cw * this.dpr);
      c.height = Math.round(this.ch * this.dpr);
    }
    this.canvas.style.width = this.cw + 'px';
    this.canvas.style.height = this.ch + 'px';
    const margin = 16;
    this.scale = Math.min((this.cw - 2 * margin) / this.track.aspect, this.ch - 2 * margin);
    this.ox = (this.cw - this.track.aspect * this.scale) / 2;
    this.oy = (this.ch - this.scale) / 2;
    this.drawBackground();
  }

  sx(x) { return this.ox + x * this.scale; }
  sy(y) { return this.oy + y * this.scale; }

  makeTrees() {
    // Générateur pseudo-aléatoire déterministe : le décor est toujours le même.
    let seed = 42;
    const rand = () => {
      seed = (seed * 1664525 + 1013904223) % 4294967296;
      return seed / 4294967296;
    };
    const trees = [];
    const minDist = this.track.width * 0.95;
    for (let i = 0; i < 400 && trees.length < 70; i++) {
      const x = -0.4 + rand() * (this.track.aspect + 0.8);
      const y = -0.3 + rand() * 1.6;
      if (this.track.distanceTo(x, y) < minDist) continue;
      if (trees.some((t) => Math.hypot(t.x - x, t.y - y) < 0.07)) continue;
      trees.push({ x, y, emoji: rand() < 0.75 ? '🌳' : (rand() < 0.5 ? '🌲' : '🌼') });
    }
    return trees;
  }

  drawBackground() {
    const ctx = this.bg.getContext('2d');
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    const W = this.track.width * this.scale;

    // Herbe à bandes
    ctx.fillStyle = '#6cc04a';
    ctx.fillRect(0, 0, this.cw, this.ch);
    ctx.fillStyle = '#64b443';
    const band = Math.max(20, this.scale * 0.08);
    for (let x = -this.ch; x < this.cw; x += band * 2) {
      ctx.beginPath();
      ctx.moveTo(x, 0); ctx.lineTo(x + band, 0);
      ctx.lineTo(x + band + this.ch, this.ch); ctx.lineTo(x + this.ch, this.ch);
      ctx.fill();
    }

    // Piste
    const path = new Path2D();
    this.track.samples.forEach((p, i) => {
      if (i === 0) path.moveTo(this.sx(p.x), this.sy(p.y));
      else path.lineTo(this.sx(p.x), this.sy(p.y));
    });
    path.closePath();
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';

    ctx.strokeStyle = 'rgba(0,0,0,0.18)';
    ctx.lineWidth = W * 1.35;
    ctx.save(); ctx.translate(3, 4); ctx.stroke(path); ctx.restore();

    ctx.lineWidth = W * 1.22;
    ctx.strokeStyle = '#e63946';
    ctx.stroke(path);
    ctx.setLineDash([W * 0.3, W * 0.3]);
    ctx.strokeStyle = '#ffffff';
    ctx.stroke(path);
    ctx.setLineDash([]);

    ctx.lineWidth = W;
    ctx.strokeStyle = '#5b6068';
    ctx.stroke(path);

    ctx.lineWidth = Math.max(1.5, W * 0.03);
    ctx.setLineDash([W * 0.25, W * 0.35]);
    ctx.strokeStyle = 'rgba(255,255,255,0.45)';
    ctx.stroke(path);
    ctx.setLineDash([]);

    // Ligne de départ / arrivée en damier
    const start = this.track.at(0);
    ctx.save();
    ctx.translate(this.sx(start.x), this.sy(start.y));
    ctx.rotate(start.angle);
    const cols = 8;
    const sq = W / cols;
    for (let row = 0; row < 2; row++) {
      for (let c = 0; c < cols; c++) {
        ctx.fillStyle = (row + c) % 2 ? '#111' : '#fff';
        ctx.fillRect(row * sq - sq, -W / 2 + c * sq, sq, sq);
      }
    }
    ctx.restore();

    // Décor
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = `${Math.round(this.scale * 0.055)}px serif`;
    for (const t of this.trees) ctx.fillText(t.emoji, this.sx(t.x), this.sy(t.y));
  }

  addPoof(x, y, emoji) {
    this.effects.push({ x, y, emoji, t: 0 });
  }

  draw(race, dt) {
    const ctx = this.ctx;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.drawImage(this.bg, 0, 0);
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    const W = this.track.width;
    const now = performance.now() / 1000;

    // Obstacle devant le kart du joueur pendant qu'un mot est affiché
    const p = race.player;
    if (p.word && !p.finished) {
      const pos = this.track.at(p.progress + 0.035, LANES[p.lane] * W);
      const bob = Math.sin(now * 5) * this.scale * 0.006;
      ctx.font = `${Math.round(this.scale * W * 0.55)}px serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(p.word.emoji || '🚧', this.sx(pos.x), this.sy(pos.y) + bob);
    }

    // Karts (le joueur dessiné en dernier, par-dessus)
    const order = [...race.racers].sort((a, b) => (a.isPlayer ? 1 : 0) - (b.isPlayer ? 1 : 0));
    for (const r of order) this.drawKart(r, now);

    // Effets « pouf » quand un mot est réussi
    for (const e of this.effects) {
      e.t += dt;
      const k = e.t / 0.8;
      ctx.globalAlpha = Math.max(0, 1 - k);
      ctx.strokeStyle = '#ffd60a';
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(this.sx(e.x), this.sy(e.y), this.scale * W * (0.2 + k * 0.6), 0, Math.PI * 2);
      ctx.stroke();
      ctx.font = `${Math.round(this.scale * W * 0.55)}px serif`;
      ctx.fillText(e.emoji, this.sx(e.x), this.sy(e.y) - k * this.scale * 0.08);
      ctx.globalAlpha = 1;
    }
    this.effects = this.effects.filter((e) => e.t < 0.8);
  }

  drawKart(r, now) {
    const ctx = this.ctx;
    const W = this.track.width;
    const pos = this.track.at(r.progress, LANES[r.lane] * W);
    const x = this.sx(pos.x), y = this.sy(pos.y);
    const L = this.scale * W * 0.42;
    const Wd = this.scale * W * 0.26;
    const boosting = r.boost > 0 && !r.word && !r.finished;

    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(pos.angle);
    if (boosting) {
      const flick = 0.7 + Math.random() * 0.5;
      ctx.fillStyle = '#ff9f1c';
      ctx.beginPath();
      ctx.moveTo(-L / 2, -Wd * 0.35);
      ctx.lineTo(-L / 2 - L * 0.7 * flick, 0);
      ctx.lineTo(-L / 2, Wd * 0.35);
      ctx.fill();
      ctx.fillStyle = '#ffe066';
      ctx.beginPath();
      ctx.moveTo(-L / 2, -Wd * 0.18);
      ctx.lineTo(-L / 2 - L * 0.4 * flick, 0);
      ctx.lineTo(-L / 2, Wd * 0.18);
      ctx.fill();
    }
    ctx.fillStyle = '#222';
    for (const wx of [-L * 0.3, L * 0.3]) {
      for (const wy of [-Wd * 0.55, Wd * 0.55]) {
        ctx.fillRect(wx - L * 0.11, wy - Wd * 0.13, L * 0.22, Wd * 0.26);
      }
    }
    roundRect(ctx, -L / 2, -Wd / 2, L, Wd, Wd * 0.3);
    ctx.fillStyle = r.color;
    ctx.fill();
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = 'rgba(0,0,0,0.5)';
    ctx.stroke();
    ctx.restore();

    if (r.isPlayer) {
      ctx.beginPath();
      ctx.arc(x, y, L * 0.85, 0, Math.PI * 2);
      ctx.strokeStyle = '#ffd60a';
      ctx.lineWidth = 3;
      ctx.stroke();
    }

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = `${Math.round(Wd * 1.3)}px serif`;
    ctx.fillText(r.emoji, x, y - Wd * 0.2);

    if (r.isPlayer) {
      const label = 'TOI';
      ctx.font = `bold ${Math.max(12, Math.round(Wd * 0.8))}px system-ui, sans-serif`;
      const ly = y - L * 1.25 + Math.sin(now * 4) * 2;
      ctx.lineWidth = 4;
      ctx.strokeStyle = '#000';
      ctx.strokeText(label, x, ly);
      ctx.fillStyle = '#ffd60a';
      ctx.fillText(label, x, ly);
    }
  }

  // Position écran de l'obstacle du joueur (pour l'effet « pouf »).
  obstaclePos(race) {
    const p = race.player;
    const pos = this.track.at(p.progress + 0.035, LANES[p.lane] * this.track.width);
    return { x: pos.x, y: pos.y };
  }
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
