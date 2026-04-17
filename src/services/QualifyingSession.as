namespace QualifyingSession
{
    ICotdApi@ cotdApi = null;
    NadeoCotdApi@ nadeoCotdApi = null;

    void RunLoop()
    {
        if (!state_configLoaded)
        {
            ConfigService::FetchAll();
        }

        LoadPlayersIfNeeded();
        LoadMapUidIfNeeded();
        LoadCurrentChallengeIdIfNeeded();

        array<SingleUserResultVM@> singleResultVMs = FetchResults(cotdApi);

        if (settings_showDivOneCutoff || settings_showCutoffPrediction)
        {
            CutoffService::AppendCutoffRows(singleResultVMs, cotdApi, state_currentChallengeid, state_currentMapUid, cast<CTrackMania>(GetApp()));
        }

        int secsRemaining = CutoffService::GetSecondsRemaining(cast<CTrackMania>(GetApp()));
        state_rankingModel = RankingController::BuildModel(singleResultVMs, secsRemaining);
        state_forceRefreshPlayers = false;
    }

    void LoadPlayersIfNeeded()
    {
        bool settingsChanged = state_settingsChanged || state_forceRefreshPlayers;
        state_settingsChanged = false;
        if (settingsChanged)
        {
            state_accountIds = {};
            PlayerLoaderService::LoadClubAndCustomPlayers();
            @cotdApi = ResolveCotdApi();
        }

        PlayerLoaderService::LoadFriends(settingsChanged);
    }

    void LoadCurrentChallengeIdIfNeeded()
    {    
        if (state_currentChallengeid == 0)
        {
            state_activeCupType = ResolveCupType(state_currentMapUid);
            state_currentChallengeid = nadeoCotdApi.GetCurrentChallengeIdByType(state_activeCupType);
        }
    }

    void AwaitRefresh()
    {
        float progress = 100;
        int progressBarInterval = 60;
        float refreshTime = 15000;
        while (refreshTime >= progress)
        {
            if (progress != 0)
            {
                state_refreshProgress = 1 - (progress / refreshTime);
            }
            progress = progress + progressBarInterval;
            sleep(progressBarInterval);
        }
    }

    ICotdApi@ ResolveCotdApi()
    {
        NadeoCotdApi nadeo;
        @nadeoCotdApi = nadeo;

        if (settings_cotdApi == CotdApiType::Nadeo)
        {
            return nadeoCotdApi;
        }
        MapMonitorCotdApi mapMonitor;
        return mapMonitor;
    }

    void LoadMapUidIfNeeded()
    {
        if (state_currentMapUid.Length == 0)
        {
            auto network = cast<CTrackManiaNetwork>(cast<CTrackMania>(GetApp()).Network);
            state_currentMapUid = network.ClientManiaAppPlayground.Playground.Map.MapInfo.MapUid;
        }
    }

    array<SingleUserResultVM@> FetchResults(ICotdApi@ cotdApi)
    {
        array<Result@> allResults = cotdApi.GetCurrentStandingForPlayers(state_accountIds, state_currentChallengeid, state_currentMapUid);
        
        // Capture time series snapshot BEFORE sorting
        CaptureTimeSnapshotFromResults(allResults);
        
        allResults.SortAsc();

        array<Result@> topResults = {};
        for (uint n = 0; n < numberOfPlayerDisplay && n < allResults.Length; n++)
        {
            topResults.InsertLast(allResults[n]);
        }

        return VMMapper::ToSingleUserResultVMs(topResults);
    }

    // Detects which cup type the current map belongs to by comparing the map UID
    // against the current COTW and Grand Enduro campaign maps.
    // Falls back to "cotd" if neither matches.
    // type strings match /api/cups-of-the-day?type=... parameter values.
    string ResolveCupType(const string &in mapUid)
    {
        string cotwMapUid = NadeoLiveServicesAPI::GetCotwMapUid();
        if (cotwMapUid.Length > 0 && mapUid == cotwMapUid)
        {
            return "cotw";
        }

        string grandEnduroMapUid = NadeoLiveServicesAPI::GetGrandEnduroMapUid();
        if (grandEnduroMapUid.Length > 0 && mapUid == grandEnduroMapUid)
        {
            return "grand_race";
        }

        return "cotd";
    }

    uint GetMaxTrackedPlayers()
    {
        if (settings_cotdApi == CotdApiType::Nadeo)
        {
            return 100;
        }
        if (settings_cotdApi == CotdApiType::MapMonitor)
        {
            return 1000;
        }
        return 0;
    }

    array<string> BuildDisplayModeList(const string &in clubName)
    {
        if (!settings_showClub && !settings_showFriends && !settings_showCustomPlayers)
        {
            return {"$F33No opponents selected!\n $FFFYou can select\n- Club\n- Friends\n- Custom Players"};
        }

        array<string> displayModeNames = {};
        if (settings_showClub)
        {
            displayModeNames.InsertLast(clubName);
        }
        if (settings_showFriends)
        {
            displayModeNames.InsertLast("Friends");
        }
        if (settings_showCustomPlayers)
        {
            displayModeNames.InsertLast("Custom");
        }

        return displayModeNames;
    }

    void CaptureTimeSnapshotFromResults(const array<Result@> &in allResults)
    {
        // Get seconds remaining in the qualifying session
        int secsRemaining = CutoffService::GetSecondsRemaining(cast<CTrackMania>(GetApp()));
        
        // Only record snapshots if data recording is enabled
        if (!settings_recordProgress)
        {
            return;
        }
        
        // Initialize time series for any new players on first capture
        for (uint i = 0; i < allResults.Length; i++)
        {
            Result@ r = allResults[i];
            PlayerTimeSeries@ ts = TimeSeriesService::GetPlayerTimeSeries(r.accountId);
            if (ts is null)
            {
                // Try to get the display name - it will be resolved eventually by VMMapper
                string displayName = "Player";
                @ts = PlayerTimeSeries(r.accountId, displayName);
                TimeSeriesService::InitializePlayer(r.accountId, displayName);
            }
        }
        
        // Record a snapshot for each tracked player
        TimeSeriesService::RecordSnapshot(allResults, secsRemaining);
        
        // Record the current cutoff progression
        int currentCutoff = TimeSeriesService::GetDiv1CutoffTime();
        if (currentCutoff > 0)
        {
            TimeSeriesService::RecordCutoffSnapshot(currentCutoff, secsRemaining);
        }
    }
}

