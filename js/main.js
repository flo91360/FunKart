// Interface : menu, réglages, boucle de jeu, résultats, historique.

const AVATARS = [
  { emoji: '🐱', color: '#ff8c42' }, { emoji: '🐶', color: '#4d96ff' },
  { emoji: '🐸', color: '#6bcb77' }, { emoji: '🦄', color: '#c77dff' },
  { emoji: '🐼', color: '#dee2e6' }, { emoji: '🦁', color: '#ffd166' },
  { emoji: '🐵', color: '#b5835a' }, { emoji: '🐧', color: '#118ab2' },
];
const BOTS = [
  { name: 'Tortue', emoji: '🐢', color: '#2a9d8f' },
  { name: 'Lapin', emoji: '🐰', color: '#e76f51' },
  { name: 'Renard', emoji: '🦊', color: '#f4a261' },
];
const DEFAULT_SETTINGS = {
  playerName: '',
  avatar: 0,
  laps: 2,
  botCount: 3,
  botKpm: [16, 20, 24],
  lapTime: 25,
  wordGap: 2.5,
  slowFactor: 0.4,
  boostFactor: 1.8,
  boostDuration: 2,
  maxWordLength: 8,
  uppercase: false,
  accentsTolerant: true,
  textSize: 'grand',
  speak: false,
  sound: true,
  words: DEFAULT_WORDS_TEXT,
};
const TEXT_SIZES = { normal: 64, grand: 96, 'tres-grand': 132 };
const SETTINGS_KEY = 'funkart.settings';
const HISTORY_KEY = 'funkart.history';

const $ = (sel) => document.querySelector(sel);

// ---------- Stockage ----------
function loadJSON(key, fallback) {
  try {
    const v = JSON.parse(localStorage.getItem(key));
    return v ?? fallback;
  } catch {
    return fallback;
  }
}
function saveJSON(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* stockage indisponible */ }
}

let settings = { ...DEFAULT_SETTINGS, ...loadJSON(SETTINGS_KEY, {}) };
const saveSettings = () => saveJSON(SETTINGS_KEY, settings);

// ---------- Écrans ----------
function showScreen(id) {
  document.querySelectorAll('.screen').forEach((s) => s.classList.toggle('active', s.id === id));
}

// ---------- Menu ----------
function buildMenu() {
  const list = $('#avatar-list');
  list.innerHTML = '';
  AVATARS.forEach((a, i) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.textContent = a.emoji;
    b.style.background = a.color;
    b.classList.toggle('selected', i === settings.avatar);
    b.addEventListener('click', () => {
      settings.avatar = i;
      saveSettings();
      buildMenu();
    });
    list.appendChild(b);
  });
  $('#player-name').value = settings.playerName;
  fillSettingsForm();
  renderHistory();
}

function fillSettingsForm() {
  document.querySelectorAll('[data-setting]').forEach((el) => {
    const v = settings[el.dataset.setting];
    if (el.type === 'checkbox') el.checked = !!v;
    else el.value = v;
  });
  const kpmList = $('#bot-kpm-list');
  kpmList.innerHTML = '';
  BOTS.forEach((b, i) => {
    const label = document.createElement('label');
    label.textContent = `${b.emoji} ${b.name}`;
    const input = document.createElement('input');
    input.type = 'number';
    input.min = 1;
    input.max = 400;
    input.value = settings.botKpm[i];
    input.disabled = i >= settings.botCount;
    input.addEventListener('change', () => {
      settings.botKpm[i] = clampNum(input.value, 1, 400, DEFAULT_SETTINGS.botKpm[i]);
      input.value = settings.botKpm[i];
      saveSettings();
    });
    label.appendChild(input);
    kpmList.appendChild(label);
  });
}

function clampNum(v, min, max, fallback) {
  const n = parseFloat(v);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

function bindSettings() {
  $('#player-name').addEventListener('input', (e) => {
    settings.playerName = e.target.value.trim();
    saveSettings();
  });
  document.querySelectorAll('[data-setting]').forEach((el) => {
    el.addEventListener('change', () => {
      const key = el.dataset.setting;
      if (el.type === 'checkbox') settings[key] = el.checked;
      else if (el.type === 'number') {
        settings[key] = clampNum(el.value, +el.min, +el.max, DEFAULT_SETTINGS[key]);
        el.value = settings[key];
      } else if (typeof DEFAULT_SETTINGS[key] === 'number') settings[key] = parseFloat(el.value);
      else settings[key] = el.value;
      saveSettings();
      if (key === 'botCount') fillSettingsForm();
    });
  });
  $('#bot-preset').addEventListener('change', (e) => {
    const base = parseFloat(e.target.value);
    if (!base) return;
    settings.botKpm = [0.8, 1, 1.2].map((k) => Math.round(base * k));
    saveSettings();
    fillSettingsForm();
    e.target.value = '';
  });
  $('#btn-default-words').addEventListener('click', () => {
    settings.words = DEFAULT_WORDS_TEXT;
    saveSettings();
    fillSettingsForm();
  });
  $('#btn-reset-settings').addEventListener('click', () => {
    if (!confirm('Remettre tous les réglages par défaut ?')) return;
    settings = { ...DEFAULT_SETTINGS, playerName: settings.playerName, avatar: settings.avatar };
    saveSettings();
    buildMenu();
  });
}

// ---------- Historique ----------
function renderHistory() {
  const rows = loadJSON(HISTORY_KEY, []);
  const tbody = $('#history-table tbody');
  tbody.innerHTML = '';
  if (!rows.length) {
    tbody.innerHTML = '<tr><td colspan="8">Aucune course pour le moment.</td></tr>';
    return;
  }
  for (const h of [...rows].reverse()) {
    const tr = document.createElement('tr');
    [
      new Date(h.date).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }),
      h.name, `${h.place}/${h.total}`, Math.round(h.kpm), `${Math.round(h.accuracy * 100)} %`,
      h.words, `${h.avgWordTime.toFixed(1)} s`, h.botKpm.join(' / ') || '—',
    ].forEach((v) => {
      const td = document.createElement('td');
      td.textContent = v;
      tr.appendChild(td);
    });
    tbody.appendChild(tr);
  }
}

function exportHistory() {
  const rows = loadJSON(HISTORY_KEY, []);
  const header = ['date', 'prenom', 'place', 'participants', 'tours', 'frappes_par_minute', 'precision_pct',
    'mots', 'erreurs', 'temps_moyen_par_mot_s', 'temps_course_s', 'adversaires_frappes_par_minute'];
  const lines = rows.map((h) => [
    h.date, h.name, h.place, h.total, h.laps, h.kpm.toFixed(1), (h.accuracy * 100).toFixed(1),
    h.words, h.errors, h.avgWordTime.toFixed(2), h.time.toFixed(1), h.botKpm.join(' / '),
  ].map((v) => `"${String(v).replace(/"/g, '""')}"`).join(';'));
  const blob = new Blob(['﻿' + [header.join(';'), ...lines].join('\n')], { type: 'text/csv' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'funkart-historique.csv';
  a.click();
  URL.revokeObjectURL(a.href);
}

// ---------- Course ----------
const track = new Track();
const renderer = new Renderer($('#canvas'), track);
let race = null;
let paused = false;
let lastFrame = 0;
let hudTimer = 0;

function startRace() {
  if (document.activeElement) document.activeElement.blur(); // évite qu'Entrée/Espace relance la course
  Sound.init();
  Sound.enabled = settings.sound;
  const avatar = AVATARS[settings.avatar] || AVATARS[0];
  const player = { name: settings.playerName || 'Toi', emoji: avatar.emoji, color: avatar.color };
  const bots = BOTS.slice(0, settings.botCount).map((b, i) => ({ ...b, kpm: settings.botKpm[i] }));
  race = new Race(settings, parseWordList(settings.words), player, bots);
  paused = false;
  $('#pause-overlay').hidden = true;
  document.documentElement.style.setProperty('--word-size', `${TEXT_SIZES[settings.textSize] || 96}px`);
  showScreen('screen-game');
  renderer.resize();
  renderer.effects = [];
  showIdleWord();
  showCountdown('3');
  Sound.countdown();
  updateHud();
  lastFrame = performance.now();
}

function loop(ts) {
  const dt = Math.min(0.1, (ts - lastFrame) / 1000);
  lastFrame = ts;
  if (race && $('#screen-game').classList.contains('active')) {
    if (!paused) race.update(dt);
    for (const e of race.drainEvents()) handleEvent(e);
    renderer.draw(race, paused ? 0 : dt);
    hudTimer += dt;
    if (hudTimer > 0.2) {
      hudTimer = 0;
      updateHud();
    }
  }
  requestAnimationFrame(loop);
}

function handleEvent(e) {
  switch (e.type) {
    case 'countdown':
      showCountdown(String(e.n));
      Sound.countdown();
      break;
    case 'go':
      showCountdown('GO !');
      Sound.go();
      setTimeout(() => showCountdown(''), 800);
      break;
    case 'wordStart':
      renderWord();
      setHint('Tape le mot pour avoir un turbo !');
      if (settings.speak) Sound.speak(e.word.word);
      break;
    case 'keyOk':
      renderWord();
      setHint('Tape le mot pour avoir un turbo !');
      Sound.keyOk();
      break;
    case 'keyError': {
      const w = $('#word');
      w.classList.remove('shake');
      void w.offsetWidth; // relance l'animation
      w.classList.add('shake');
      const letter = settings.uppercase ? e.expected.toUpperCase() : e.expected;
      setHint(`Oups ! Cherche la lettre « ${letter} »`, true);
      Sound.keyError();
      break;
    }
    case 'wordComplete': {
      const pos = renderer.obstaclePos(race);
      renderer.addPoof(pos.x, pos.y, e.word.emoji || '🚧');
      Sound.wordComplete();
      renderWord(e.word.word, true);
      setHint('🚀 TURBO !');
      setTimeout(() => {
        if (race && !race.player.word) showIdleWord();
      }, 900);
      break;
    }
    case 'playerFinish':
      Sound.finish();
      showIdleWord('🏁 Arrivée !');
      setTimeout(showResults, 1800);
      break;
  }
}

function showCountdown(text) {
  const el = $('#countdown');
  el.textContent = text;
  el.classList.remove('pop');
  void el.offsetWidth;
  if (text) el.classList.add('pop');
}

function displayLetters(word) {
  const letters = [...word];
  return settings.uppercase ? letters.map((c) => c.toUpperCase()) : letters;
}

// Affiche le mot en cours : lettres tapées en vert, lettre attendue surlignée.
function renderWord(doneWord = null, success = false) {
  const wEl = $('#word');
  const p = race.player;
  const word = doneWord ?? p.word?.word;
  if (!word) return;
  const typed = doneWord ? [...doneWord].length : p.typed;
  wEl.innerHTML = '';
  displayLetters(word).forEach((c, i) => {
    const span = document.createElement('span');
    span.textContent = c;
    span.className = i < typed ? 'done' : i === typed ? 'current' : 'todo';
    wEl.appendChild(span);
  });
  $('#word-emoji').textContent = (doneWord ? '' : p.word?.emoji) || (doneWord ? '✨' : '');
  wEl.classList.remove('success', 'shake');
  if (success) {
    void wEl.offsetWidth;
    wEl.classList.add('success');
  }
}

function showIdleWord(text = '🏎️ Ton kart roule tout seul… prépare tes doigts !') {
  $('#word').innerHTML = '';
  $('#word-emoji').textContent = '';
  setHint(text);
}

function setHint(text, error = false) {
  const h = $('#word-hint');
  h.textContent = text;
  h.classList.toggle('error', error);
}

function updateHud() {
  if (!race) return;
  const n = race.racers.length;
  $('#hud-position').textContent = `${race.playerPosition()}/${n}`;
  $('#hud-lap').textContent = `${race.currentLap()}/${settings.laps}`;
  $('#hud-kpm').textContent = race.stats.correctKeys ? Math.round(race.kpm()) : '–';
  const keys = race.stats.correctKeys + race.stats.errorKeys;
  $('#hud-accuracy').textContent = keys ? `${Math.round(race.accuracy() * 100)} %` : '–';

  const p = race.player;
  const status = $('#hud-status');
  if (race.state === 'running' && p.word) {
    status.textContent = '🐌 Ralenti';
    status.className = 'status slow';
  } else if (race.state === 'running' && p.boost > 0) {
    status.textContent = '🚀 TURBO !';
    status.className = 'status boost';
  } else {
    status.textContent = '';
    status.className = 'status';
  }

  const ol = $('#standings');
  ol.innerHTML = '';
  race.standings().forEach((r, i) => {
    const li = document.createElement('li');
    li.textContent = `${i + 1}. ${r.emoji} ${r.name}`;
    if (r.isPlayer) li.className = 'me';
    ol.appendChild(li);
  });
}

function setPaused(v) {
  if (!race || race.state === 'finished') return;
  paused = v;
  $('#pause-overlay').hidden = !v;
  if (v && 'speechSynthesis' in window) window.speechSynthesis.cancel();
}

function quitRace() {
  race = null;
  paused = false;
  showScreen('screen-menu');
  buildMenu();
}

// ---------- Résultats ----------
function formatTime(s) {
  if (!Number.isFinite(s)) return '—';
  const m = Math.floor(s / 60);
  const sec = (s - m * 60).toFixed(1).padStart(4, '0');
  return `${m}:${sec}`;
}

function showResults() {
  if (!race) return;
  const standings = race.standings();
  const place = standings.indexOf(race.player) + 1;
  const medals = ['🥇', '🥈', '🥉'];
  $('#result-medal').textContent = medals[place - 1] || '🏁';
  const name = settings.playerName ? `, ${settings.playerName}` : '';
  $('#result-title').textContent = place === 1
    ? `Bravo${name}, tu as gagné !`
    : `Bravo${name} ! Tu finis ${place}${place === 1 ? 'er' : 'e'}`;

  const ol = $('#result-ranking');
  ol.innerHTML = '';
  standings.forEach((r, i) => {
    const li = document.createElement('li');
    const t = r.finished ? r.finishTime : r.predictedFinish;
    li.innerHTML = '<span></span><span></span>';
    li.children[0].textContent = `${medals[i] || `${i + 1}.`} ${r.emoji} ${r.name}`;
    li.children[1].textContent = formatTime(t);
    if (r.isPlayer) li.className = 'me';
    ol.appendChild(li);
  });

  const words = race.stats.words;
  const avgWordTime = words.length ? words.reduce((s, w) => s + w.time, 0) / words.length : 0;
  const stats = [
    [Math.round(race.kpm()), 'frappes par minute'],
    [`${Math.round(race.accuracy() * 100)} %`, 'précision'],
    [words.length, 'mots tapés'],
    [`${avgWordTime.toFixed(1)} s`, 'temps moyen par mot'],
    [race.stats.errorKeys, 'erreurs de frappe'],
  ];
  $('#result-stats').innerHTML = '';
  for (const [v, l] of stats) {
    const d = document.createElement('div');
    d.className = 'stat';
    d.innerHTML = '<div class="v"></div><div class="l"></div>';
    d.children[0].textContent = v;
    d.children[1].textContent = l;
    $('#result-stats').appendChild(d);
  }

  const history = loadJSON(HISTORY_KEY, []);
  history.push({
    date: new Date().toISOString(),
    name: settings.playerName || '—',
    place,
    total: standings.length,
    laps: settings.laps,
    kpm: race.kpm(),
    accuracy: race.accuracy(),
    words: words.length,
    errors: race.stats.errorKeys,
    avgWordTime,
    time: race.player.finishTime,
    botKpm: settings.botKpm.slice(0, settings.botCount),
  });
  saveJSON(HISTORY_KEY, history);

  showScreen('screen-results');
}

// ---------- Clavier ----------
document.addEventListener('keydown', (e) => {
  if (!race || !$('#screen-game').classList.contains('active')) return;
  if (e.key === 'Escape') {
    setPaused(!paused);
    return;
  }
  if (paused) return;
  if (e.key === 'Backspace' || e.key === ' ') e.preventDefault();
  // (Ctrl+Alt = AltGr sous Windows : ces caractères sont acceptés)
  if (e.key.length === 1 && !(e.ctrlKey && !e.altKey) && !e.metaKey) {
    e.preventDefault();
    race.handleKey(e.key);
  }
});

window.addEventListener('blur', () => {
  if (race && race.state === 'running') setPaused(true);
});
window.addEventListener('resize', () => {
  if (race) renderer.resize();
});

// ---------- Boutons ----------
$('#btn-play').addEventListener('click', startRace);
$('#btn-replay').addEventListener('click', startRace);
$('#btn-menu').addEventListener('click', quitRace);
$('#btn-pause').addEventListener('click', (e) => {
  setPaused(true);
  e.currentTarget.blur();
});
$('#btn-resume').addEventListener('click', () => setPaused(false));
$('#btn-quit').addEventListener('click', quitRace);
$('#btn-export').addEventListener('click', exportHistory);
$('#btn-clear-history').addEventListener('click', () => {
  if (!confirm("Effacer tout l'historique des courses ?")) return;
  saveJSON(HISTORY_KEY, []);
  renderHistory();
});

bindSettings();
buildMenu();
requestAnimationFrame(loop);
