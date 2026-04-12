namespace CutoffService
{
    // Total qualifying duration in seconds (14 minutes).
    // Used to normalise the time-remaining value in the prediction formula.
    const float QUALIFYING_DURATION_SECS = 840.0f;

    // Maximum seconds remaining at which the prediction is shown.
    // Predictions beyond 5 minutes have high uncertainty (>500 ms MAE).
    const int PREDICTION_WINDOW_SECS = 300;

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

    // Predicts the final Div 1 cutoff time using a power-law decay model fitted
    // across 78 recorded qualifying sessions (3 777 snapshots).
    //
    // Model:  correction = 1 - 0.0824 * (R / 840)^1.5962
    //         predicted  = currentCutoffMs * correction
    //
    // Accuracy (mean absolute error by time remaining):
    //   5 min left : ~236 ms MAE   |   3 min left : ~100 ms MAE
    //   2 min left :  ~54 ms MAE   |   1 min left :  ~23 ms MAE
    int PredictFinalCutoff(int currentCutoffMs, int secsRemaining)
    {
        if (secsRemaining <= 0)
        {
            return currentCutoffMs;
        }
        float r = float(secsRemaining) / QUALIFYING_DURATION_SECS;
        float correction = 1.0f - 0.0824f * Math::Pow(r, 1.5962f);
        if (correction < 0.5f)
        {
            correction = 0.5f;
        }
        if (correction > 1.0f)
        {
            correction = 1.0f;
        }
        return int(float(currentCutoffMs) * correction);
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

        if (settings_showCutoffPrediction)
        {
            int secsRemaining = GetSecondsRemaining(app);
            if (secsRemaining >= 0 && secsRemaining <= PREDICTION_WINDOW_SECS)
            {
                int predictedCutoff = PredictFinalCutoff(cutoff.time, secsRemaining);
                singleResultVMs.InsertLast(VMMapper::ToSingleUserResultCutoffPredictionVM(predictedCutoff));
                rowAdded = true;
            }
        }

        if (rowAdded)
        {
            singleResultVMs.SortAsc();
        }
    }
}
