namespace CutoffService
{
    // Total qualifying duration in seconds (14 minutes).
    // Used to normalise the time-remaining value in the prediction formula.
    const float QUALIFYING_DURATION_SECS = 840.0f;

    // Minimum number of cutoff readings required before the AR correction activates.
    // At ~15 s per poll this is a ~45 s warm-up, which avoids noisy early-session estimates.
    const int AR_MIN_READINGS = 4;

    // Session-scoped AR state — reset via ResetArState() on each new qualifying session.
    int ar_prevCutoffMs = 0;
    int ar_prevSecsRemaining = 0;
    int ar_readingCount = 0;

    void ResetArState()
    {
        ar_prevCutoffMs = 0;
        ar_prevSecsRemaining = 0;
        ar_readingCount = 0;
    }

    // Returns the number of seconds remaining in the current qualifier,
    // derived from the game's own RulesStateEndTime / GameTime fields.
    // Returns -1 when the playground or arena state is not available.
    int GetSecondsRemaining(CTrackMania@ app)
    {
        auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
        if (cp is null || cp.Arena is null || cp.Arena.Rules is null)
        {
            return -1;
        }
        uint endTime = cp.Arena.Rules.RulesStateEndTime;
        if (endTime == 0)
        {
            return -1;
        }
        uint gameTime = app.Network.PlaygroundInterfaceScriptHandler.GameTime;
        if (endTime <= gameTime)
        {
            return 0;
        }
        return int((endTime - gameTime) / 1000);
    }

    // Predicts the final Div 1 cutoff time using a power-law decay model with
    // AR(1) residual correction, fitted across 78 recorded qualifying sessions.
    //
    // Step 1 — Static power-law baseline:
    //   correction = 1 - a * (R / 840)^b
    //   predicted  = currentCutoffMs * correction
    //
    // Step 2 — AR(1) correction (after AR_MIN_READINGS warm-up):
    //   spPrev = staticPred(prevCutoffMs, prevSecsRemaining)
    //   residual = currentCutoffMs - spPrev   (negative = session improving faster than average)
    //   predicted = staticPred(current) + lambda * residual
    //
    // The residual captures per-session bias: if this session's cutoff has been
    // dropping faster than the population average, that trend is projected forward.
    //
    // Accuracy (mean absolute error by time remaining, AR model):
    //   5 min left : ~177 ms MAE   |   3 min left :  ~81 ms MAE
    //   2 min left :  ~57 ms MAE   |   1 min left :  ~36 ms MAE
    int PredictFinalCutoff(int currentCutoffMs, int secsRemaining)
    {
        if (secsRemaining <= 0)
        {
            return currentCutoffMs;
        }

        // Step 1: static prediction for the current reading
        float r = float(secsRemaining) / QUALIFYING_DURATION_SECS;
        float sp = float(currentCutoffMs) * Math::Clamp(
            1.0f - ConfigService::g_predictionConfig.a * Math::Pow(r, ConfigService::g_predictionConfig.b),
            0.5f, 1.0f);

        // Step 2: AR(1) correction once the warm-up readings are available
        if (ar_readingCount >= AR_MIN_READINGS
            && ar_prevSecsRemaining > secsRemaining
            && ar_prevCutoffMs > 0)
        {
            float rp = float(ar_prevSecsRemaining) / QUALIFYING_DURATION_SECS;
            float spPrev = float(ar_prevCutoffMs) * Math::Clamp(
                1.0f - ConfigService::g_predictionConfig.a * Math::Pow(rp, ConfigService::g_predictionConfig.b),
                0.5f, 1.0f);
            float residual = float(currentCutoffMs) - spPrev;
            float predicted = sp + ConfigService::g_predictionConfig.lambda * residual;
            return int(Math::Clamp(predicted, float(currentCutoffMs) * 0.5f, float(currentCutoffMs)));
        }

        return int(sp);
    }

    void AppendCutoffRows(
        array<SingleUserResultVM@> &inout singleResultVMs,
        ICotdApi@ cotdApi,
        const int &in challengeId,
        const string &in mapId,
        CTrackMania@ app
    ) {
        Result@ cutoff = cotdApi.GetDiv1CutoffTime(challengeId, mapId);
        if (@cutoff is null)
        {
            return;
        }

        bool rowAdded = false;

        if (settings_showDivOneCutoff)
        {
            singleResultVMs.InsertLast(VMMapper::ToSingleUserResultCutoffVM(cutoff));
            rowAdded = true;
        }

        int secsRemaining = GetSecondsRemaining(app);

        if (settings_showCutoffPrediction
            && secsRemaining >= 0
            && secsRemaining <= ConfigService::g_predictionConfig.windowSecs)
        {
            int predictedCutoff = PredictFinalCutoff(cutoff.time, secsRemaining);
            singleResultVMs.InsertLast(VMMapper::ToSingleUserResultCutoffPredictionVM(predictedCutoff));
            rowAdded = true;
        }

        // Always update AR state so warm-up accumulates regardless of the prediction window.
        if (secsRemaining >= 0)
        {
            ar_readingCount++;
            ar_prevCutoffMs = cutoff.time;
            ar_prevSecsRemaining = secsRemaining;
        }

        if (rowAdded)
        {
            singleResultVMs.SortAsc();
        }
    }
}
