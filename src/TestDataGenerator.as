// Test data generator for development and debugging
// Use TestDataGenerator::GenerateTestData() to populate time series with realistic demo data

namespace TestDataGenerator
{
    const array<string> TEST_PLAYER_NAMES = {
        "KuebelChris",
        "SpeedRunner123",
        "TimeTrialKing",
        "QualiGrinder",
        "FastLapMaster",
        "TrackDemon",
        "RacePro2024",
        "CompetitiveEdge",
        "SolidDriver",
        "SkillfulPilot"
    };
    
    const array<int> TEST_PLAYER_TIMES_MS = {
        85000, 85200, 85500, 86000, 86100,
        86300, 86500, 87000, 87200, 87500
    };

    void GenerateTestData()
    {
        // Clear existing data
        TimeSeriesService::Reset();
        
        // Generate synthetic time progression for multiple players
        for (uint i = 0; i < TEST_PLAYER_NAMES.Length; i++)
        {
            string accountId = "test-account-" + i;
            string playerName = TEST_PLAYER_NAMES[i];
            int baseTimeMs = TEST_PLAYER_TIMES_MS[i];
            
            TimeSeriesService::InitializePlayer(accountId, playerName);
            GeneratePlayerTimeSeries(accountId, baseTimeMs, i);
        }
        
        // Set Div 1 cutoff to the middle of all final times
        int cutoffTime = CalculateMiddleTimeFromFinalTimes();
        TimeSeriesService::SetDiv1CutoffTime(cutoffTime);
        
        // Generate cutoff progression (starts high, gradually improves)
        GenerateCutoffProgression(cutoffTime);
    }

    // Extreme test data with dramatic time variations for debugging
    void GenerateExtremeTestData()
    {
        TimeSeriesService::Reset();
        
        for (uint i = 0; i < TEST_PLAYER_NAMES.Length; i++)
        {
            string accountId = "test-extreme-" + i;
            string playerName = TEST_PLAYER_NAMES[i];
            
            TimeSeriesService::InitializePlayer(accountId, playerName);
            
            PlayerTimeSeries@ series = TimeSeriesService::GetPlayerTimeSeries(accountId);
            if (series !is null)
            {
                // Each player has a vastly different improvement pattern
                int position = 0;
                for (int secsRemaining = 840; secsRemaining >= 0; secsRemaining -= 15)
                {
                    int timeMs;
                    
                    if (i == 0)
                    {
                        // Dramatic improvement from 90s to 80s
                        timeMs = 90000 - int((840.0f - secsRemaining) / 840.0f * 10000.0f);
                    }
                    else if (i == 1)
                    {
                        // Steady improvement 85s to 80s
                        timeMs = 85000 - int((840.0f - secsRemaining) / 840.0f * 5000.0f);
                    }
                    else if (i == 2)
                    {
                        // No improvement, stays at 88s
                        timeMs = 88000;
                    }
                    else if (i == 3)
                    {
                        // Fast start then plateau
                        float prog = (840.0f - secsRemaining) / 840.0f;
                        timeMs = 87000 - int(Math::Min(prog * 8000.0f, 6000.0f));
                    }
                    else if (i == 4)
                    {
                        // Slow start then fast improvement
                        float prog = (840.0f - secsRemaining) / 840.0f;
                        timeMs = 86000 - int(prog * prog * 10000.0f);
                    }
                    else
                    {
                        // Oscillating improvement
                        float prog = (840.0f - secsRemaining) / 840.0f;
                        int baseImprovement = int(prog * 7000.0f);
                        int oscillation = int(Math::Sin(prog * 10.0f) * 1000.0f);
                        timeMs = 85000 - baseImprovement + oscillation;
                    }
                    
                    int rank = int(i) + 1;
                    series.AddSnapshot(Math::Max(timeMs, 75000), secsRemaining, rank);
                    position++;
                }
            }
        }
        
        // Set Div 1 cutoff to the middle of all final times
        int cutoffTime = CalculateMiddleTimeFromFinalTimes();
        TimeSeriesService::SetDiv1CutoffTime(cutoffTime);
        
        // Generate cutoff progression (starts high, gradually improves)
        GenerateCutoffProgression(cutoffTime);
    }

    void GenerateCutoffProgression(const int &in finalCutoffTime)
    {
        // Starting cutoff time (higher than final)
        int startingCutoff = finalCutoffTime + 5000;
        
        // Generate cutoff snapshots every 15 seconds
        for (int secsRemaining = 840; secsRemaining >= 0; secsRemaining -= 15)
        {
            float progressRatio = float(840 - secsRemaining) / 840.0f;
            // Gradual improvement toward final cutoff with diminishing returns
            int improvement = int((finalCutoffTime - startingCutoff) * (1.0f - Math::Pow(1.0f - progressRatio, 2.0f)));
            int cutoffAtTime = startingCutoff + improvement;
            
            TimeSeriesService::RecordCutoffSnapshot(cutoffAtTime, secsRemaining);
        }
    }

    int CalculateMiddleTimeFromFinalTimes()
    {
        array<int> finalTimes;
        array<PlayerTimeSeries@> allSeries = TimeSeriesService::GetAllTimeSeries();
        
        // Collect the final time for each player (last snapshot)
        for (uint i = 0; i < allSeries.Length; i++)
        {
            PlayerTimeSeries@ series = allSeries[i];
            if (series.snapshots.Length > 0)
            {
                TimeSnapshot@ lastSnap = series.snapshots[series.snapshots.Length - 1];
                if (lastSnap.timeMs > 0)
                {
                    finalTimes.InsertLast(lastSnap.timeMs);
                }
            }
        }
        
        // If no valid times, return a default
        if (finalTimes.Length == 0)
        {
            return 84000;
        }
        
        // Sort times to find median
        for (uint i = 0; i < finalTimes.Length; i++)
        {
            for (uint j = i + 1; j < finalTimes.Length; j++)
            {
                if (finalTimes[j] < finalTimes[i])
                {
                    int temp = finalTimes[i];
                    finalTimes[i] = finalTimes[j];
                    finalTimes[j] = temp;
                }
            }
        }
        
        // Return median
        return finalTimes[finalTimes.Length / 2];
    }

    void GeneratePlayerTimeSeries(const string &in accountId, const int &in baseTimeMs, const uint &in playerIndex)
    {
        PlayerTimeSeries@ series = TimeSeriesService::GetPlayerTimeSeries(accountId);
        if (series is null)
        {
            return;
        }

        // Simulate 15 seconds of data (840 seconds) with a snapshot every 15 seconds
        // This creates a realistic progression showing players improving (lowering their times)
        
        // Generate snapshots across the qualifying period
        for (int secsRemaining = 840; secsRemaining >= 0; secsRemaining -= 15)
        {
            int snapshotTimeMs = CalculateTimeAtPoint(baseTimeMs, secsRemaining, playerIndex);
            int rank = int(playerIndex) + 1;  // Rank based on player index
            series.AddSnapshot(snapshotTimeMs, secsRemaining, rank);
        }
    }

    // Calculate a realistic time progression for a player across the session
    // Players generally improve their times as the session progresses (time decreases)
    int CalculateTimeAtPoint(const int &in baseTimeMs, const int &in secsRemaining, const uint &in playerIndex)
    {
        // Progression: time improves as seconds remaining decreases
        // Formula: base_time - (improvement_curve * 0-840 range)
        
        float progressRatio = float(840 - secsRemaining) / 840.0f;
        
        // Add variance per player to make it more realistic
        float characteristicVariance = 0.3f + (float(playerIndex) * 0.05f);
        
        // Improvement curve: faster improvement early, slower later (realistic)
        float improvementCurve = characteristicVariance * Math::Sqrt(progressRatio);
        
        // Some players might not improve as much
        float maxImprovement = (float(playerIndex) % 3 == 0) ? 1500.0f : 2000.0f;
        
        int improvement = int(improvementCurve * maxImprovement);
        
        // Add small random-like noise for realism
        int noise = int(Math::Sin(float(playerIndex) * 12.7f + float(secsRemaining) * 0.01f) * 200.0f);
        
        int resultTime = baseTimeMs - improvement + noise;
        
        // Clamp to reasonable bounds
        resultTime = Math::Max(resultTime, baseTimeMs - 2500);
        resultTime = Math::Min(resultTime, baseTimeMs + 500);
        
        return resultTime;
    }

    // Alternative: Generate a minimal test case with just 3 players and fewer snapshots (faster testing)
    void GenerateMinimalTestData()
    {
        TimeSeriesService::Reset();
        
        array<string> names = {"Player A", "Player B", "Player C"};
        array<int> times = {85000, 86000, 87000};
        
        for (uint i = 0; i < names.Length; i++)
        {
            string accountId = "test-min-" + i;
            TimeSeriesService::InitializePlayer(accountId, names[i]);
            
            PlayerTimeSeries@ series = TimeSeriesService::GetPlayerTimeSeries(accountId);
            if (series !is null)
            {
                // Snapshots every 15 seconds
                for (int secsRemaining = 840; secsRemaining >= 0; secsRemaining -= 15)
                {
                    int timeMs = times[i] - int((840 - secsRemaining) * 0.5f);
                    int rank = int(i) + 1;
                    series.AddSnapshot(timeMs, secsRemaining, rank);
                }
            }
        }
        
        // Set Div 1 cutoff to the middle of all final times
        int cutoffTime = CalculateMiddleTimeFromFinalTimes();
        TimeSeriesService::SetDiv1CutoffTime(cutoffTime);
        
        // Generate cutoff progression
        GenerateCutoffProgression(cutoffTime);
    }

    // Generate test data with a steep improvement curve (players getting significantly faster)
    void GenerateAggressiveImprovementTestData()
    {
        TimeSeriesService::Reset();
        
        for (uint i = 0; i < TEST_PLAYER_NAMES.Length; i++)
        {
            string accountId = "test-aggressive-" + i;
            string playerName = TEST_PLAYER_NAMES[i];
            int baseTimeMs = TEST_PLAYER_TIMES_MS[i];
            
            TimeSeriesService::InitializePlayer(accountId, playerName);
            
            PlayerTimeSeries@ series = TimeSeriesService::GetPlayerTimeSeries(accountId);
            if (series !is null)
            {
                for (int secsRemaining = 840; secsRemaining >= 0; secsRemaining -= 15)
                {
                    float progressRatio = float(840 - secsRemaining) / 840.0f;
                    // Aggressive curve: quadratic improvement
                    int improvement = int(progressRatio * progressRatio * 3000.0f);
                    int timeMs = baseTimeMs - improvement;
                    int rank = int(i) + 1;
                    series.AddSnapshot(Math::Max(timeMs, baseTimeMs - 3000), secsRemaining, rank);
                }
            }
        }
        
        // Set Div 1 cutoff to the middle of all final times
        int cutoffTime = CalculateMiddleTimeFromFinalTimes();
        TimeSeriesService::SetDiv1CutoffTime(cutoffTime);
        
        // Generate cutoff progression
        GenerateCutoffProgression(cutoffTime);
    }

    // Generate test data with a realistic competitive scenario
    // (multiple players with varying improvement rates, some stalling, some improving)
    void GenerateRealisticCompetitiveTestData()
    {
        TimeSeriesService::Reset();
        
        for (uint i = 0; i < TEST_PLAYER_NAMES.Length; i++)
        {
            string accountId = "test-competitive-" + i;
            string playerName = TEST_PLAYER_NAMES[i];
            int baseTimeMs = TEST_PLAYER_TIMES_MS[i];
            
            TimeSeriesService::InitializePlayer(accountId, playerName);
            
            PlayerTimeSeries@ series = TimeSeriesService::GetPlayerTimeSeries(accountId);
            if (series !is null)
            {
                int currentTimeMs = baseTimeMs;
                
                for (int secsRemaining = 840; secsRemaining >= 0; secsRemaining -= 15)
                {
                    // Each player has different behaviors
                    if (i % 4 == 0)
                    {
                        // Steady improver
                        currentTimeMs -= 50;
                    }
                    else if (i % 4 == 1)
                    {
                        // Burst improver (improves quickly then plateaus)
                        if (secsRemaining > 420)
                        {
                            currentTimeMs -= 150;
                        }
                        else
                        {
                            currentTimeMs -= 20;
                        }
                    }
                    else if (i % 4 == 2)
                    {
                        // Slow grind
                        currentTimeMs -= 30;
                    }
                    else
                    {
                        // No improvement for a while, then a sudden improvement
                        if (secsRemaining < 180)
                        {
                            currentTimeMs -= 200;
                        }
                        else if (secsRemaining < 600)
                        {
                            currentTimeMs -= 10;
                        }
                    }
                    
                    int rank = int(i) + 1;
                    series.AddSnapshot(currentTimeMs, secsRemaining, rank);
                }
            }
        }
        
        // Set Div 1 cutoff to the middle of all final times
        int cutoffTime = CalculateMiddleTimeFromFinalTimes();
        TimeSeriesService::SetDiv1CutoffTime(cutoffTime);
        
        // Generate cutoff progression
        GenerateCutoffProgression(cutoffTime);
    }
}
