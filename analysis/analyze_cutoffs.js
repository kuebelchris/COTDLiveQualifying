// COTD Div1 Cutoff Prediction Formula Analysis
// Reads all qualifying snapshot files and fits a model:
//   predicted_final = current_cutoff * correction(seconds_remaining)
//   where correction(R) ≈ 1 - a * (R / TOTAL_SECONDS)^b
//
// Data format per line: HH:MM:SS, unix_timestamp, seconds_remaining, div1_cutoff_ms

'use strict';
const fs = require('fs');
const path = require('path');

const DATA_DIR = process.argv[2];
if (!DATA_DIR) {
    console.error('Usage: node analyze_cutoffs.js <data-dir>');
    process.exit(1);
}
const TOTAL_SECONDS = 840; // 14 minutes (empirical max ~840s remaining at start)

// ─── Parse all files ────────────────────────────────────────────────────────

const snapshots = []; // { secsRemaining, currentCutoff, finalCutoff, correction }
let filesLoaded = 0;
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
            return (!isNaN(secsRemaining) && !isNaN(cutoff) && cutoff > 0)
                ? { secsRemaining, cutoff }
                : null;
        })
        .filter(Boolean);

    if (rows.length < 5) { filesSkipped++; continue; }

    // Use last row's cutoff as "final" (secsRemaining should be 0 or near 0)
    const finalCutoff = rows[rows.length - 1].cutoff;
    const finalSecsRemaining = rows[rows.length - 1].secsRemaining;
    const totalSecsForFile = rows[0].secsRemaining; // first recorded value

    for (const row of rows) {
        // Skip the final snapshot itself (correction = 1.0, not informative for fitting)
        if (row.secsRemaining === 0) continue;
        if (row.cutoff <= finalCutoff) continue; // sanity: current must be ≥ final

        snapshots.push({
            file,
            secsRemaining: row.secsRemaining,
            currentCutoff: row.cutoff,
            finalCutoff,
            correction: finalCutoff / row.cutoff,  // always ≤ 1.0
            relativeRemaining: row.secsRemaining / TOTAL_SECONDS,
        });
    }

    filesLoaded++;
}

console.log(`\n=== Data Loading ===`);
console.log(`Files loaded : ${filesLoaded}`);
console.log(`Files skipped: ${filesSkipped}`);
console.log(`Total snapshots: ${snapshots.length}`);

// ─── Bucket analysis ─────────────────────────────────────────────────────────
// Bucket by 30-second intervals, compute mean correction factor per bucket

const BUCKET_SIZE = 30;
const buckets = new Map();

for (const s of snapshots) {
    const b = Math.round(s.secsRemaining / BUCKET_SIZE) * BUCKET_SIZE;
    if (!buckets.has(b)) buckets.set(b, []);
    buckets.get(b).push(s.correction);
}

console.log(`\n=== Correction Factor by Time Remaining ===`);
console.log(`${'Secs Remaining'.padEnd(20)} ${'Mean Correction'.padEnd(18)} ${'StdDev'.padEnd(12)} Count`);
console.log('─'.repeat(65));

const fittingPoints = []; // { x: R/840, y: mean_correction }

for (const [b, corrections] of [...buckets.entries()].sort((a, b) => a[0] - b[0])) {
    const n = corrections.length;
    const mean = corrections.reduce((acc, v) => acc + v, 0) / n;
    const variance = corrections.reduce((acc, v) => acc + (v - mean) ** 2, 0) / n;
    const std = Math.sqrt(variance);
    const x = b / TOTAL_SECONDS;
    console.log(`${String(b).padEnd(20)} ${mean.toFixed(6).padEnd(18)} ${std.toFixed(6).padEnd(12)} ${n}`);
    fittingPoints.push({ x, y: mean, std, n });
}

// ─── Curve fitting: three models compared ─────────────────────────────────────

// Helper: OLS on (lx, ly) bucket means, unweighted (each bucket counts equally)
function fitPowerLawOLS(pts, weighted) {
    const logPts = pts.filter(p => p.x > 0 && p.y < 1.0 - 1e-9).map(p => ({
        lx: Math.log(p.x),
        ly: Math.log(1 - p.y),
        n: p.n,
    }));
    const w = logPts.map(p => weighted ? p.n : 1);
    const sumW      = w.reduce((s, v) => s + v, 0);
    const sumWlx    = logPts.reduce((s, p, i) => s + w[i] * p.lx, 0);
    const sumWly    = logPts.reduce((s, p, i) => s + w[i] * p.ly, 0);
    const sumWlxlx  = logPts.reduce((s, p, i) => s + w[i] * p.lx * p.lx, 0);
    const sumWlxly  = logPts.reduce((s, p, i) => s + w[i] * p.lx * p.ly, 0);
    const denom = sumW * sumWlxlx - sumWlx * sumWlx;
    const b = (sumW * sumWlxly - sumWlx * sumWly) / denom;
    const a = Math.exp((sumWly - b * sumWlx) / sumW);
    return { a, b };
}

// Helper: compute RMSE of power-law model (correction = 1 - a*x^b) against all snapshots
function powerLawRmse(a, b) {
    let sumSq = 0;
    for (const s of snapshots) {
        const x = s.secsRemaining / TOTAL_SECONDS;
        const pred = s.currentCutoff * (1 - a * Math.pow(x, b));
        const err = pred - s.finalCutoff;
        sumSq += err * err;
    }
    return Math.sqrt(sumSq / snapshots.length);
}

// Model A: weighted by observation count (dominated by late-stage data)
const modelA = fitPowerLawOLS(fittingPoints, true);
// Model B: unweighted (each 30s bucket equals)
const modelB = fitPowerLawOLS(fittingPoints, false);

console.log(`\n=== Model Comparison: correction(R) = 1 - a * (R/840)^b ===`);
console.log(`\n  Model A (count-weighted OLS on bucket means):`);
console.log(`    a=${modelA.a.toFixed(6)}, b=${modelA.b.toFixed(6)}  →  RMSE=${powerLawRmse(modelA.a, modelA.b).toFixed(1)} ms`);
console.log(`  Model B (unweighted by bucket):`);
console.log(`    a=${modelB.a.toFixed(6)}, b=${modelB.b.toFixed(6)}  →  RMSE=${powerLawRmse(modelB.a, modelB.b).toFixed(1)} ms`);

// Model C: gradient descent on normalised bucket means to avoid scale issues
// Minimise: sum_i (pred_correction_i - actual_correction_i)^2
function gradientDescentPowerLaw(pts, a0, b0, lr = 0.001, steps = 200000) {
    let a = a0, b = b0;
    const validPts = pts.filter(p => p.x > 0 && p.y < 1.0);
    for (let step = 0; step < steps; step++) {
        let ga = 0, gb = 0;
        for (const p of validPts) {
            const xb = Math.pow(p.x, b);
            const predY = 1 - a * xb;
            const err = predY - p.y; // residual in correction space
            ga += 2 * err * (-xb);
            gb += (p.x > 0) ? 2 * err * (-a * xb * Math.log(p.x)) : 0;
        }
        ga /= validPts.length;
        gb /= validPts.length;
        a -= lr * ga;
        b -= lr * gb;
        if (a < 0.001) a = 0.001;
        if (b < 0.1)   b = 0.1;
        if (step % 50000 === 49999) lr *= 0.5;
    }
    return { a, b };
}

process.stdout.write('  Model C (gradient descent on bucket correction means): fitting...');
const modelC = gradientDescentPowerLaw(fittingPoints, modelB.a, modelB.b);
console.log(` done`);
console.log(`    a=${modelC.a.toFixed(6)}, b=${modelC.b.toFixed(6)}  →  RMSE=${powerLawRmse(modelC.a, modelC.b).toFixed(1)} ms`);

// Use the model with lowest raw RMSE
const models = [
    { label: 'A (count-weighted)', ...modelA, rmse: powerLawRmse(modelA.a, modelA.b) },
    { label: 'B (bucket-unweighted)', ...modelB, rmse: powerLawRmse(modelB.a, modelB.b) },
    { label: 'C (gradient descent)', ...modelC, rmse: powerLawRmse(modelC.a, modelC.b) },
];
const best = models.reduce((best, m) => m.rmse < best.rmse ? m : best, models[0]);
console.log(`\n  Best model: ${best.label}  (a=${best.a.toFixed(4)}, b=${best.b.toFixed(4)}, RMSE=${best.rmse.toFixed(1)} ms)`);

const a_fit = best.a;
const b_fit = best.b;

// ─── Residuals / accuracy ─────────────────────────────────────────────────────
// For each snapshot, compare predicted final vs actual final

console.log(`\n=== Prediction Accuracy by Time Remaining (best model) ===`);
console.log(`${'Time'.padEnd(12)} ${'Secs'.padEnd(8)} ${'Mean Err'.padEnd(12)} ${'MAE (ms)'.padEnd(14)} ${'RMSE (ms)'.padEnd(14)} ${'±95% CI'.padEnd(12)} Count`);
console.log('─'.repeat(80));

// Group errors by bucket
const errorBuckets = new Map();

for (const s of snapshots) {
    const x = s.secsRemaining / TOTAL_SECONDS;
    const correctionPredicted = 1 - a_fit * Math.pow(x, b_fit);
    const predictedFinal = s.currentCutoff * correctionPredicted;
    const error = predictedFinal - s.finalCutoff; // negative = undershoot

    const b = Math.round(s.secsRemaining / BUCKET_SIZE) * BUCKET_SIZE;
    if (!errorBuckets.has(b)) errorBuckets.set(b, []);
    errorBuckets.get(b).push(error);
}

const allRmses = [];
for (const [b, errors] of [...errorBuckets.entries()].sort((a, b) => a[0] - b[0])) {
    const n = errors.length;
    const meanErr = errors.reduce((acc, e) => acc + e, 0) / n;
    const meanAbsErr = errors.reduce((acc, e) => acc + Math.abs(e), 0) / n;
    const rmse = Math.sqrt(errors.reduce((acc, e) => acc + e * e, 0) / n);
    // 95% CI from normal approx: ±1.96 * std
    const std = Math.sqrt(errors.reduce((acc, e) => acc + (e - meanErr)**2, 0) / n);
    const ci95 = 1.96 * std;
    allRmses.push(...errors);
    const R = b;
    const mins = Math.floor(R / 60);
    const secs = R % 60;
    const timeStr = `${mins}m ${String(secs).padStart(2,'0')}s`;
    console.log(`${timeStr.padEnd(12)} ${String(b).padEnd(8)} ${meanErr.toFixed(1).padEnd(12)} ${meanAbsErr.toFixed(1).padEnd(14)} ${rmse.toFixed(1).padEnd(14)} ±${ci95.toFixed(1).padEnd(10)} ${n}`);
}

const overallMeanAbsErr = allRmses.reduce((acc, e) => acc + Math.abs(e), 0) / allRmses.length;
const overallRmse = Math.sqrt(allRmses.reduce((acc, e) => acc + e * e, 0) / allRmses.length);
console.log(`\n  Overall mean absolute error : ${overallMeanAbsErr.toFixed(1)} ms`);
console.log(`  Overall RMSE               : ${overallRmse.toFixed(1)} ms`);

// ─── Key milestone predictions ────────────────────────────────────────────────
// Show what the formula predicts at useful plugin milestones

console.log(`\n=== Prediction Formula at Key Milestones ===`);
console.log(`${'Time Remaining'.padEnd(20)} ${'R/840'.padEnd(12)} ${'correction(R)'.padEnd(18)} Formula`);
console.log('─'.repeat(72));

const milestones = [840, 720, 600, 480, 360, 300, 240, 180, 120, 60, 30, 0];
for (const R of milestones) {
    const x = R / TOTAL_SECONDS;
    const correction = R === 0 ? 1.0 : Math.max(0, 1 - a_fit * Math.pow(x, b_fit));
    const timeStr = `${Math.floor(R / 60)}m ${String(R % 60).padStart(2, '0')}s`;
    console.log(`${timeStr.padEnd(20)} ${x.toFixed(4).padEnd(12)} ${correction.toFixed(6).padEnd(18)} F = C * ${correction.toFixed(4)}`);
}

// ─── Compact formula summary ──────────────────────────────────────────────────
console.log(`\n${'═'.repeat(70)}`);
console.log(`FINAL FORMULA`);
console.log(`${'═'.repeat(70)}`);
console.log(`\n  Given: current_cutoff C (ms) and seconds_remaining R (0–840)`);
console.log(`\n  correction  =  1 - ${a_fit.toFixed(4)} × (R ÷ 840)^${b_fit.toFixed(4)}`);
console.log(`  predicted_final  =  C × correction`);
console.log(`\n  AngelScript version:`);
console.log(`    float r = float(secsRemaining) / 840.0f;`);
console.log(`    float correction = 1.0f - ${a_fit.toFixed(4)}f * Math::Pow(r, ${b_fit.toFixed(4)}f);`);
console.log(`    int predictedFinal = int(currentCutoff * correction);`);
console.log(``);
