// Logique de course (sans affichage).
//
// Chaque pilote roule en pilote automatique à une vitesse de croisière.
// Régulièrement, un mot apparaît : tant qu'il n'est pas entièrement tapé, le
// kart ralentit ; une fois tapé, le kart reçoit un turbo temporaire.
// Les adversaires suivent exactement les mêmes règles : ils « tapent » leurs
// mots à une vitesse (frappes par minute) réglée par l'adulte.

const LANES = [-0.3, -0.1, 0.1, 0.3]; // décalages latéraux, en largeur de piste

class Race {
  constructor(settings, wordList, playerInfo, botInfos) {
    this.s = settings;
    const maxLen = settings.maxWordLength;
    this.words = wordList.filter((w) => [...w.word].length <= maxLen);
    if (!this.words.length) this.words = wordList.length ? wordList : [{ word: 'kart', emoji: '🏎️' }];
    this.baseSpeed = 1 / settings.lapTime; // tours par seconde
    this.time = 0;
    this.state = 'countdown'; // countdown -> running -> finished
    this.countdown = 3;
    this.events = [];
    this.recentWords = [];
    this.finishedCount = 0;
    this.stats = { correctKeys: 0, errorKeys: 0, activeTime: 0, words: [] };

    // Le joueur part dans le 2e couloir, les adversaires autour.
    const lanes = [1, 0, 2, 3];
    this.player = this.makeRacer({ ...playerInfo, isPlayer: true }, lanes[0]);
    this.racers = [this.player];
    botInfos.forEach((b, i) => this.racers.push(this.makeRacer({ ...b, isPlayer: false }, lanes[i + 1])));
  }

  makeRacer(info, lane) {
    return {
      ...info,
      lane,
      progress: 0,
      mult: 1,
      word: null,
      typed: 0,
      wordElapsed: 0,
      wordDuration: 0,
      wordErrors: 0,
      nextWordIn: 1.5 + (info.isPlayer ? 0 : Math.random() * 0.4),
      boost: 0,
      finished: false,
      finishTime: null,
    };
  }

  emit(type, data = {}) {
    this.events.push({ type, ...data });
  }

  drainEvents() {
    const e = this.events;
    this.events = [];
    return e;
  }

  pickWord(forPlayer) {
    let pool = this.words;
    if (forPlayer && pool.length > 1) {
      // Évite de redonner un des derniers mots à l'enfant.
      const avoid = this.recentWords.slice(-Math.min(5, pool.length - 1));
      pool = pool.filter((w) => !avoid.includes(w.word));
    }
    const w = pool[Math.floor(Math.random() * pool.length)];
    if (forPlayer) this.recentWords.push(w.word);
    return w;
  }

  update(dt) {
    if (this.state === 'countdown') {
      const before = Math.ceil(this.countdown);
      this.countdown -= dt;
      const after = Math.ceil(this.countdown);
      if (after !== before && after > 0) this.emit('countdown', { n: after });
      if (this.countdown <= 0) {
        this.state = 'running';
        this.emit('go');
      }
      return;
    }
    this.time += dt;
    for (const r of this.racers) {
      if (!r.finished) this.updateRacer(r, dt, this.time, true);
    }
  }

  updateRacer(r, dt, now, live) {
    if (!r.word) {
      r.nextWordIn -= dt;
      if (r.nextWordIn <= 0) this.spawnWord(r, live);
    } else {
      r.wordElapsed += dt;
      if (r.isPlayer && live) this.stats.activeTime += dt;
      if (!r.isPlayer && r.wordElapsed >= r.wordDuration) this.completeWord(r, live);
    }
    if (r.boost > 0) r.boost = Math.max(0, r.boost - dt);

    const target = r.word ? this.s.slowFactor : (r.boost > 0 ? this.s.boostFactor : 1);
    const rate = target > r.mult ? 4 : 3;
    r.mult += (target - r.mult) * Math.min(1, rate * dt);
    r.progress += this.baseSpeed * r.mult * dt;

    if (r.progress >= this.s.laps) {
      r.progress = this.s.laps;
      r.finished = true;
      r.finishTime = now;
      r.word = null;
      if (live) {
        this.finishedCount++;
        r.place = this.finishedCount;
        if (r.isPlayer) this.onPlayerFinish();
      }
    }
  }

  spawnWord(r, live) {
    r.word = this.pickWord(r.isPlayer);
    r.typed = 0;
    r.wordElapsed = 0;
    r.wordErrors = 0;
    if (!r.isPlayer) {
      // Temps de frappe simulé avec un peu de variabilité (±20 %).
      const chars = [...r.word.word].length;
      r.wordDuration = (chars * 60) / r.kpm * (0.8 + Math.random() * 0.4);
    } else if (live) {
      this.emit('wordStart', { word: r.word });
    }
  }

  completeWord(r, live) {
    if (r.isPlayer && live) {
      this.stats.words.push({ word: r.word.word, time: r.wordElapsed, errors: r.wordErrors });
      this.emit('wordComplete', { word: r.word });
    }
    r.word = null;
    r.boost = this.s.boostDuration;
    r.nextWordIn = this.s.wordGap + (r.isPlayer ? 0 : (Math.random() - 0.5) * 0.6);
  }

  // Touche tapée par l'enfant.
  handleKey(key) {
    const p = this.player;
    if (this.state !== 'running' || p.finished || !p.word) return;
    const letters = [...p.word.word];
    const expected = letters[p.typed];
    const tol = this.s.accentsTolerant;
    if (normalizeChar(key, tol) === normalizeChar(expected, tol)) {
      p.typed++;
      this.stats.correctKeys++;
      this.emit('keyOk', { typed: p.typed });
      if (p.typed >= letters.length) this.completeWord(p, true);
    } else {
      this.stats.errorKeys++;
      p.wordErrors++;
      this.emit('keyError', { key, expected });
    }
  }

  onPlayerFinish() {
    this.state = 'finished';
    // On prédit l'heure d'arrivée des adversaires encore en course en
    // simulant une copie de chacun jusqu'à la ligne.
    for (const r of this.racers) {
      if (r.finished) continue;
      const clone = { ...r };
      let t = this.time;
      for (let i = 0; i < 200000 && !clone.finished; i++) {
        t += 0.05;
        this.updateRacer(clone, 0.05, t, false);
      }
      r.predictedFinish = clone.finishTime ?? Infinity;
    }
    this.emit('playerFinish');
  }

  // Classement : arrivés (par temps) puis en course (par progression).
  standings() {
    const finishOf = (r) => (r.finished ? r.finishTime : r.predictedFinish);
    return [...this.racers].sort((a, b) => {
      if (this.state === 'finished') return (finishOf(a) ?? Infinity) - (finishOf(b) ?? Infinity);
      if (a.finished && b.finished) return a.finishTime - b.finishTime;
      if (a.finished) return -1;
      if (b.finished) return 1;
      return b.progress - a.progress;
    });
  }

  playerPosition() {
    return this.standings().indexOf(this.player) + 1;
  }

  currentLap(r = this.player) {
    return Math.min(this.s.laps, Math.floor(r.progress) + 1);
  }

  kpm() {
    const minutes = this.stats.activeTime / 60;
    return minutes > 0 ? this.stats.correctKeys / minutes : 0;
  }

  accuracy() {
    const total = this.stats.correctKeys + this.stats.errorKeys;
    return total ? this.stats.correctKeys / total : 1;
  }
}
