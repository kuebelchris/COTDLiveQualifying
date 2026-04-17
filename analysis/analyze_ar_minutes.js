// AR(1) model — per-minute MAE from 10 min remaining, with activation guard analysis
// Usage: node analyze_ar_minutes.js <data-dir>
'use strict';
const fs = require('fs');
const path = require('path');
const DATA_DIR = process.argv[2];
if (!DATA_DIR) { console.error('Usage: node analyze_ar_minutes.js <data-dir>'); process.exit(1); }

const T = 840, A = 0.0824, B = 1.5962, LAMBDA = 0.45;
const MIN_READINGS_BEFORE_AR = 4;  // require this many readings before activating AR

function staticPred(C, R) {
    if (R <= 0) return C;
    const r = R / T;
    return C * Math.max(0.5, Math.min(1.0, 1 - A * Math.pow(r, B)));
}

// Load
const sessions = [];
for (const file of fs.readdirSync(DATA_DIR).filter(f => f.endsWith('.txt')).sort()) {
    const rows = fs.readFileSync(path.join(DATA_DIR, file), 'utf8').trim().split('\n')
        .map(l => { const p = l.trim().split(','); const R=parseInt(p[2]),C=parseInt(p[3]); return (!isNaN(R)&&!isNaN(C)&&C>0)?{R,C}:null; }).filter(Boolean);
    if (rows.length < 5) continue;
    sessions.push({ rows, finalCutoff: rows[rows.length - 1].C });
}
console.log(`Sessions: ${sessions.length}\n`);

// Evaluate AR(1) with activation guard, bucket by 60s
const staticBuckets = new Map(), arBuckets = new Map();
let totalReadingsUsedAR = 0, totalReadingsSkippedAR = 0;

for (const { rows, finalCutoff } of sessions) {
    let readingCount = 0;
    for (let i = 0; i < rows.length; i++) {
        const { R, C } = rows[i];
        if (R === 0 || C <= finalCutoff) continue;
        readingCount++;

        const bk = Math.floor(R / 60) * 60;  // minute bucket: floor to whole minute
        if (!staticBuckets.has(bk)) { staticBuckets.set(bk, []); arBuckets.set(bk, []); }

        const sp = staticPred(C, R);
        staticBuckets.get(bk).push(sp - finalCutoff);

        // AR: only after MIN_READINGS_BEFORE_AR readings and a valid prior snapshot
        if (i > 0 && readingCount >= MIN_READINGS_BEFORE_AR) {
            const prev = rows[i - 1];
            const prevSP = staticPred(prev.C, prev.R);
            const residual = C - prevSP;
            let arP = sp + LAMBDA * residual;
            arP = Math.min(C, Math.max(C * 0.5, arP));
            arBuckets.get(bk).push(arP - finalCutoff);
            totalReadingsUsedAR++;
        } else {
            arBuckets.get(bk).push(sp - finalCutoff);  // fall back to static while warming up
            totalReadingsSkippedAR++;
        }
    }
}

console.log(`AR activation guard: ${MIN_READINGS_BEFORE_AR} readings (~${(MIN_READINGS_BEFORE_AR-1)*15}s warm-up)`);
console.log(`AR used: ${totalReadingsUsedAR} | Warm-up fallback: ${totalReadingsSkippedAR}\n`);

// Display from 10 min down
console.log('═'.repeat(80));
console.log('Per-minute MAE from 10 minutes remaining');
console.log('═'.repeat(80));
console.log(`${'Time left'.padEnd(12)} ${'Secs'.padEnd(6)} ${'Static MAE'.padEnd(13)} ${'AR MAE'.padEnd(13)} ${'Δ ms'.padEnd(10)} ${'Δ %'.padEnd(10)} Count`);
console.log('─'.repeat(80));

const displayCandidates = [];  // candidates for "start showing prediction" threshold
const allS = [], allAR = [];

for (let R = 600; R >= 0; R -= 60) {
    const sErrs = staticBuckets.get(R) || [];
    const aErrs = arBuckets.get(R) || [];
    if (aErrs.length === 0) continue;

    const sMAE = sErrs.reduce((s,e)=>s+Math.abs(e),0)/sErrs.length;
    const aMAE = aErrs.reduce((s,e)=>s+Math.abs(e),0)/aErrs.length;
    const d = sMAE - aMAE;
    const pct = (d/sMAE*100).toFixed(1);
    const sign = d >= 0 ? '+' : '';
    const mins = Math.floor(R/60), secs = R%60;
    const timeStr = `${mins}m ${String(secs).padStart(2,'0')}s`;

    // Tag display threshold suggestion
    let tag = '';
    if (aMAE <= 50)  tag = ' ◀ <50ms';
    else if (aMAE <= 100) tag = ' ◀ <100ms';
    else if (aMAE <= 200) tag = ' ◀ <200ms';

    console.log(`${timeStr.padEnd(12)} ${String(R).padEnd(6)} ${sMAE.toFixed(0).padEnd(13)} ${aMAE.toFixed(0).padEnd(13)} ${(sign+d.toFixed(0)).padEnd(10)} ${(sign+pct+'%').padEnd(10)} ${aErrs.length}${tag}`);
    displayCandidates.push({ R, aMAE, sMAE });
    allS.push(...sErrs); allAR.push(...aErrs);
}

const totalS  = allS.reduce((s,e)=>s+Math.abs(e),0)/allS.length;
const totalAR = allAR.reduce((s,e)=>s+Math.abs(e),0)/allAR.length;
console.log('─'.repeat(80));
console.log(`${'OVERALL (0-10min)'.padEnd(18)} ${totalS.toFixed(0).padEnd(13)} ${totalAR.toFixed(0).padEnd(13)}`);

// Suggestion: first minute where AR MAE drops below a fraction of typical cutoff spread
// Cutoff spreads across sessions vary, but < 200ms before 5 min, < 100ms before 3 min
console.log('\n═'.repeat(80));
console.log('\nDisplay threshold recommendation:');
console.log('─'.repeat(80));
for (const t of [500, 300, 200, 150, 100, 50]) {
    const first = displayCandidates.find(c => c.aMAE <= t);
    if (first) {
        const mins = Math.floor(first.R/60);
        const secs = first.R%60;
        console.log(`  MAE first drops below ${String(t).padStart(4)} ms at : ${mins}m ${String(secs).padStart(2,'0')}s remaining  (${first.aMAE.toFixed(0)} ms AR MAE)`);
    }
}

console.log('\n─'.repeat(80));
console.log('\nFormula complexity check (in-game calculation per refresh):');
console.log(`
  Given: currentCutoffMs (C), secsRemaining (R), prevCutoffMs (Cp), prevSecsRemaining (Rp)

  Step 1 — Static prediction of current (always):
    float r  = float(R)  / 840.0f;
    float sp = float(C)  * Math::Clamp(1.0f - 0.0824f * Math::Pow(r,  1.5962f), 0.5f, 1.0f);

  Step 2 — Static prediction of previous reading (only after 4 readings):
    float rp  = float(Rp) / 840.0f;
    float spP = float(Cp) * Math::Clamp(1.0f - 0.0824f * Math::Pow(rp, 1.5962f), 0.5f, 1.0f);

  Step 3 — AR correction:
    float residual = float(C) - spP;
    float predicted = sp + 0.45f * residual;
    predicted = Math::Clamp(predicted, float(C) * 0.5f, float(C));

  Total: 2× Math::Pow, 2× multiply, 1× add, 2× clamp.
  This is ~the same complexity as what's already in the plugin today (1× Math::Pow).
`);
