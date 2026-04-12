namespace QualifyingSession
{
    ICotdApi@ cotdApi = null;
    NadeoCotdApi@ nadeoCotdApi = null;

    void RunLoop()
    {
        bool settingsChanged = checkSettingsChanged();
        print("RunLoop: settingsChanged=" + settingsChanged);
        if (settingsChanged)
        {
            accountIds = {};
            @cotdApi = ResolveCotdApi();
        }

        PlayerLoader::LoadAll(settingsChanged);
        print("RunLoop: accountIds.Length=" + accountIds.Length);

        string mapid = GetCurrentMapUid();
        print("RunLoop: mapid=" + mapid);

        if (state_currentChallengeid == 0)
        {
            state_activeCupType = ResolveCupType(mapid);
            print("RunLoop: resolving challenge for cupType=" + state_activeCupType);
            state_currentChallengeid = nadeoCotdApi.GetCurrentChallengeIdByType(state_activeCupType);
            print("RunLoop: challengeid=" + state_currentChallengeid);
        }

        array<SingleUserResultVM@> singleResultVMs = BuildResultVMs(cotdApi, mapid);

        if (settings_showDivOneCutoff || settings_showCutoffPrediction)
        {
            CutoffDisplay::AppendCutoffRows(singleResultVMs, cotdApi, state_currentChallengeid, mapid, cast<CTrackMania>(GetApp()));
        }

        SyncDisplayState();
        vm = VMMapper::ToUserResultVM(BuildDisplayModeList(state_currentClubName), singleResultVMs);
        state_forceRefreshPlayers = false;
    }

    void Reset()
    {
        state_currentChallengeid = 0;
        state_activeCupType = "cotd";
        vm = UserResultVM();
        accountIds = {};
        totalPlayers = 0;
        state_forceRefreshPlayers = true;
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
                refreshProgress = 1 - (progress / refreshTime);
            }
            progress = progress + progressBarInterval;
            sleep(progressBarInterval);
        }
    }

    ICotdApi@ ResolveCotdApi()
    {
        NadeoCotdApi nadeo;
        @nadeoCotdApi = nadeo;

        if (settings_cotdApi == CotdApi::Nadeo)
        {
            return nadeoCotdApi;
        }
        MapMonitorCotdApi mapMonitor;
        return mapMonitor;
    }

    string GetCurrentMapUid()
    {
        auto network = cast<CTrackManiaNetwork>(cast<CTrackMania>(GetApp()).Network);
        return network.ClientManiaAppPlayground.Playground.Map.MapInfo.MapUid;
    }

    array<SingleUserResultVM@> BuildResultVMs(ICotdApi@ cotdApi, const string &in mapid)
    {
        array<Result@> allResults = cotdApi.GetCurrentStandingForPlayers(accountIds, state_currentChallengeid, mapid);
        allResults.SortAsc();

        array<Result@> topResults = {};
        for (uint n = 0; n < numberOfPlayerDisplay && n < allResults.Length; n++)
        {
            topResults.InsertLast(allResults[n]);
        }

        return VMMapper::ToSingleUserResultVMs(topResults);
    }

    void SyncDisplayState()
    {
        state_showClub = settings_showClub;
        state_currentClubId = settings_clubId;
        state_showFriends = settings_showFriends;
        state_showCustom = settings_showCustomPlayers;
        state_customPlayerList = settings_customPlayers;
        state_showDivOneCutoff = settings_showDivOneCutoff;
        state_showCutoffPrediction = settings_showCutoffPrediction;
        state_cotdApi = settings_cotdApi;
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
        if (settings_cotdApi == CotdApi::Nadeo)
        {
            return 100;
        }
        if (settings_cotdApi == CotdApi::MapMonitor)
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
}
