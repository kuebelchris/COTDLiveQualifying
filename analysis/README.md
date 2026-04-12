# COTD Div 1 Cutoff Analysis

This folder contains the tooling to fit a prediction formula from recorded COTD qualifying sessions.

## How data gets collected

The plugin logs a snapshot every ~15 seconds while qualifying is running. Each session produces one `.txt` file named `YY_MM_DD.txt` inside:

```
%localappdata%\..\OpenplanetNext\PluginStorage\COTDLiveQualifying\
```

Each line in the file has four comma-separated fields:

```
HH:MM:SS, unix_timestamp, seconds_remaining, div1_cutoff_ms
```

Example:
```
19:07:22,1706551642,526,40158
```

To accumulate a better dataset, simply play (or observe) more COTDs with the plugin running. Each new `.txt` file is automatically picked up by the analysis script.

---

## Prerequisites

- [Node.js](https://nodejs.org/) (v18 or newer)

No additional npm packages are required — the script uses only the Node.js standard library.

---

## Running the analysis

The quickest way is to run the included PowerShell helper:

```powershell
.\analysis\fit-formula.ps1
```

It runs `analyze_cutoffs.js`, prints the full analysis to the terminal, and then prints just the final formula so you can copy it directly into the plugin.

To run the script manually:

```powershell
node .\analysis\analyze_cutoffs.js
```

---

## What the script does

1. **Loads all `.txt` files** from the data directory and parses every snapshot.
2. **Computes the correction factor** for each snapshot:  
   `correction = final_cutoff / current_cutoff`  
   This is always ≤ 1.0 because the cutoff only improves (decreases) over time.
3. **Groups snapshots into 30-second buckets** and computes the mean correction per bucket.
4. **Fits three competing models** of the form `correction(R) = 1 - a × (R / 840)^b`:
   - **Model A** — weighted OLS on bucket means (weights = observation count per bucket)
   - **Model B** — unweighted OLS on bucket means (each 30s bucket counts equally)
   - **Model C** — gradient descent directly minimising prediction error across bucket means
5. **Selects the best model** (lowest raw RMSE across all snapshots).
6. **Reports prediction accuracy** per 30-second bucket — mean error, mean absolute error, RMSE, and a ±95 % confidence interval.
7. **Prints the formula** in both human-readable and AngelScript forms ready to paste into the plugin.

---

## Updating the plugin formula

After running the analysis, the output ends with a block like:

```
══════════════════════════════════════════════════════════════════════
FINAL FORMULA
══════════════════════════════════════════════════════════════════════

  Given: current_cutoff C (ms) and seconds_remaining R (0–840)

  correction  =  1 - 0.0553 × (R ÷ 840)^1.5717
  predicted_final  =  C × correction

  AngelScript version:
    float r = float(secsRemaining) / 840.0f;
    float correction = 1.0f - 0.0553f * Math::Pow(r, 1.5717f);
    int predictedFinal = int(currentCutoff * correction);
```

Open `src/services/CutoffDisplay.as` and update the two constants in `PredictFinalCutoff`:

```angelscript
float correction = 1.0f - 0.0553f * Math::Pow(r, 1.572f);
//                         ^^^^^^                ^^^^^
//                           a                    b
```

Replace `0.0553` with the new `a` value and `1.572` with the new `b` value.

---

## Understanding the accuracy table

The accuracy table shows how reliable the prediction is at each point in qualifying:

| Column | Meaning |
|--------|---------|
| `Mean Err` | Average signed error (negative = formula undershoots the final cutoff) |
| `MAE` | Mean absolute error — the typical prediction error in milliseconds |
| `RMSE` | Root mean squared error — penalises large outliers more |
| `±95% CI` | 95 % confidence interval width around the prediction |

**Rule of thumb:** predictions are reliable during the **last 5 minutes** (≤ 300 s remaining). Before that, variance is high because different maps see very different improvement rates early in qualifying.

---

## Files

| File | Purpose |
|------|---------|
| `analyze_cutoffs.js` | Full analysis script — loads data, fits models, reports accuracy |
| `fit-formula.ps1` | PowerShell helper — runs the script and prints only the formula |
| `README.md` | This file |
