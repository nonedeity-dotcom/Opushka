/*
 * Проверка звуков — чтобы «слышать» их без ушей: числа и картинки.
 *
 *   node tools/sound-check.js                  все звуки из sounds/
 *   node tools/sound-check.js a.wav b.wav      только эти файлы (например, запись игры)
 *   node tools/sound-check.js --sheet=out.png  ещё и лист со спектрограммами
 *
 * Для каждого звука: длина, пик, громкость (как её слышит ухо — с K-фильтром, как в LUFS),
 * громкость в игре (с поправкой LEVEL из sound_bank.gd), сколько останется в динамике
 * телефона (он почти не играет ниже ~300 Гц), доли низа/середины/«колючих» частот, щелчки
 * на краях, резкие скачки, перегруз, смещение нуля, шов петли. В конце — что подозрительно.
 *
 * Лист: по строке на звук — номер и имя, форма волны и спектрограмма (снизу низкие частоты,
 * сверху высокие, яркость — громкость). По ней видно, где звук резкий, где гулкий, где пусто.
 */
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const ROOT = path.join(__dirname, "..");
const args = process.argv.slice(2);
const sheetArg = args.find((a) => a.startsWith("--sheet="));
const files = args.filter((a) => !a.startsWith("--"));
const list = files.length
  ? files
  : fs.readdirSync(path.join(ROOT, "sounds")).filter((f) => f.endsWith(".wav")).sort().map((f) => path.join(ROOT, "sounds", f));

// Поправки громкости из игры: LEVEL в sound_bank.gd.
const LEVEL = {};
try {
  const src = fs.readFileSync(path.join(ROOT, "scripts", "sound_bank.gd"), "utf8");
  const m = src.match(/const LEVEL := \{([\s\S]*?)\}/);
  if (m) for (const [, k, v] of m[1].matchAll(/"(\w+)":\s*(-?[\d.]+)/g)) LEVEL[k] = parseFloat(v);
} catch (e) {}
// Звуки, которые звучат часто: им нельзя быть громче редких.
const FREQUENT = ["eat", "eat_meat", "bite", "hit", "dash", "chirp", "ui", "place", "drop", "rock", "spit", "bubbles"];
const LOOPS = ["amb_water", "music_calm", "music_fight"];

// --- чтение WAV -------------------------------------------------------------------------

function readWav(file) {
  const b = fs.readFileSync(file);
  let o = 12, fmt = null, data = null;
  while (o + 8 <= b.length) {
    const id = b.toString("ascii", o, o + 4);
    const size = b.readUInt32LE(o + 4);
    if (id === "fmt ") fmt = { format: b.readUInt16LE(o + 8), ch: b.readUInt16LE(o + 10), rate: b.readUInt32LE(o + 12), bits: b.readUInt16LE(o + 22) };
    if (id === "data") data = b.subarray(o + 8, o + 8 + size);
    o += 8 + size + (size % 2);
  }
  if (!fmt || !data) throw new Error("не WAV: " + file);
  const bytes = fmt.bits / 8;
  const n = Math.floor(data.length / (bytes * fmt.ch));
  const x = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    let v = 0;
    for (let c = 0; c < fmt.ch; c++) {
      const p = (i * fmt.ch + c) * bytes;
      if (fmt.format === 3) v += data.readFloatLE(p);
      else if (fmt.bits === 16) v += data.readInt16LE(p) / 32768;
      else if (fmt.bits === 32) v += data.readInt32LE(p) / 2147483648;
      else if (fmt.bits === 8) v += (data[p] - 128) / 128;
    }
    x[i] = v / fmt.ch;
  }
  return { x, rate: fmt.rate };
}

// --- фильтры и спектр -------------------------------------------------------------------

/** Бикуад (RBJ). type: hp, lp, shelf. */
function biquad(x, rate, type, f0, q = 0.707, gainDb = 0) {
  const w = (2 * Math.PI * f0) / rate, cw = Math.cos(w), sw = Math.sin(w), al = sw / (2 * q);
  let b0, b1, b2, a0, a1, a2;
  if (type === "hp") [b0, b1, b2, a0, a1, a2] = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2, 1 + al, -2 * cw, 1 - al];
  else if (type === "lp") [b0, b1, b2, a0, a1, a2] = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2, 1 + al, -2 * cw, 1 - al];
  else {
    const A = Math.pow(10, gainDb / 40), s = 2 * Math.sqrt(A) * al;
    [b0, b1, b2] = [A * (A + 1 + (A - 1) * cw + s), -2 * A * (A - 1 + (A + 1) * cw), A * (A + 1 + (A - 1) * cw - s)];
    [a0, a1, a2] = [A + 1 - (A - 1) * cw + s, 2 * (A - 1 - (A + 1) * cw), A + 1 - (A - 1) * cw - s];
  }
  const y = new Float32Array(x.length);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < x.length; i++) {
    const v = (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
    x2 = x1; x1 = x[i]; y2 = y1; y1 = v; y[i] = v;
  }
  return y;
}

/** Громкость «как слышит ухо»: K-фильтр и средний квадрат по блокам 400 мс с порогом тишины. */
function loudness(x, rate) {
  const k = biquad(biquad(x, rate, "shelf", 1500, 0.707, 4), rate, "hp", 60, 0.5);
  const blk = Math.max(1, Math.round(0.4 * rate)), hop = Math.max(1, Math.round(0.1 * rate));
  const ms = [];
  for (let s = 0; s + blk <= k.length || (s === 0 && k.length > 0); s += hop) {
    const e = Math.min(k.length, s + blk);
    let sum = 0;
    for (let i = s; i < e; i++) sum += k[i] * k[i];
    ms.push(sum / (e - s));
    if (e >= k.length) break;
  }
  const lk = (v) => -0.691 + 10 * Math.log10(v + 1e-12);
  const loud = ms.filter((v) => lk(v) > -70);
  if (!loud.length) return -99;
  return lk(loud.reduce((a, b) => a + b, 0) / loud.length);
}

function fft(re, im) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = (-2 * Math.PI) / len;
    for (let i = 0; i < n; i += len)
      for (let j = 0; j < len / 2; j++) {
        const wr = Math.cos(ang * j), wi = Math.sin(ang * j);
        const ur = re[i + j], ui = im[i + j];
        const vr = re[i + j + len / 2] * wr - im[i + j + len / 2] * wi;
        const vi = re[i + j + len / 2] * wi + im[i + j + len / 2] * wr;
        re[i + j] = ur + vr; im[i + j] = ui + vi;
        re[i + j + len / 2] = ur - vr; im[i + j + len / 2] = ui - vi;
      }
  }
}

/** Спектрограмма: кадры по N точек, окно Ханна. Возвращает [кадры][бины] мощности. */
function stft(x, N = 1024, hop = 256) {
  const frames = [];
  const win = Float32Array.from({ length: N }, (_, i) => 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / N));
  for (let s = 0; s + N <= Math.max(x.length, N); s += hop) {
    const re = new Float64Array(N), im = new Float64Array(N);
    for (let i = 0; i < N; i++) re[i] = (x[s + i] || 0) * win[i];
    fft(re, im);
    const p = new Float64Array(N / 2);
    for (let i = 0; i < N / 2; i++) p[i] = re[i] * re[i] + im[i] * im[i];
    frames.push(p);
  }
  return frames;
}

// --- разбор одного звука ----------------------------------------------------------------

const db = (v) => 20 * Math.log10(Math.max(v, 1e-9));

function analyze(file) {
  const { x, rate } = readWav(file);
  const name = path.basename(file, ".wav");
  let peak = 0, sum = 0, clip = 0, mean = 0;
  for (const v of x) { peak = Math.max(peak, Math.abs(v)); sum += v * v; mean += v; if (Math.abs(v) >= 0.999) clip++; }
  mean /= x.length;
  const rms = Math.sqrt(sum / x.length);
  const lufs = loudness(x, rate);
  // Динамик телефона: почти ничего ниже 300 Гц.
  const phone = loudness(biquad(biquad(x, rate, "hp", 300, 0.707), rate, "hp", 300, 0.707), rate);
  // Доли энергии по полосам.
  const fr = stft(x);
  const bands = { low: 0, lowmid: 0, mid: 0, harsh: 0, high: 0 };
  let tot = 0, cen = 0;
  for (const p of fr)
    for (let i = 1; i < p.length; i++) {
      const f = (i * rate) / 1024;
      const e = p[i];
      tot += e; cen += e * f;
      if (f < 150) bands.low += e; else if (f < 500) bands.lowmid += e; else if (f < 2000) bands.mid += e; else if (f < 5000) bands.harsh += e; else bands.high += e;
    }
  for (const k in bands) bands[k] = tot ? bands[k] / tot : 0;
  // Щелчки: звук не с нуля начинается или обрывается не в ноль.
  const edge = Math.max(1, Math.round(rate * 0.002));
  const startJump = Math.abs(x[0]);
  const endJump = Math.abs(x[x.length - 1]);
  // Резкие скачки внутри: разность соседних точек много больше обычной.
  let maxStep = 0, stepSum = 0;
  for (let i = 1; i < x.length; i++) { const d = Math.abs(x[i] - x[i - 1]); stepSum += d; if (d > maxStep) maxStep = d; }
  const stepRatio = maxStep / (stepSum / x.length + 1e-9);
  const seam = LOOPS.includes(name) ? Math.abs(x[x.length - 1] - x[0]) : 0;
  return { name, file, x, rate, fr, dur: x.length / rate, peak: db(peak), rms: db(rms), lufs, phone, clip, mean, bands,
    centroid: tot ? cen / tot : 0, startJump, endJump, stepRatio, seam, level: LEVEL[name] || 0, edge };
}

// --- отчёт ------------------------------------------------------------------------------

const res = list.map(analyze);
const pct = (v) => `${Math.round(v * 100)}`.padStart(3) + "%";
console.log("№  звук          сек   пик  громк  в игре телефон  низ <150 150-500 0.5-2к 2-5к >5к  яркость");
res.forEach((r, i) => {
  const game = r.lufs + r.level;
  console.log(
    `${String(i + 1).padStart(2)} ${r.name.padEnd(13)} ${r.dur.toFixed(2).padStart(5)} ${r.peak.toFixed(1).padStart(5)} ${r.lufs.toFixed(1).padStart(6)} ${game.toFixed(1).padStart(6)} ${(r.phone - r.lufs).toFixed(1).padStart(6)}  ${pct(r.bands.low)}  ${pct(r.bands.lowmid)}  ${pct(r.bands.mid)}  ${pct(r.bands.harsh)} ${pct(r.bands.high)}  ${Math.round(r.centroid)} Гц`
  );
});

// Что подозрительно.
const games = res.map((r) => r.lufs + r.level).sort((a, b) => a - b);
const median = games[Math.floor(games.length / 2)];
const notes = [];
for (const r of res) {
  const game = r.lufs + r.level;
  const say = (s) => notes.push(`${r.name}: ${s}`);
  if (r.clip > 0) say(`перегруз — ${r.clip} точек упираются в потолок`);
  if (r.peak > -0.5) say(`пик ${r.peak.toFixed(1)} дБ — почти вплотную к потолку`);
  if (r.startJump > 0.02) say(`щелчок в начале (${r.startJump.toFixed(3)})`);
  if (r.endJump > 0.02) say(`щелчок в конце — обрывается не в ноль (${r.endJump.toFixed(3)})`);
  if (r.seam > 0.05) say(`шов петли слышен: скачок ${r.seam.toFixed(3)}`);
  if (Math.abs(r.mean) > 0.01) say(`смещение нуля ${r.mean.toFixed(3)}`);
  if (r.phone - r.lufs < -10) say(`в динамике телефона тише на ${(r.lufs - r.phone).toFixed(0)} дБ — почти весь звук ниже 300 Гц, на телефоне его едва слышно`);
  if (r.bands.harsh > 0.35) say(`много «колючих» 2–5 кГц (${pct(r.bands.harsh).trim()}) — может резать ухо`);
  if (r.bands.high > 0.25) say(`много шипящего верха >5 кГц (${pct(r.bands.high).trim()})`);
  if (FREQUENT.includes(r.name) && game > median + 4) say(`звучит часто, а громче середины на ${(game - median).toFixed(0)} дБ — утомит`);
  if (game > median + 8) say(`громче большинства на ${(game - median).toFixed(0)} дБ`);
  if (game < median - 12) say(`тише большинства на ${(median - game).toFixed(0)} дБ — может потеряться`);
}
console.log("\nСредняя громкость в игре: " + median.toFixed(1));
console.log(notes.length ? "\nПодозрительно:\n- " + notes.join("\n- ") : "\nНичего подозрительного.");

// --- лист со спектрограммами ------------------------------------------------------------

if (sheetArg) {
  const out = sheetArg.slice(8);
  const W = 900, ROW = 70, LABEL = 150;
  const H = ROW * res.length;
  const img = new Uint8Array(W * H * 3).fill(12);
  const put = (x, y, c) => { if (x < 0 || y < 0 || x >= W || y >= H) return; const o = (y * W + x) * 3; img[o] = c[0]; img[o + 1] = c[1]; img[o + 2] = c[2]; };
  // Шрифт 3×5 — только чтобы подписать строки.
  const F = { a: "010101111101101", b: "110101110101110", c: "011100100100011", d: "110101101101110", e: "111100110100111", f: "111100110100100", g: "011100101101011", h: "101101111101101", i: "111010010010111", j: "001001001101010", k: "101101110101101", l: "100100100100111", m: "101111111101101", n: "110101101101101", o: "010101101101010", p: "110101110100100", q: "010101101110011", r: "110101110101101", s: "011100010001110", t: "111010010010010", u: "101101101101111", v: "101101101101010", w: "101101111111101", x: "101101010101101", y: "101101010010010", z: "111001010100111", _: "000000000000111", 0: "111101101101111", 1: "010110010010111", 2: "110001010100111", 3: "110001010001110", 4: "101101111001001", 5: "111100110001110", 6: "011100111101111", 7: "111001010010010", 8: "111101111101111", 9: "111101111001110", " ": "000000000000000", ".": "000000000000010" };
  const text = (s, x0, y0, sc, c) => { let x = x0; for (const ch of s.toLowerCase()) { const g = F[ch] || F[" "]; for (let k = 0; k < 15; k++) if (g[k] === "1") for (let a = 0; a < sc; a++) for (let b = 0; b < sc; b++) put(x + (k % 3) * sc + a, y0 + Math.floor(k / 3) * sc + b, c); x += 4 * sc; } };
  const heat = (v) => { v = Math.max(0, Math.min(1, v)); return [Math.round(255 * Math.min(1, v * 1.8)), Math.round(255 * Math.max(0, Math.min(1, v * 1.8 - 0.5))), Math.round(255 * Math.max(0, v * 3 - 2) + 60 * (1 - v))]; };
  res.forEach((r, row) => {
    const y0 = row * ROW;
    for (let x = 0; x < W; x++) put(x, y0, [40, 44, 50]);
    text(`${row + 1} ${r.name}`, 6, y0 + 8, 3, [230, 230, 220]);
    text(`${r.dur.toFixed(1)}s`, 6, y0 + 34, 2, [150, 150, 150]);
    // Форма волны: 30% ширины.
    const ww = 220, wx = LABEL, mid = y0 + ROW / 2;
    for (let px = 0; px < ww; px++) {
      const s0 = Math.floor((px / ww) * r.x.length), s1 = Math.floor(((px + 1) / ww) * r.x.length);
      let mn = 0, mx = 0;
      for (let i = s0; i < s1; i++) { mn = Math.min(mn, r.x[i]); mx = Math.max(mx, r.x[i]); }
      for (let y = Math.round(mid - mx * 30); y <= Math.round(mid - mn * 30); y++) put(wx + px, y, [120, 200, 170]);
    }
    // Спектрограмма: по оси y — частоты от 40 Гц до 11 кГц в логарифме.
    const sx = LABEL + ww + 10, sw = W - sx - 6, sh = ROW - 6;
    const fr = r.fr;
    // Яркость — от самого громкого места этого звука вниз на 60 дБ.
    let top = -200;
    for (const p of fr) for (let i = 1; i < p.length; i++) top = Math.max(top, 10 * Math.log10(p[i] + 1e-12));
    for (let px = 0; px < sw; px++) {
      const p = fr[Math.min(fr.length - 1, Math.floor((px / sw) * fr.length))];
      for (let py = 0; py < sh; py++) {
        const f = 40 * Math.pow(11000 / 40, 1 - py / sh);
        const bin = Math.min(p.length - 1, Math.max(1, Math.round((f * 1024) / r.rate)));
        const v = (10 * Math.log10(p[bin] + 1e-12) - (top - 60)) / 60;
        put(sx + px, y0 + 3 + py, heat(v));
      }
    }
    // Метки 300 Гц (ниже — телефону не сыграть) и 2 кГц.
    for (const [f, c] of [[300, [255, 90, 90]], [2000, [120, 120, 255]]]) {
      const py = Math.round((1 - Math.log(f / 40) / Math.log(11000 / 40)) * sh);
      for (let px = 0; px < sw; px += 3) put(sx + px, y0 + 3 + py, c);
    }
  });
  // PNG: сырые строки + deflate.
  const raw = Buffer.alloc((W * 3 + 1) * H);
  for (let y = 0; y < H; y++) { raw[y * (W * 3 + 1)] = 0; Buffer.from(img.buffer, y * W * 3, W * 3).copy(raw, y * (W * 3 + 1) + 1); }
  const crcT = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = (b) => { let c = 0xffffffff; for (const v of b) c = crcT[(c ^ v) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (type, data) => { const l = Buffer.alloc(4); l.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 2;
  fs.writeFileSync(out, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]));
  console.log(`\nЛист: ${out}`);
}
