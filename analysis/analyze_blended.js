// COTD Cutoff — Blended Velocity Model Analysis
//
// Tests whether blending the static power-law with a short-term linear
// velocity extrapolation (from the last N consecutive snapshots) beats
// the static model alone.
//
// Static model (current, baseline):
//   predicted = currentCutoff * (1 - A * (R / T)^B)
//
// Velocity model:
//   v = average drop rate (ms/sec) over last N snapshot pairs in this session
//   linearPred = currentCutoff + v * R   (v is negative when cutoff is falling)
//
// Blended model:
//   alpha(R) = blend weight on velocity; 0 for large R, increases near end
//   predicted = (1 - alpha) * staticPred + alpha * linearPred
//
// We compare several alpha profiles and blend thresholds against the dataset.
//
// Usage: node analyze_blended.js <data-dir>

'use strict';
const fs = require('fs');
const path = require('path');

const DATA_DIR = process.argv[2];
if (!DATA_DIR) {
    console.error('Usage: node analyze_blended.js <data-dir>');
    process.exit(1);
}

const T = 840;
const A = 0.0824;
const B = 1.5962;
const BUCKET_SIZE = 30;

// ─── Load sessions ────────────────────────────────────────────────────────────

const sessions = [];
let filesSkipped = 0;

const files = fs.readdirSync(DATA_DIR).filter(f => f.endsWith('.txt')).sort();

for (const file of files) {
    const raw = fs.readFileSync(path.join(DATA_DIR, file), 'utf8').trim();
    if (!raw) { filesSkipped++; continue; }

    const rows = raw.split('\n')
        .map(line => {
            const p = line.trim().split(',');
            if (p.length < 4) return null;
            const secsRemaining = parseInt(p[2], 10);
            const cutoff = parseInt(p[3], 10);
            if (isNaN(secsRemaining) || isNaN(cutoff) || cutoff <= 0) return null;
            return { secsRemaining, cutoff };
        })
        .filter(Boolean);

    if (rows.length < 5) { filesSkipped++; continue; }

    const finalCutoff = rows[rows.length - 1].cutoff;
    sessions.push({ file, rows, finalCutoff });
}

console.log(`\nFiles loaded : ${sessions.length}`);
console.log(`Files skipped: ${filesSkipped}`);

// ─── Compute static prediction ────────────────────────────────────────────────

function staticPred(currentCutoff, R) {
    if (R <= 0) return currentCutoff;
    const r = R / T;
    let correction = 1 - A * Math.pow(r, B);
    if (correction < 0.5) correction = 0.5;
    if (correction > 1.0) correction = 1.0;
    return currentCutoff * correction;
}

// ─── Build evaluation dataset: each entry has snapshot + recent velocity ──────
// We simulate the plugin: maintain a rolling window of the last N readings
// per session and compute velocity at each snapshot.

function buildDataset(velocityWindow) {
    const entries = [];  // { R, currentCutoff, finalCutoff, velMsPerSec: null | number }

    for (const session of sessions) {
        const { rows, finalCutoff } = session;
        const history = [];  // last velocityWindow readings: { secsRemaining, cutoff }

        for (const row of rows) {
            if (row.secsRemaining === 0) continue;
            if (row.cutoff <= finalCutoff) continue;  // sanity

            // Compute velocity from history
            let velMsPerSec = null;
            if (history.length >= velocityWindow) {
                // oldest reading in our window
                const oldest = history[history.length - velocityWindow];
                const deltaT = oldest.secsRemaining - row.secsRemaining; // elapsed secs between
                const deltaC = oldest.cutoff - row.cutoff;               // drop in ms (positive = improved)
                if (deltaT > 0) {
                    velMsPerSec = deltaC / deltaT;  // ms/sec cutoff improvement rate (positive = improving)
                }
            }

            entries.push({
                R: row.secsRemaining,
                currentCutoff: row.cutoff,
                finalCutoff,
                velMsPerSec,
            });

            history.push({ secsRemaining: row.secsRemaining, cutoff: row.cutoff });
        }
    }
    return entries;
}

// ─── Alpha profile: how much weight to put on velocity near end of qualifying ──

// Profile "linear-T":   alpha = max(0, (threshold - R) / threshold)
// Profile "quadratic-T": alpha = max(0, ((threshold - R) / threshold)^2
// Profile "step-T":     alpha = R <= threshold ? 1 : 0

function alphaLinear(R, threshold) {
    if (R >= threshold) return 0;
    return (threshold - R) / threshold;
}
function alphaQuadratic(R, threshold) {
    if (R >= threshold) return 0;
    const t = (threshold - R) / threshold;
    return t * t;
}
function alphaSigmoid(R, threshold) {
    // Logistic centred at threshold/2, steep enough to be ~0 at threshold
    const centre = threshold / 2;
    const k = 6 / threshold;
    return 1 / (1 + Math.exp(k * (R - centre)));
}

// ─── Evaluate a blended model: compute MAE per bucket and overall ─────────────

function evaluate(entries, alphaFn, threshold, label) {
    const static_only_buckets  = new Map();
    const blended_buckets      = new Map();
    const velocity_only_buckets = new Map();

    for (const e of entries) {
        const { R, currentCutoff, finalCutoff, velMsPerSec } = e;
        const buckKey = Math.round(R / BUCKET_SIZE) * BUCKET_SIZE;

        // Static-only error
        const sp = staticPred(currentCutoff, R);
        const staticErr = sp - finalCutoff;

        if (!static_only_buckets.has(buckKey)) static_only_buckets.set(buckKey, []);
        static_only_buckets.get(buckKey).push(staticErr);

        // Only compute blended/velocity errors if velocity was available
        if (velMsPerSec === null) continue;

        // Linear velocity prediction: project current improvement rate to end
        // velMsPerSec is positive when cutoff is falling (improving)
        const linearP = currentCutoff - velMsPerSec * R;
        // Clamp: can't predict above current (worse) or below reasonable floor
        const linearClamped = Math.min(currentCutoff, Math.max(currentCutoff * 0.5, linearP));

        const alpha = alphaFn(R, threshold);
        const blendedP = (1 - alpha) * sp + alpha * linearClamped;

        const blendedErr   = blendedP   - finalCutoff;
        const velocityErr  = linearClamped - finalCutoff;

        if (!blended_buckets.has(buckKey))       blended_buckets.set(buckKey, []);
        if (!velocity_only_buckets.has(buckKey)) velocity_only_buckets.set(buckKey, []);
        blended_buckets.get(buckKey).push(blendedErr);
        velocity_only_buckets.get(buckKey).push(velocityErr);
    }

    return { static_only_buckets, blended_buckets, velocity_only_buckets };
}

// ─── Grid search over all meaningful combinations ─────────────────────────────

const velocityWindows = [1, 2, 3];   // number of prior readings for velocity
const thresholds      = [60, 90, 120, 150, 180];  // seconds
const alphaProfiles   = [
    { name: 'linear',    fn: alphaLinear },
    { name: 'quadratic', fn: alphaQuadratic },
    { name: 'sigmoid',   fn: alphaSigmoid },
];

console.log(`\n${'═'.repeat(85)}`);
console.log(`GRID SEARCH: Velocity window × Threshold × Alpha profile`);
console.log('═'.repeat(85));
console.log(`${'Config'.padEnd(40)} ${'Static MAE'.padEnd(14)} ${'Blended MAE'.padEnd(14)} Δ`);
console.log('─'.repeat(85));

let globalBest = { label: '', blendedMAE: Infinity, staticMAE: 0 };
const results = [];

for (const vw of velocityWindows) {
    const dataset = buildDataset(vw);
    const hasVelocity = dataset.filter(e => e.velMsPerSec !== null);

    for (const ap of alphaProfiles) {
        for (const th of thresholds) {
            const { static_only_buckets, blended_buckets } = evaluate(dataset, ap.fn, th, '');

            // Only compare buckets where we have blended data
            let totalStaticErr = 0, totalBlendedErr = 0, n = 0;
            for (const [bk, bErrs] of blended_buckets.entries()) {
                const sErrs = static_only_buckets.get(bk);
                if (!sErrs) continue;
                totalBlendedErr += bErrs.reduce((s, e) => s + Math.abs(e), 0);
                totalStaticErr  += sErrs.slice(0, bErrs.length).reduce((s, e) => s + Math.abs(e), 0);
                n += bErrs.length;
            }
            if (n === 0) continue;

            const staticMAE  = totalStaticErr  / n;
            const blendedMAE = totalBlendedErr / n;
            const delta = staticMAE - blendedMAE;
            const label = `vw=${vw} th=${th}s alpha=${ap.name}`;
            const sign = delta >= 0 ? '+' : '';
            console.log(`${label.padEnd(40)} ${staticMAE.toFixed(1).padEnd(14)} ${blendedMAE.toFixed(1).padEnd(14)} ${sign}${delta.toFixed(1)} ms`);

            results.push({ label, staticMAE, blendedMAE, vw, th, ap });
            if (blendedMAE < globalBest.blendedMAE) {
                globalBest = { label, blendedMAE, staticMAE, vw, th, ap };
            }
        }
    }
}

// ─── Detailed breakdown for the best config (and static baseline) ─────────────

console.log(`\n${'═'.repeat(80)}`);
console.log(`BEST CONFIG: ${globalBest.label}`);
console.log('═'.repeat(80));

const bestDataset = buildDataset(globalBest.vw);
const { static_only_buckets, blended_buckets, velocity_only_buckets } =
    evaluate(bestDataset, globalBest.ap.fn, globalBest.th, globalBest.label);

console.log(`\n${'Time'.padEnd(10)} ${'Secs'.padEnd(6)} ${'Static MAE'.padEnd(13)} ${'Blended MAE'.padEnd(15)} ${'Δ'.padEnd(18)} Count`);
console.log('─'.repeat(75));

const allStatic = [], allBlended = [];

for (const [bk, bErrs] of [...blended_buckets.entries()].sort((a, b) => a[0] - b[0])) {
    const sErrs = static_only_buckets.get(bk) || [];
    if (bErrs.length < 3) continue;

    const staticMAE   = sErrs.reduce((s, e) => s + Math.abs(e), 0) / sErrs.length;
    const blendedMAE  = bErrs.reduce((s, e) => s + Math.abs(e), 0) / bErrs.length;
    const delta = staticMAE - blendedMAE;
    const pct   = (delta / staticMAE * 100).toFixed(1);
    const sign  = delta >= 0 ? '+' : '';

    const mins    = Math.floor(bk / 60);
    const secs    = bk % 60;
    const timeStr = `${mins}m ${String(secs).padStart(2, '0')}s`;

    const alphaAtBk = globalBest.ap.fn(bk, globalBest.th).toFixed(3);
    console.log(
        `${timeStr.padEnd(10)} ${String(bk).padEnd(6)}` +
        ` ${staticMAE.toFixed(1).padEnd(13)} ${blendedMAE.toFixed(1).padEnd(15)}` +
        ` ${sign}${delta.toFixed(1)} ms (${sign}${pct}%) α=${alphaAtBk}`.padEnd(18) +
        ` ${bErrs.length}`
    );

    allStatic.push(...sErrs);
    allBlended.push(...bErrs);
}

const overallStatic  = allStatic.reduce((s, e)  => s + Math.abs(e), 0) / allStatic.length;
const overallBlended = allBlended.reduce((s, e) => s + Math.abs(e), 0) / allBlended.length;
const overallDelta   = overallStatic - overallBlended;
const overallPct     = (overallDelta / overallStatic * 100).toFixed(1);
const sign = overallDelta >= 0 ? '+' : '';

console.log('─'.repeat(75));
console.log(`\n  Static model overall MAE   : ${overallStatic.toFixed(1)} ms   (${allStatic.length} snapshots)`);
console.log(`  Blended model overall MAE  : ${overallBlended.toFixed(1)} ms   (${allBlended.length} snapshots)`);
console.log(`  Improvement                : ${sign}${overallDelta.toFixed(1)} ms (${sign}${overallPct}%)`);

// ─── AngelScript implementation hint ─────────────────────────────────────────

console.log(`\n${'═'.repeat(70)}`);
console.log(`ANGELSCRIPT IMPLEMENTATION HINT`);
console.log('═'.repeat(70));
console.log(`
  Best config: velocity window = ${globalBest.vw} reading(s), blend threshold = ${globalBest.th}s, alpha = ${globalBest.ap.name}
  Plugin polls ~every 15s, so velocity window = ${globalBest.vw} means using the last ${globalBest.vw} prior reading(s).

  In QualifyingSession / CutoffService, store the previous cutoff snapshot:
    int prevCutoffMs = 0;
    int prevSecsRemaining = 0;

  Then in PredictFinalCutoff (called per 15s refresh):

    // Compute static prediction (always available)
    float r = float(secsRemaining) / 840.0f;
    float correction = 1.0f - ${A}f * Math::Pow(r, ${B}f);
    correction = Math::Clamp(correction, 0.5f, 1.0f);
    int sp = int(float(currentCutoffMs) * correction);

    // Blend in velocity prediction only inside the window
    if (secsRemaining <= ${globalBest.th} && prevSecsRemaining > secsRemaining && prevCutoffMs > currentCutoffMs)
    {
        float deltaT = float(prevSecsRemaining - secsRemaining);
        float deltaC = float(prevCutoffMs - currentCutoffMs);  // positive = improving
        float velPerSec = deltaC / deltaT;
        int linearP = Math::Clamp(
            currentCutoffMs - int(velPerSec * float(secsRemaining)),
            currentCutoffMs / 2, currentCutoffMs);

        // alpha = ${globalBest.ap.name === 'linear' ? '(threshold - R) / threshold' : globalBest.ap.name === 'quadratic' ? '((threshold - R) / threshold)^2' : 'sigmoid'}
        float alpha = ${
            globalBest.ap.name === 'linear'    ? `(float(${globalBest.th} - secsRemaining)) / ${globalBest.th}.0f;` :
            globalBest.ap.name === 'quadratic' ? `float t = float(${globalBest.th} - secsRemaining) / ${globalBest.th}.0f; float alpha = t * t;` :
            `1.0f / (1.0f + Math::Exp(${(6/globalBest.th).toFixed(4)}f * float(secsRemaining - ${Math.round(globalBest.th/2)}))); // sigmoid`
        }
        return int((1.0f - alpha) * float(sp) + alpha * float(linearP));
    }
    return sp;
`);
