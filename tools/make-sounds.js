/*
 * Звуки игры — синтезируются здесь, а не скачиваются.
 *
 * Свои звуки, а не чужие: ни лицензий, ни ссылок, которые однажды пропадут, и все звучат
 * одной рукой — мягко, «под водой», без резких пиков. Скрипт детерминированный (одно зерно —
 * одни и те же файлы). Новые звуки дописывать в конец: иначе поменяются прежние.
 *
 *   node tools/make-sounds.js
 *
 * Пишет WAV (моно, 22 050 Гц, 16 бит) в sounds/.
 */
const fs = require("fs");
const path = require("path");

const RATE = 22050;
const OUT = path.join(__dirname, "..", "sounds");

// --- основа ---------------------------------------------------------------------------

let seed = 20260924;
const rnd = () => {
  seed ^= seed << 13;
  seed >>>= 0;
  seed ^= seed >> 17;
  seed ^= seed << 5;
  seed >>>= 0;
  return seed / 4294967296;
};
const noise = () => rnd() * 2 - 1;
const buf = (sec) => new Float32Array(Math.round(sec * RATE));
const TAU = Math.PI * 2;

/** Огибающая: быстрая атака, экспоненциальное затухание. */
const env = (t, attack, decay) => (t < attack ? t / attack : Math.exp(-(t - attack) / decay));

/** Однополюсный фильтр нижних частот — делает шум мягче. */
function lowpass(x, cutoff) {
  const a = Math.exp((-TAU * cutoff) / RATE);
  let y = 0;
  for (let i = 0; i < x.length; i++) x[i] = y = (1 - a) * x[i] + a * y;
  return x;
}
function highpass(x, cutoff) {
  const low = lowpass(Float32Array.from(x), cutoff);
  for (let i = 0; i < x.length; i++) x[i] -= low[i];
  return x;
}
const bandpass = (x, lo, hi) => lowpass(highpass(x, lo), hi);

/** Сложить src в dst, начиная с секунды at, с громкостью gain. */
function mix(dst, src, at = 0, gain = 1) {
  const o = Math.round(at * RATE);
  for (let i = 0; i < src.length && o + i < dst.length; i++) dst[o + i] += src[i] * gain;
  return dst;
}

/** Нота: синус с парой обертонов и своей огибающей. */
function tone(freq, sec, { attack = 0.004, decay = 0.15, harmonics = [1, 0.3, 0.1], glide = 0 } = {}) {
  const x = buf(sec);
  let phase = 0;
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE;
    const f = freq * (1 + glide * t);
    phase += (TAU * f) / RATE;
    let v = 0;
    harmonics.forEach((h, k) => (v += h * Math.sin(phase * (k + 1))));
    x[i] = v * env(t, attack, decay);
  }
  return x;
}

/** Шумовой щелчок/шорох с огибающей. */
function burst(sec, { attack = 0.002, decay = 0.03, lo = 200, hi = 4000 } = {}) {
  const x = buf(sec);
  for (let i = 0; i < x.length; i++) x[i] = noise() * env(i / RATE, attack, decay);
  return bandpass(x, lo, hi);
}

/** Довести пик до уровня и сгладить края, чтобы не щёлкало. */
function finish(x, peak = 0.7) {
  let max = 0;
  for (const v of x) max = Math.max(max, Math.abs(v));
  const g = max > 0 ? peak / max : 1;
  const fade = Math.min(x.length / 4, Math.round(0.004 * RATE));
  for (let i = 0; i < x.length; i++) {
    x[i] *= g;
    if (i < fade) x[i] *= i / fade;
    if (i >= x.length - fade) x[i] *= (x.length - 1 - i) / fade;
  }
  return x;
}

function writeWav(name, x) {
  const data = Buffer.alloc(x.length * 2);
  for (let i = 0; i < x.length; i++) data.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(x[i] * 32767))), i * 2);
  const head = Buffer.alloc(44);
  head.write("RIFF", 0);
  head.writeUInt32LE(36 + data.length, 4);
  head.write("WAVE", 8);
  head.write("fmt ", 12);
  head.writeUInt32LE(16, 16);
  head.writeUInt16LE(1, 20);
  head.writeUInt16LE(1, 22);
  head.writeUInt32LE(RATE, 24);
  head.writeUInt32LE(RATE * 2, 28);
  head.writeUInt16LE(2, 32);
  head.writeUInt16LE(16, 34);
  head.write("data", 36);
  head.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(OUT, `${name}.wav`), Buffer.concat([head, data]));
  return data.length + 44;
}

// --- звуки ----------------------------------------------------------------------------

const S = {};

/** Пузырёк: нота, быстро уходящая вверх, — так звучит всё «водяное». */
const bubble = (f, sec = 0.12, glide = 4) => tone(f, sec, { attack: 0.003, decay: sec / 3, harmonics: [1, 0.15], glide });

// Съел водоросль: мягкий «пульк».
S.eat = finish(mix(bubble(520, 0.14, 3), bubble(780, 0.1, 3), 0.03, 0.4), 0.45);

// Съел мясо: чавк — шум пониже и пузырь.
S.eat_meat = finish(mix(burst(0.16, { attack: 0.01, decay: 0.05, lo: 200, hi: 1800 }), bubble(300, 0.16, 2), 0.02, 0.8), 0.55);

// Укус: щелчок челюстей — два коротких клика.
S.bite = (() => {
  const x = buf(0.2);
  mix(x, burst(0.05, { decay: 0.008, lo: 1500, hi: 6000 }), 0, 1);
  mix(x, tone(900, 0.06, { decay: 0.015, harmonics: [1, 0.5, 0.3] }), 0, 0.6);
  mix(x, burst(0.05, { decay: 0.01, lo: 900, hi: 4000 }), 0.07, 0.8);
  return finish(x, 0.6);
})();

// Удар: глухой «тук» в воде.
S.hit = finish(mix(tone(160, 0.2, { attack: 0.002, decay: 0.05, harmonics: [1, 0.5, 0.2], glide: -0.5 }), burst(0.08, { decay: 0.02, lo: 300, hi: 2500 }), 0, 0.5), 0.6);

// Тебя ранили: ниже и с дрожью.
S.hurt = (() => {
  const x = tone(220, 0.3, { attack: 0.004, decay: 0.09, harmonics: [1, 0.6, 0.3], glide: -1.2 });
  for (let i = 0; i < x.length; i++) x[i] *= 1 + 0.4 * Math.sin((TAU * 30 * i) / RATE);
  return finish(mix(x, burst(0.1, { decay: 0.03, lo: 200, hi: 1500 }), 0, 0.5), 0.6);
})();

// Победа: «хлоп» и россыпь пузырей.
S.kill = (() => {
  const x = buf(0.7);
  mix(x, burst(0.12, { attack: 0.002, decay: 0.03, lo: 150, hi: 2500 }), 0, 1);
  mix(x, tone(130, 0.25, { decay: 0.07, harmonics: [1, 0.4], glide: -0.6 }), 0, 0.7);
  for (let k = 0; k < 6; k++) mix(x, bubble(600 + rnd() * 900, 0.09, 5), 0.06 + k * 0.07 + rnd() * 0.03, 0.35);
  return finish(x, 0.65);
})();

// Выпала часть: тихий звон.
S.drop = finish(mix(tone(1318.5, 0.5, { attack: 0.004, decay: 0.15, harmonics: [1, 0.2] }), tone(1760, 0.4, { attack: 0.004, decay: 0.12, harmonics: [1] }), 0.07, 0.5), 0.4);

// Подобрал часть: блестящее «дзынь» вверх.
S.pickup = (() => {
  const x = buf(0.6);
  [1046.5, 1318.5, 1568].forEach((f, k) => mix(x, tone(f, 0.35, { attack: 0.004, decay: 0.1, harmonics: [1, 0.25] }), k * 0.06, 0.6));
  return finish(x, 0.55);
})();

// Новая часть: маленькие фанфары.
S.newpart = (() => {
  const x = buf(1.3);
  [523.25, 659.25, 783.99, 1046.5, 1318.5].forEach((f, k) => mix(x, tone(f, 0.8, { attack: 0.006, decay: 0.25, harmonics: [1, 0.3, 0.1] }), k * 0.09, 0.6));
  return finish(x, 0.6);
})();

// Вырос: тёплый аккорд, поднимающийся вверх.
S.levelup = (() => {
  const x = buf(1.8);
  [[261.63, 0], [329.63, 0.12], [392, 0.24], [523.25, 0.36], [659.25, 0.5]].forEach(([f, at]) =>
    mix(x, tone(f, 1.2, { attack: 0.02, decay: 0.45, harmonics: [1, 0.35, 0.12], glide: 0.05 }), at, 0.55));
  for (let k = 0; k < 8; k++) mix(x, bubble(700 + rnd() * 1200, 0.08, 6), 0.3 + rnd() * 1.0, 0.2);
  return finish(x, 0.6);
})();

// Рывок: «вжух» — шум, съезжающий по частоте.
S.dash = (() => {
  const sec = 0.35;
  const x = buf(sec);
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE;
    x[i] = noise() * Math.sin((Math.PI * t) / sec) ** 2;
  }
  bandpass(x, 400, 2600);
  return finish(mix(x, bubble(400, 0.2, 3), 0.02, 0.4), 0.5);
})();

// Ток: треск.
S.zap = (() => {
  const x = buf(0.3);
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE;
    const on = Math.sin(TAU * 60 * t) > 0.2 ? 1 : 0.2;
    x[i] = noise() * on * Math.exp(-t / 0.12);
  }
  highpass(x, 1500);
  return finish(mix(x, tone(120, 0.25, { decay: 0.08, harmonics: [1, 0.8, 0.6, 0.4] }), 0, 0.4), 0.5);
})();

// Яд: шипение.
S.poison = finish(mix(burst(0.4, { attack: 0.03, decay: 0.15, lo: 2500, hi: 8000 }), bubble(260, 0.25, -1), 0.05, 0.4), 0.4);

// Гибель: вниз и глухо.
S.death = (() => {
  const x = buf(1.2);
  [392, 329.63, 261.63, 196].forEach((f, k) => mix(x, tone(f, 0.6, { attack: 0.01, decay: 0.2, harmonics: [1, 0.3] }), k * 0.18, 0.6));
  return finish(lowpass(x, 1800), 0.55);
})();

// Кнопка: едва слышный щелчок.
S.ui = finish(mix(tone(1500, 0.04, { attack: 0.001, decay: 0.008 }), burst(0.02, { decay: 0.004, lo: 2000, hi: 8000 }), 0, 0.3), 0.3);

// Поставил часть: мягкий «чпок».
S.place = finish(mix(bubble(350, 0.18, 2.5), tone(700, 0.12, { decay: 0.04, harmonics: [1, 0.3] }), 0.05, 0.4), 0.55);

// Убрал часть: «чпок» наоборот — вниз.
S.remove = finish(bubble(600, 0.18, -2), 0.5);

// Нельзя: низкий мягкий «бум-бум».
S.nope = finish(mix(tone(240, 0.14, { decay: 0.04, harmonics: [1, 0.3] }), tone(180, 0.18, { decay: 0.05, harmonics: [1, 0.3] }), 0.08, 0.9), 0.45);

// Задача выполнена: светлое арпеджио.
S.goal = (() => {
  const x = buf(1.2);
  [587.33, 739.99, 880, 1174.66].forEach((f, k) => mix(x, tone(f, 0.7, { attack: 0.006, decay: 0.2, harmonics: [1, 0.3, 0.1] }), k * 0.1, 0.6));
  return finish(x, 0.55);
})();

// --- фон ------------------------------------------------------------------------------

/** Петля без шва: хвост плавно накладывается на начало. */
function loop(x, xfadeSec) {
  const n = Math.round(xfadeSec * RATE);
  const out = x.slice(0, x.length - n);
  for (let i = 0; i < n; i++) {
    const k = i / n;
    out[i] = out[i] * k + x[x.length - n + i] * (1 - k);
  }
  return out;
}

// Глубина: низкий гул, медленно дышащий, и редкие пузырьки.
S.amb_water = (() => {
  const sec = 14;
  const x = buf(sec);
  let y = 0;
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE;
    y = 0.995 * y + noise() * 0.02;
    x[i] = y * (0.75 + 0.25 * Math.sin((TAU * t) / 7)) + 0.25 * Math.sin(TAU * 55 * t) * (0.6 + 0.4 * Math.sin((TAU * t) / 3.5));
  }
  lowpass(x, 400);
  const hum = finish(x, 0.3);
  const bubbles = buf(sec);
  for (let k = 0; k < 14; k++) mix(bubbles, bubble(500 + rnd() * 900, 0.1, 5), 0.3 + rnd() * (sec - 1), 0.12);
  return loop(mix(hum, bubbles), 0.6);
})();

// --- добавлены позже: камни и пара -----------------------------------------------------

// Камень: сухой каменный стук и крошки.
S.rock = (() => {
  const x = buf(0.45);
  mix(x, tone(110, 0.3, { attack: 0.002, decay: 0.06, harmonics: [1, 0.7, 0.5, 0.3], glide: -0.3 }), 0, 0.8);
  mix(x, burst(0.2, { decay: 0.04, lo: 600, hi: 4000 }), 0, 0.7);
  for (let k = 0; k < 4; k++) mix(x, burst(0.04, { decay: 0.008, lo: 2000, hi: 7000 }), 0.05 + k * 0.05 + rnd() * 0.03, 0.4);
  return finish(x, 0.65);
})();

// Зов пары: мягкая трель, дважды.
S.mate = (() => {
  const x = buf(1.0);
  [[659.25, 0], [783.99, 0.12], [659.25, 0.34], [880, 0.46]].forEach(([f, at]) =>
    mix(x, tone(f, 0.5, { attack: 0.01, decay: 0.16, harmonics: [1, 0.3, 0.1], glide: 0.08 }), at, 0.55));
  return finish(x, 0.5);
})();

// --- добавлены позже: паразиты, умения, логова, арена, музыка --------------------------

// Прицепился паразит: влажный присос.
S.parasite = (() => {
  const x = buf(0.4);
  mix(x, bubble(260, 0.3, -1.5), 0, 0.8);
  mix(x, burst(0.25, { attack: 0.02, decay: 0.08, lo: 150, hi: 1200 }), 0.02, 0.6);
  return finish(lowpass(x, 2000), 0.55);
})();

// Умение: тёплый нарастающий «вжух» и звон.
S.ability = (() => {
  const x = buf(0.7);
  mix(x, tone(330, 0.6, { attack: 0.08, decay: 0.2, harmonics: [1, 0.4, 0.2], glide: 0.9 }), 0, 0.6);
  mix(x, burst(0.5, { attack: 0.1, decay: 0.12, lo: 400, hi: 3000 }), 0, 0.35);
  mix(x, tone(990, 0.4, { attack: 0.005, decay: 0.12, harmonics: [1, 0.2] }), 0.15, 0.3);
  return finish(x, 0.55);
})();

// Хозяин логова: низкий рык.
S.boss = (() => {
  const x = buf(1.2);
  mix(x, tone(55, 1.1, { attack: 0.05, decay: 0.4, harmonics: [1, 0.8, 0.6, 0.4, 0.3], glide: -0.1 }), 0, 0.9);
  const grit = burst(1.0, { attack: 0.05, decay: 0.3, lo: 60, hi: 500 });
  mix(x, grit, 0, 0.8);
  return finish(lowpass(x, 900), 0.7);
})();

// Новая волна на арене: гонг.
S.wave = (() => {
  const x = buf(1.6);
  mix(x, tone(196, 1.5, { attack: 0.003, decay: 0.5, harmonics: [1, 0.6, 0.35, 0.25, 0.15] }), 0, 0.7);
  mix(x, tone(293.66, 1.2, { attack: 0.003, decay: 0.35, harmonics: [1, 0.3] }), 0.02, 0.35);
  return finish(x, 0.6);
})();

/** Петля без шва: всё, что звучит за концом, дописывается в начало. */
function mixWrap(dst, src, at = 0, gain = 1) {
  const o = Math.round(at * RATE);
  for (let i = 0; i < src.length; i++) dst[(o + i) % dst.length] += src[i] * gain;
  return dst;
}
function normalize(x, peak) {
  let max = 0;
  for (const v of x) max = Math.max(max, Math.abs(v));
  for (let i = 0; i < x.length; i++) x[i] *= peak / max;
  return x;
}
const midi = (n) => 440 * Math.pow(2, (n - 69) / 12);

// Спокойная музыка: медленные аккорды-«подушки» и редкие капли-ноты сверху.
S.music_calm = (() => {
  const bar = 4; // секунды на аккорд
  const chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62], [57, 60, 64], [50, 53, 57]];
  const x = buf(bar * chords.length);
  chords.forEach((ch, k) => {
    ch.forEach((n) => mixWrap(x, tone(midi(n), bar + 1.5, { attack: 1.2, decay: 1.6, harmonics: [1, 0.25, 0.08] }), k * bar, 0.22));
    mixWrap(x, tone(midi(ch[0] - 12), bar + 1, { attack: 0.6, decay: 1.4, harmonics: [1, 0.2] }), k * bar, 0.25);
  });
  const scale = [69, 72, 74, 76, 79, 81, 84];
  for (let b = 0; b < chords.length * 4; b++) {
    if (rnd() < 0.55) {
      const n = scale[Math.floor(rnd() * scale.length)];
      mixWrap(x, tone(midi(n), 1.6, { attack: 0.004, decay: 0.45, harmonics: [1, 0.12, 0.05] }), b * 1.0 + rnd() * 0.2, 0.12);
    }
  }
  lowpass(x, 3000);
  return normalize(x, 0.42);
})();

// Музыка боя: быстрый низкий пульс, тревожные ноты и мягкие удары.
S.music_fight = (() => {
  const beat = 60 / 132;
  const beats = 48;
  const x = buf(beat * beats);
  const bass = [45, 45, 48, 45, 43, 43, 41, 40];
  for (let b = 0; b < beats; b++) {
    const n = bass[Math.floor(b / 2) % bass.length];
    for (let h = 0; h < 2; h++)
      mixWrap(x, tone(midi(n - 12), beat * 0.6, { attack: 0.005, decay: 0.09, harmonics: [1, 0.5, 0.3, 0.2] }), (b + h * 0.5) * beat, 0.3);
    if (b % 2 === 0) mixWrap(x, tone(60, 0.3, { attack: 0.002, decay: 0.07, harmonics: [1, 0.3], glide: -0.6 }), b * beat, 0.55);
    if (b % 4 === 2) mixWrap(x, burst(0.15, { decay: 0.04, lo: 300, hi: 3000 }), b * beat, 0.25);
  }
  const lead = [69, 72, 71, 67, 69, 64, 65, 64];
  lead.forEach((n, k) => mixWrap(x, tone(midi(n), beat * 5, { attack: 0.05, decay: beat * 2, harmonics: [1, 0.35, 0.15] }), k * beat * 6, 0.16));
  lowpass(x, 3500);
  return normalize(x, 0.45);
})();

// --- добавлены позже: голоса существ и выстрелы ----------------------------------------

// Мирные: короткий щебет вверх.
S.chirp = (() => {
  const x = buf(0.3);
  mix(x, tone(1300, 0.12, { attack: 0.004, decay: 0.04, harmonics: [1, 0.2], glide: 1.2 }), 0, 0.6);
  mix(x, tone(1700, 0.1, { attack: 0.004, decay: 0.035, harmonics: [1, 0.2], glide: 0.8 }), 0.09, 0.45);
  return finish(x, 0.4);
})();

// Хищники: низкое рычание с дрожью.
S.growl = (() => {
  const x = buf(0.7);
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE;
    const f = 90 + 15 * Math.sin(TAU * 7 * t);
    x[i] = Math.sin(TAU * f * t) * 0.6 + Math.sin(TAU * f * 2.01 * t) * 0.3 + noise() * 0.25;
    x[i] *= env(t, 0.05, 0.25);
  }
  return finish(lowpass(x, 900), 0.55);
})();

// Гиганты: глубокий гул.
S.boom = (() => {
  const x = buf(1.4);
  mix(x, tone(48, 1.3, { attack: 0.08, decay: 0.5, harmonics: [1, 0.7, 0.4, 0.2], glide: -0.15 }), 0, 0.9);
  mix(x, burst(0.8, { attack: 0.08, decay: 0.3, lo: 40, hi: 300 }), 0, 0.5);
  return finish(lowpass(x, 600), 0.7);
})();

// Паразиты: влажное шипение.
S.hiss = finish(burst(0.5, { attack: 0.03, decay: 0.15, lo: 2500, hi: 7000 }), 0.35);

// Плевок и выстрел иглой: хлопок с посвистом.
S.spit = (() => {
  const x = buf(0.3);
  mix(x, burst(0.12, { decay: 0.02, lo: 400, hi: 3000 }), 0, 0.8);
  mix(x, tone(700, 0.2, { attack: 0.002, decay: 0.06, harmonics: [1, 0.3], glide: -1.2 }), 0.01, 0.5);
  return finish(x, 0.45);
})();

// Делитель распался: двойной «чпок».
S.split = finish(mix(bubble(300, 0.18, 3), bubble(420, 0.16, 3), 0.1, 0.8), 0.5);

// Старый кит: протяжная песня.
S.whale = (() => {
  const x = buf(2.2);
  mix(x, tone(220, 2.0, { attack: 0.4, decay: 0.8, harmonics: [1, 0.5, 0.25], glide: 0.35 }), 0, 0.6);
  mix(x, tone(165, 1.6, { attack: 0.3, decay: 0.6, harmonics: [1, 0.4], glide: -0.2 }), 0.5, 0.4);
  return finish(lowpass(x, 1500), 0.55);
})();

// --- добавлены позже: атмосфера ------------------------------------------------------

// Сердцебиение, когда мало здоровья: «тук-тук», глухо.
S.heart = (() => {
  const x = buf(0.6);
  const thump = () => lowpass(tone(58, 0.25, { attack: 0.006, decay: 0.06, harmonics: [1, 0.5, 0.2], glide: -0.4 }), 300);
  mix(x, thump(), 0, 1);
  mix(x, thump(), 0.2, 0.7);
  return finish(x, 0.6);
})();

// Струйка пузырьков вдалеке.
S.bubbles = (() => {
  const x = buf(1.6);
  for (let k = 0; k < 11; k++) mix(x, bubble(380 + rnd() * 700, 0.12 + rnd() * 0.06, 3 + rnd() * 3), 0.05 + k * 0.11 + rnd() * 0.05, 0.25 + rnd() * 0.2);
  return finish(lowpass(x, 2500), 0.4);
})();

// Далёкий скрип и потрескивание — будто что-то огромное шевелится на дне.
S.creak = (() => {
  const x = buf(1.8);
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE;
    const f = 70 + 25 * Math.sin(TAU * 0.7 * t) + 8 * Math.sin(TAU * 13 * t);
    x[i] = Math.sin(TAU * f * t) * 0.4 * Math.sin((Math.PI * t) / 1.8);
  }
  for (let k = 0; k < 9; k++) mix(x, burst(0.03, { decay: 0.006, lo: 700, hi: 3000 }), 0.2 + rnd() * 1.3, 0.35);
  return finish(lowpass(x, 1200), 0.45);
})();

// Зов из глубины: низкий протяжный стон, как у кита, только дальше.
S.deep = (() => {
  const x = buf(3.2);
  mix(x, tone(98, 3.0, { attack: 0.8, decay: 1.0, harmonics: [1, 0.45, 0.2, 0.1], glide: 0.12 }), 0, 0.7);
  mix(x, tone(73.4, 2.4, { attack: 0.6, decay: 0.9, harmonics: [1, 0.3], glide: -0.08 }), 0.6, 0.5);
  return finish(lowpass(x, 700), 0.55);
})();

// Событие в океане: медленно нарастающий гул с мерцанием.
S.swell = (() => {
  const x = buf(3.0);
  for (let i = 0; i < x.length; i++) {
    const t = i / RATE;
    const e = Math.sin((Math.PI * t) / 3.0);
    x[i] = (Math.sin(TAU * 110 * t) * 0.4 + Math.sin(TAU * 164.8 * t) * 0.3 + Math.sin(TAU * 220.5 * t) * 0.15) * e * e;
  }
  for (let k = 0; k < 8; k++) mix(x, tone(880 + rnd() * 900, 0.5, { attack: 0.05, decay: 0.2, harmonics: [1] }), 0.4 + rnd() * 2.0, 0.08);
  return finish(lowpass(x, 2500), 0.5);
})();

fs.mkdirSync(OUT, { recursive: true });
let total = 0;
for (const [name, x] of Object.entries(S)) total += writeWav(name, x);
console.log(`${Object.keys(S).length} звуков, ${Math.round(total / 1024)} КБ → ${OUT}`);
