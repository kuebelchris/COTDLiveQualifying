namespace TimeSeriesService
{
    // Array of player time series data (includes special "CUTOFF_PROGRESSION" entry)
    array<PlayerTimeSeries@> g_timeseries;
    int g_div1CutoffTimeMs = -1;
    
    void Reset()
    {
        g_timeseries.RemoveRange(0, g_timeseries.Length);
        g_div1CutoffTimeMs = -1;
    }
    
    // Initialize or get time series for a player
    void InitializePlayer(const string &in accountId, const string &in displayName)
    {
        if (GetPlayerTimeSeries(accountId) is null)
        {
            g_timeseries.InsertLast(PlayerTimeSeries(accountId, displayName));
        }
    }
    
    // Initialize cutoff progression tracker if not already done
    void InitializeCutoffProgression()
    {
        if (GetPlayerTimeSeries("CUTOFF_PROGRESSION") is null)
        {
            g_timeseries.InsertLast(PlayerTimeSeries("CUTOFF_PROGRESSION", "Cutoff Progression"));
        }
    }
    
    // Record current standings - called once per poll
    void RecordSnapshot(const array<Result@> &in results, const int &in secsRemaining)
    {
        for (uint i = 0; i < results.Length; i++)
        {
            Result@ r = results[i];
            PlayerTimeSeries@ ts = GetPlayerTimeSeries(r.accountId);
            if (ts !is null)
            {
                ts.AddSnapshot(r.time, secsRemaining, r.rank);
            }
        }
    }
    
    // Get all time series data
    array<PlayerTimeSeries@> GetAllTimeSeries()
    {
        return g_timeseries;
    }
    
    // Get time series for a specific player
    PlayerTimeSeries@ GetPlayerTimeSeries(const string &in accountId)
    {
        for (uint i = 0; i < g_timeseries.Length; i++)
        {
            if (g_timeseries[i].accountId == accountId)
            {
                return g_timeseries[i];
            }
        }
        return null;
    }
    
    // Set Div 1 cutoff time for the chart
    void SetDiv1CutoffTime(const int &in cutoffTimeMs)
    {
        g_div1CutoffTimeMs = cutoffTimeMs;
    }
    
    // Get Div 1 cutoff time
    int GetDiv1CutoffTime()
    {
        return g_div1CutoffTimeMs;
    }
    
    // Record a cutoff progression snapshot (track how cutoff changes over time)
    void RecordCutoffSnapshot(const int &in cutoffTimeMs, const int &in secsRemaining)
    {
        InitializeCutoffProgression();
        PlayerTimeSeries@ cutoffTs = GetPlayerTimeSeries("CUTOFF_PROGRESSION");
        if (cutoffTs !is null)
        {
            cutoffTs.AddSnapshot(cutoffTimeMs, secsRemaining, 0);
        }
    }
    
    // Get cutoff progression times
    array<int> GetCutoffProgressionTimes()
    {
        PlayerTimeSeries@ cutoffTs = GetPlayerTimeSeries("CUTOFF_PROGRESSION");
        array<int> result = {};
        if (cutoffTs !is null)
        {
            for (uint i = 0; i < cutoffTs.snapshots.Length; i++)
            {
                result.InsertLast(cutoffTs.snapshots[i].timeMs);
            }
        }
        return result;
    }
    
    // Get cutoff progression seconds remaining
    array<int> GetCutoffProgressionSecsRemaining()
    {
        PlayerTimeSeries@ cutoffTs = GetPlayerTimeSeries("CUTOFF_PROGRESSION");
        array<int> result = {};
        if (cutoffTs !is null)
        {
            for (uint i = 0; i < cutoffTs.snapshots.Length; i++)
            {
                result.InsertLast(cutoffTs.snapshots[i].secsRemaining);
            }
        }
        return result;
    }
}
