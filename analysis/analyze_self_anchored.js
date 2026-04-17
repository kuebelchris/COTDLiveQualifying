// Self-Anchored Power Law Model — Comparison Analysis
//
// Tests whether anchoring the prediction to the *observed* improvement within
// a session beats the static population-average model.
//
// Static model (current):
//   predicted = currentCutoff * (1 - A * (R / T)^B)
//   where A=0.0824, B=1.5962, T=840, R=secsRemaining
//
// Self-anchored model (candidate):
//   Assumes the cutoff follows  f(t) = C_offset - K * t^b  over elapsed time t.
//   Given first reading at t_first (elapsed) with C_first, and current reading
//   at t_current with C_current, estimate K from the observed drop:
//
//     K = (C_first - C_current) / (t_current^b - t_first^b)
//
//   Then predict the final cutoff at t = T:
//
//     C_predicted = C_current - K * (T^b - t_current^b)
//
//   This adapts to the actual pace of improvement in each session.
//
// Usage: node analyze_self_anchored.js <data-dir>

'use strict';
const fs = require('fs');
const path = require('path');

const DATA_DIR = process.argv[2];
if (!DATA_DIR) {
    console.error('Usage: node analyze_self_anchored.js <data-dir>');
    process.exit(1);
}

const T = 840;               // qualifying duration in seconds
const STATIC_A = 0.0824;
const STATIC_B = 1.5962;
const BUCKET_SIZE = 30;      // seconds per accuracy bucket

// Minimum additional seconds elapsed since first reading before we trust the
// self-anchored estimate — avoids noisy K when the denominator is tiny.
const MIN_ELAPSED_DELTA = 30;

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
            return { secsRemaining, cutoff, tElapsed: T - secsRemaining };
        })
        .filter(Boolean);

    if (rows.length < 5) { filesSkipped++; continue; }

    const finalCutoff = rows[rows.length - 1].cutoff;
    sessions.push({ file, rows, finalCutoff });
}

console.log(`\nFiles loaded : ${sessions.length}`);
console.log(`Files skipped: ${filesSkipped}`);

// ─── Evaluate both models over all sessions ───────────────────────────────────

function evaluateModels(b_anchored) {
    const staticBuckets  = new Map();  // buckKey → errors[]
    const anchoredBuckets = new Map();

    for (const session of sessions) {
        const { rows, finalCutoff } = session;
        const anchor = rows[0];           // first reading in the session
        const t_first    = Math.max(anchor.tElapsed, 1);
        const C_first    = anchor.cutoff;
        const t_first_b  = Math.pow(t_first, b_anchored);
        const T_b        = Math.pow(T, b_anchored);

        for (const row of rows) {
            if (row === anchor) continue;     // can't anchor to itself
            if (row.secsRemaining === 0) continue;
            if (row.cutoff <= finalCutoff) continue;  // sanity: current ≥ final

            const R = row.secsRemaining;
            const C_current  = row.cutoff;
            const t_current  = row.tElapsed;

            // ── Static model ────────────────────────────────────────────────
            const r = R / T;
            const correctionStatic = Math.max(0.5, Math.min(1.0, 1 - STATIC_A * Math.pow(r, STATIC_B)));
            const predStatic = C_current * correctionStatic;

            // ── Self-anchored model ─────────────────────────────────────────
            const t_current_b = Math.pow(t_current, b_anchored);
            const denom = t_current_b - t_first_b;

            let predAnchored = null;
            if (denom > 0 && (t_current - t_first) >= MIN_ELAPSED_DELTA) {
                const K = (C_first - C_current) / denom;
                // If K <= 0, the cutoff hasn't improved yet — fall back to static
                if (K > 0) {
                    const raw = C_current - K * (T_b - t_current_b);
                    // Clamp: final can't be above current cutoff or below 0
                    predAnchored = Math.min(C_current, Math.max(0, raw));
                }
            }

            const buckKey = Math.round(R / BUCKET_SIZE) * BUCKET_SIZE;

            if (!staticBuckets.has(buckKey))   staticBuckets.set(buckKey, []);
            staticBuckets.get(buckKey).push(predStatic - finalCutoff);

            if (predAnchored !== null) {
                if (!anchoredBuckets.has(buckKey)) anchoredBuckets.set(buckKey, []);
                anchoredBuckets.get(buckKey).push(predAnchored - finalCutoff);
            }
        }
    }

    return { staticBuckets, anchoredBuckets };
}

// ─── Find optimal b for the self-anchored model ───────────────────────────────

process.stdout.write('\nSearching for optimal b (self-anchored)...');
let bestB = STATIC_B;
let bestMAE = Infinity;

for (let bi = 0; bi <= 50; bi++) {
    const b = 0.5 + bi * 0.05;  // range: 0.5 → 3.0
    const { anchoredBuckets } = evaluateModels(b);
    const allErrs = [...anchoredBuckets.values()].flat();
    if (allErrs.length === 0) continue;
    const mae = allErrs.reduce((s, e) => s + Math.abs(e), 0) / allErrs.length;
    if (mae < bestMAE) { bestMAE = mae; bestB = b; }
}
console.log(` done  →  best b = ${bestB.toFixed(2)}, MAE = ${bestMAE.toFixed(1)} ms`);

// ─── Full comparison at both static_b and best_b ─────────────────────────────

for (const [label, b] of [['Static B (1.5962)', STATIC_B], [`Optimal B (${bestB.toFixed(2)})`, bestB]]) {
    const { staticBuckets, anchoredBuckets } = evaluateModels(b);

    console.log(`\n${'═'.repeat(80)}`);
    console.log(`SELF-ANCHORED MODEL — b = ${b.toFixed(4)}  (${label})`);
    console.log('═'.repeat(80));
    console.log(`${'Time'.padEnd(10)} ${'Secs'.padEnd(6)} ${'Static MAE'.padEnd(13)} ${'Anchored MAE'.padEnd(15)} ${'Δ improvement'.padEnd(16)} Count`);
    console.log('─'.repeat(75));

    const allStatic   = [];
    const allAnchored = [];

    for (const [buckKey, sErrs] of [...staticBuckets.entries()].sort((a, b) => a[0] - b[0])) {
        const aErrs = anchoredBuckets.get(buckKey);
        if (!aErrs || aErrs.length < 3) continue;

        const staticMAE   = sErrs.reduce((s, e) => s + Math.abs(e), 0) / sErrs.length;
        const anchoredMAE = aErrs.reduce((s, e) => s + Math.abs(e), 0) / aErrs.length;
        const delta = staticMAE - anchoredMAE;
        const pct   = (delta / staticMAE * 100).toFixed(1);
        const sign  = delta >= 0 ? '+' : '';

        const mins    = Math.floor(buckKey / 60);
        const secs    = buckKey % 60;
        const timeStr = `${mins}m ${String(secs).padStart(2, '0')}s`;

        console.log(
            `${timeStr.padEnd(10)} ${String(buckKey).padEnd(6)}` +
            ` ${staticMAE.toFixed(1).padEnd(13)} ${anchoredMAE.toFixed(1).padEnd(15)}` +
            ` ${sign}${delta.toFixed(1)} ms (${sign}${pct}%)`.padEnd(16) +
            ` ${aErrs.length}`
        );

        allStatic.push(...sErrs);
        allAnchored.push(...aErrs);
    }

    const overallStaticMAE   = allStatic.reduce((s, e)   => s + Math.abs(e), 0) / allStatic.length;
    const overallAnchoredMAE = allAnchored.reduce((s, e) => s + Math.abs(e), 0) / allAnchored.length;
    const overallDelta = overallStaticMAE - overallAnchoredMAE;
    const overallPct   = (overallDelta / overallStaticMAE * 100).toFixed(1);

    console.log('─'.repeat(75));
    console.log(`\n  Static model overall MAE   : ${overallStaticMAE.toFixed(1)} ms   (${allStatic.length} snapshots)`);
    console.log(`  Self-anchored overall MAE  : ${overallAnchoredMAE.toFixed(1)} ms   (${allAnchored.length} snapshots)`);
    const sign = overallDelta >= 0 ? '+' : '';
    console.log(`  Improvement                : ${sign}${overallDelta.toFixed(1)} ms (${sign}${overallPct}%)`);
}

// ─── AngelScript formula hint ─────────────────────────────────────────────────

const b = bestB;
console.log(`\n${'═'.repeat(70)}`);
console.log(`ANGELSCRIPT IMPLEMENTATION HINT (b = ${b.toFixed(4)})`);
console.log('═'.repeat(70));
console.log(`
  // In QualifyingSession, store the first valid cutoff reading:
  //   int initialCutoffMs = cutoff.time;   // set once, never reset within session
  //
  // Then in CutoffService::PredictFinalCutoff():
  float b = ${b.toFixed(4)}f;
  float T = 840.0f;
  float t_first    = float(T - firstSecsRemaining);   // elapsed when first seen
  float t_current  = float(T - secsRemaining);        // elapsed now
  float t_first_b  = Math::Pow(Math::Max(1.0f, t_first), b);
  float t_current_b = Math::Pow(t_current, b);
  float T_b        = Math::Pow(T, b);
  float denom = t_current_b - t_first_b;
  if (denom <= 0.0f) return currentCutoffMs;          // not enough history yet
  float K = float(initialCutoffMs - currentCutoffMs) / denom;
  if (K <= 0.0f) return currentCutoffMs;              // no improvement observed
  int predicted = currentCutoffMs - int(K * (T_b - t_current_b));
  return Math::Clamp(predicted, 0, currentCutoffMs);
`);
