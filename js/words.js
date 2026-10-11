// Liste de mots par défaut : un mot par ligne, éventuellement suivi d'un emoji
// (l'emoji est affiché comme « obstacle » sur la piste).
const DEFAULT_WORDS_TEXT = [
  'banane 🍌', 'champignon 🍄', 'étoile ⭐', 'éclair ⚡', 'fusée 🚀',
  'turbo 💨', 'drapeau 🏁', 'coupe 🏆', 'kart 🏎️', 'auto 🚗',
  'moto 🏍️', 'bus 🚌', 'vélo 🚲', 'camion 🚚', 'route 🛣️',
  'pomme 🍎', 'fraise 🍓', 'cerise 🍒', 'citron 🍋', 'tomate 🍅',
  'bonbon 🍬', 'gâteau 🎂', 'glace 🍦', 'chat 🐱', 'chien 🐶',
  'lapin 🐰', 'tortue 🐢', 'renard 🦊', 'poisson 🐟', 'oiseau 🐦',
  'cheval 🐴', 'soleil ☀️', 'lune 🌙', 'nuage ☁️', 'fleur 🌸',
  'arbre 🌳', 'feu 🔥', 'eau 💧', 'ballon 🎈', 'cadeau 🎁',
  'jeu 🎲', 'bravo 👏', 'vite 💨', 'piste 🛣️', 'virage ↪️',
].join('\n');

function parseWordList(text) {
  return String(text || '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [word, ...rest] = line.split(/\s+/);
      return { word, emoji: rest.join(' ') };
    });
}

// Compare une lettre tapée à la lettre attendue.
// Majuscules/minuscules sont toujours acceptées ; les accents sont optionnels.
function normalizeChar(c, accentsTolerant) {
  let s = c.toLowerCase();
  if (accentsTolerant) s = s.normalize('NFD').replace(/[̀-ͯ]/g, '');
  return s;
}
