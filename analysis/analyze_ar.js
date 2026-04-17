// COTD Cutoff — AR Residual Correction Analysis
//
// Tests three ideas to improve accuracy beyond the blended velocity model:
//
// Idea A — AR(1) residual correction (works at ALL time points):
//   At each step, observe: residual = currentCutoff - staticPred(prevCutoff, prevR)
//   Adjust: finalPred = staticPred + λ * residual
//   If residuals are autocorrelated (session running consistently fast/slow),
//   this captures the session-specific bias.
//
// Idea B — Cutoff-magnitude binning:
//   Sessions with a low absolute cutoff (fast maps) likely behave differently
//   from high-cutoff (technical map) sessions. Fit separate (a,b) per bin.
//
// Idea C — Exponentially-weighted long velocity window (12 readings, ~3 min):
//   More stable velocity estimate than 3-point window; deweighted for old data.
//   Blended in using the same sigmoid profile as the best config.
//
// Usage: node analyze_ar.js <data-dir>

'use strict';
const fs = require('fs');
const path = require('path');

const DATA_DIR = process.argv[2];
if (!DATA_DIR) {
    console.error('Usage: node analyze_ar.js <data-dir>');
    process.exit(1);
}

const T = 840;
const A = 0.0824;
const B = 1.5962;
const BUCKET_SIZE = 30;

// ─── Static model ─────────────────────────────────────────────────────────────
function staticPred(C, R) {
    if (R <= 0) return C;
    const r = R / T;
    let cor = 1 - A * Math.pow(r, B);
    return C * Math.max(0.5, Math.min(1.0, cor));
}

// ─── Load sessions (sequential per-session rows) ──────────────────────────────
const sessions = [];
const files = fs.readdirSync(DATA_DIR).filter(f => f.endsWith('.txt')).sort();

for (const file of files) {
    const raw = fs.readFileSync(path.join(DATA_DIR, file), 'utf8').trim();
    if (!raw) continue;
    const rows = raw.split('\n').map(line => {
        const p = line.trim().split(',');
        if (p.length < 4) return null;
        const R = parseInt(p[2], 10);
        const C = parseInt(p[3], 10);
        return (!isNaN(R) && !isNaN(C) && C > 0) ? { R, C } : null;
    }).filter(Boolean);
    if (rows.length < 5) continue;
    const finalCutoff = rows[rows.length - 1].C;
    sessions.push({ file, rows, finalCutoff });
}
console.log(`\nFiles loaded: ${sessions.length}`);

// ─── Idea A: AR(1) grid search over λ ────────────────────────────────────────
console.log(`\n${'═'.repeat(70)}`);
console.log(`IDEA A — AR(1) Residual Correction`);
console.log(`  finalPred = staticPred(current) + λ * (currentCutoff - staticPred(prevCutoff, prevR))`);
console.log('═'.repeat(70));

function evalAR(lambda) {
    const buckets = new Map();
    const staticBuckets = new Map();

    for (const { rows, finalCutoff } of sessions) {
        for (let i = 1; i < rows.length; i++) {
            const { R, C } = rows[i];
            if (R === 0 || C <= finalCutoff) continue;
            const prev = rows[i - 1];

            const sp = staticPred(C, R);
            const prevSP = staticPred(prev.C, prev.R);
            const residual = C - prevSP;  // negative = dropped more than expected
            const adjusted = sp + lambda * residual;
            const clamped = Math.min(C, Math.max(C * 0.5, adjusted));

            const bk = Math.round(R / BUCKET_SIZE) * BUCKET_SIZE;
            if (!buckets.has(bk)) { buckets.set(bk, []); staticBuckets.set(bk, []); }
            buckets.get(bk).push(clamped - finalCutoff);
            staticBuckets.get(bk).push(sp - finalCutoff);
        }
    }
    return { buckets, staticBuckets };
}

// Grid search λ
let bestLambda = 0, bestARmae = Infinity;
for (let li = 0; li <= 40; li++) {
    const lam = li * 0.05;  // 0.0 → 2.0
    const { buckets } = evalAR(lam);
    const allErrs = [...buckets.values()].flat();
    const mae = allErrs.reduce((s, e) => s + Math.abs(e), 0) / allErrs.length;
    if (mae < bestARmae) { bestARmae = mae; bestLambda = lam; }
}
console.log(`  Optimal λ = ${bestLambda.toFixed(2)}, overall MAE = ${bestARmae.toFixed(1)} ms`);

// Detailed breakdown at best λ
const { buckets: arBuckets, staticBuckets: arStaticBuckets } = evalAR(bestLambda);
console.log(`\n  λ = ${bestLambda.toFixed(2)}`);
console.log(`  ${'Time'.padEnd(10)} ${'Secs'.padEnd(6)} ${'Static MAE'.padEnd(13)} ${'AR MAE'.padEnd(13)} Δ`);
console.log('  ' + '─'.repeat(58));

const allARstatic = [], allAR = [];
for (const [bk, errs] of [...arBuckets.entries()].sort((a, b) => a[0] - b[0])) {
    const sErrs = arStaticBuckets.get(bk) || [];
    const sMAE = sErrs.reduce((s, e) => s + Math.abs(e), 0) / sErrs.length;
    const MAE  = errs.reduce((s, e) => s + Math.abs(e), 0) / errs.length;
    const d = sMAE - MAE;
    const sign = d >= 0 ? '+' : '';
    const mins = Math.floor(bk/60), secs = bk%60;
    console.log(`  ${`${mins}m ${String(secs).padStart(2,'0')}s`.padEnd(10)} ${String(bk).padEnd(6)} ${sMAE.toFixed(1).padEnd(13)} ${MAE.toFixed(1).padEnd(13)} ${sign}${d.toFixed(1)} ms (${sign}${(d/sMAE*100).toFixed(1)}%)`);
    allARstatic.push(...sErrs);
    allAR.push(...errs);
}
const arStaticMAE = allARstatic.reduce((s,e)=>s+Math.abs(e),0)/allARstatic.length;
const arMAE       = allAR.reduce((s,e)=>s+Math.abs(e),0)/allAR.length;
console.log(`\n  Static overall MAE : ${arStaticMAE.toFixed(1)} ms`);
console.log(`  AR     overall MAE : ${arMAE.toFixed(1)} ms  (${(+(arStaticMAE-arMAE)).toFixed(1)} ms improvement)`);

// ─── Idea B: Cutoff-magnitude binning ─────────────────────────────────────────
console.log(`\n${'═'.repeat(70)}`);
console.log(`IDEA B — Cutoff-Magnitude Binning (fast/med/slow sessions)`);
console.log('═'.repeat(70));

// Bin sessions by median cutoff value into 3 equal-size groups
const sessionMedians = sessions.map(s => ({
    ...s,
    median: s.rows[Math.floor(s.rows.length / 2)].C,
})).sort((a, b) => a.median - b.median);

const third = Math.floor(sessionMedians.length / 3);
const bins = [
    { label: 'fast (low cutoff)',  sessions: sessionMedians.slice(0, third) },
    { label: 'med  (mid cutoff)',  sessions: sessionMedians.slice(third, 2*third) },
    { label: 'slow (high cutoff)', sessions: sessionMedians.slice(2*third) },
];

// Fit (a,b) separately for each bin using gradient descent on correction means
function fitBin(binSessions) {
    const snapshots = [];
    for (const { rows, finalCutoff } of binSessions) {
        for (const row of rows) {
            if (row.R === 0 || row.C <= finalCutoff) continue;
            snapshots.push({ r: row.R / T, correction: finalCutoff / row.C });
        }
    }
    // Bucket into 30s intervals
    const bmap = new Map();
    for (const s of snapshots) {
        const bk = Math.round(s.r * T / BUCKET_SIZE) * BUCKET_SIZE;
        if (!bmap.has(bk)) bmap.set(bk, []);
        bmap.get(bk).push(s.correction);
    }
    const pts = [...bmap.entries()].map(([bk, cs]) => ({
        x: bk / T,
        y: cs.reduce((a,b)=>a+b,0)/cs.length,
    })).filter(p => p.x > 0 && p.y < 1.0);

    // Gradient descent
    let a = A, b = B, lr = 0.001;
    for (let step = 0; step < 200000; step++) {
        let ga = 0, gb = 0;
        for (const p of pts) {
            const xb = Math.pow(p.x, b);
            const err = (1 - a*xb) - p.y;
            ga += 2 * err * (-xb);
            gb += 2 * err * (-a * xb * Math.log(p.x));
        }
        ga /= pts.length; gb /= pts.length;
        a -= lr * ga; b -= lr * gb;
        a = Math.max(0.001, a); b = Math.max(0.1, b);
        if (step % 50000 === 49999) lr *= 0.5;
    }
    return { a, b };
}

const binnedBuckets = new Map();
const binnedStaticBuckets = new Map();

process.stdout.write('  Fitting per-bin models...');
for (const bin of bins) {
    const { a, b } = fitBin(bin.sessions);
    bin.a = a; bin.b = b;
    process.stdout.write(` ${bin.label.split(' ')[0]}(a=${a.toFixed(4)},b=${b.toFixed(4)})`);

    // Evaluate
    for (const { rows, finalCutoff, median } of bin.sessions) {
        for (const row of rows) {
            if (row.R === 0 || row.C <= finalCutoff) continue;
            const r = row.R / T;
            let cor = 1 - a * Math.pow(r, b);
            cor = Math.max(0.5, Math.min(1.0, cor));
            const pred = row.C * cor;
            const spred = staticPred(row.C, row.R);
            const bk = Math.round(row.R / BUCKET_SIZE) * BUCKET_SIZE;
            if (!binnedBuckets.has(bk)) { binnedBuckets.set(bk, []); binnedStaticBuckets.set(bk, []); }
            binnedBuckets.get(bk).push(pred - finalCutoff);
            binnedStaticBuckets.get(bk).push(spred - finalCutoff);
        }
    }
}
console.log(' done');

const allBinnedStatic = [...binnedStaticBuckets.values()].flat();
const allBinned       = [...binnedBuckets.values()].flat();
const binnedStaticMAE = allBinnedStatic.reduce((s,e)=>s+Math.abs(e),0)/allBinnedStatic.length;
const binnedMAE       = allBinned.reduce((s,e)=>s+Math.abs(e),0)/allBinned.length;
bins.forEach(b => console.log(`  ${b.label.padEnd(22)}: a=${b.a.toFixed(4)}, b=${b.b.toFixed(4)}`));
console.log(`\n  Static overall MAE  : ${binnedStaticMAE.toFixed(1)} ms`);
console.log(`  Binned overall MAE  : ${binnedMAE.toFixed(1)} ms  (${(+(binnedStaticMAE-binnedMAE)).toFixed(1)} ms improvement)`);

// ─── Idea C: Exponentially-weighted long velocity (12 readings ≈ 3 min) ───────
console.log(`\n${'═'.repeat(70)}`);
console.log(`IDEA C — EW Long-Window Velocity (12 readings, sigmoid blend th=180s)`);
console.log('═'.repeat(70));

const EW_WINDOW = 12;
const EW_ALPHA  = 0.7;   // exponential weight decay per step back (0.7 = recent weight 30% higher than 1-step-older)
const SIG_TH    = 180;

function ewVelocity(history) {
    // history: array of {R, C}, most recent last. Compute weighted velocity (ms/s, positive = improving)
    if (history.length < 2) return null;
    let numerator = 0, denominator = 0;
    const n = Math.min(history.length, EW_WINDOW);
    // Use pairs: (history[i], history[n-1]) with weight EW_ALPHA^(n-1-i)
    const base = history[history.length - 1];
    let w = 1.0;
    for (let i = history.length - 2; i >= history.length - n; i--) {
        const older = history[i];
        const deltaT = older.R - base.R;  // seconds elapsed between them
        const deltaC = older.C - base.C;  // ms dropped (positive = improvement)
        if (deltaT > 0) {
            numerator   += w * deltaC;
            denominator += w * deltaT;
        }
        w *= EW_ALPHA;
    }
    return denominator > 0 ? numerator / denominator : null;
}

function sigmoidAlpha(R, th) {
    const centre = th / 2;
    const k = 6 / th;
    return 1 / (1 + Math.exp(k * (R - centre)));
}

const ewBuckets = new Map();
const ewStaticBuckets = new Map();

for (const { rows, finalCutoff } of sessions) {
    const history = [];
    for (const row of rows) {
        if (row.R === 0 || row.C <= finalCutoff) continue;
        const sp = staticPred(row.C, row.R);
        const vel = ewVelocity(history);
        let pred = sp;
        if (vel !== null && row.R <= SIG_TH) {
            const linearP = Math.min(row.C, Math.max(row.C * 0.5, row.C - vel * row.R));
            const alpha = sigmoidAlpha(row.R, SIG_TH);
            pred = (1 - alpha) * sp + alpha * linearP;
        }
        const bk = Math.round(row.R / BUCKET_SIZE) * BUCKET_SIZE;
        if (!ewBuckets.has(bk)) { ewBuckets.set(bk, []); ewStaticBuckets.set(bk, []); }
        ewBuckets.get(bk).push(pred - finalCutoff);
        ewStaticBuckets.get(bk).push(sp - finalCutoff);
        history.push({ R: row.R, C: row.C });
    }
}

console.log(`\n  ${'Time'.padEnd(10)} ${'Secs'.padEnd(6)} ${'Static MAE'.padEnd(13)} ${'EW-blend MAE'.padEnd(15)} Δ`);
console.log('  ' + '─'.repeat(60));
const allEWstatic = [], allEW = [];
for (const [bk, errs] of [...ewBuckets.entries()].sort((a,b)=>a[0]-b[0])) {
    const sErrs = ewStaticBuckets.get(bk) || [];
    if (errs.length < 3) continue;
    const sMAE = sErrs.reduce((s,e)=>s+Math.abs(e),0)/sErrs.length;
    const MAE  = errs.reduce((s,e)=>s+Math.abs(e),0)/errs.length;
    const d = sMAE - MAE;
    const sign = d >= 0 ? '+' : '';
    const mins = Math.floor(bk/60), secs = bk%60;
    const alpha = sigmoidAlpha(bk, SIG_TH).toFixed(3);
    console.log(`  ${`${mins}m ${String(secs).padStart(2,'0')}s`.padEnd(10)} ${String(bk).padEnd(6)} ${sMAE.toFixed(1).padEnd(13)} ${MAE.toFixed(1).padEnd(15)} ${sign}${d.toFixed(1)} ms  α=${alpha}`);
    allEWstatic.push(...sErrs); allEW.push(...errs);
}
const ewStaticMAE = allEWstatic.reduce((s,e)=>s+Math.abs(e),0)/allEWstatic.length;
const ewMAE       = allEW.reduce((s,e)=>s+Math.abs(e),0)/allEW.length;
console.log(`\n  Static overall MAE     : ${ewStaticMAE.toFixed(1)} ms`);
console.log(`  EW-blend overall MAE   : ${ewMAE.toFixed(1)} ms  (${(+(ewStaticMAE-ewMAE)).toFixed(1)} ms improvement)`);

// ─── Combined: AR + sigmoid blend ────────────────────────────────────────────
console.log(`\n${'═'.repeat(70)}`);
console.log(`COMBINED — AR(1) + sigmoid velocity blend`);
console.log('═'.repeat(70));

const comboBuckets = new Map();
const comboStaticBuckets = new Map();

for (const { rows, finalCutoff } of sessions) {
    const history = [];
    for (let i = 0; i < rows.length; i++) {
        const { R, C } = rows[i];
        if (R === 0 || C <= finalCutoff) continue;
        const sp = staticPred(C, R);

        // AR correction
        let pred = sp;
        if (i > 0) {
            const prev = rows[i - 1];
            const prevSP = staticPred(prev.C, prev.R);
            const residual = C - prevSP;
            pred = sp + bestLambda * residual;
            pred = Math.min(C, Math.max(C * 0.5, pred));
        }

        // Velocity blend on top of AR-corrected value
        const vel = ewVelocity(history);
        if (vel !== null && R <= SIG_TH) {
            const linearP = Math.min(C, Math.max(C * 0.5, C - vel * R));
            const alpha = sigmoidAlpha(R, SIG_TH);
            pred = (1 - alpha) * pred + alpha * linearP;
        }

        const bk = Math.round(R / BUCKET_SIZE) * BUCKET_SIZE;
        if (!comboBuckets.has(bk)) { comboBuckets.set(bk, []); comboStaticBuckets.set(bk, []); }
        comboBuckets.get(bk).push(pred - finalCutoff);
        comboStaticBuckets.get(bk).push(sp - finalCutoff);
        history.push({ R, C });
    }
}

console.log(`\n  ${'Time'.padEnd(10)} ${'Secs'.padEnd(6)} ${'Static MAE'.padEnd(13)} ${'Combined MAE'.padEnd(15)} Δ`);
console.log('  ' + '─'.repeat(60));
const allComboStatic = [], allCombo = [];
for (const [bk, errs] of [...comboBuckets.entries()].sort((a,b)=>a[0]-b[0])) {
    const sErrs = comboStaticBuckets.get(bk) || [];
    if (errs.length < 3) continue;
    const sMAE = sErrs.reduce((s,e)=>s+Math.abs(e),0)/sErrs.length;
    const MAE  = errs.reduce((s,e)=>s+Math.abs(e),0)/errs.length;
    const d = sMAE - MAE;
    const sign = d >= 0 ? '+' : '';
    const mins = Math.floor(bk/60), secs = bk%60;
    console.log(`  ${`${mins}m ${String(secs).padStart(2,'0')}s`.padEnd(10)} ${String(bk).padEnd(6)} ${sMAE.toFixed(1).padEnd(13)} ${MAE.toFixed(1).padEnd(15)} ${sign}${d.toFixed(1)} ms (${sign}${(d/sMAE*100).toFixed(1)}%)`);
    allComboStatic.push(...sErrs); allCombo.push(...errs);
}
const comboStaticMAE = allComboStatic.reduce((s,e)=>s+Math.abs(e),0)/allComboStatic.length;
const comboMAE       = allCombo.reduce((s,e)=>s+Math.abs(e),0)/allCombo.length;
const totalD = comboStaticMAE - comboMAE;
console.log(`\n  Static overall MAE     : ${comboStaticMAE.toFixed(1)} ms`);
console.log(`  Combined overall MAE   : ${comboMAE.toFixed(1)} ms  (+${totalD.toFixed(1)} ms, +${(totalD/comboStaticMAE*100).toFixed(1)}% improvement)`);
console.log(`\n  Components: AR λ=${bestLambda.toFixed(2)}, EW velocity (${EW_WINDOW} readings, decay=${EW_ALPHA}), sigmoid blend (th=${SIG_TH}s)`);
