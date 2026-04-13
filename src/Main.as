void Render()
{
#if TMNEXT

    if (hasPermissionAndIsQualifyingRunning())
    {
        if (!UI::IsGameUIVisible() && settings_hideIfUIHidden)
        {
            return;
        }

        if(!UI::IsOverlayShown() && onlyOnOverlay)
        {
            return;
        }

        RankingController::Render();
    }
#endif
}

void RenderMenu()
{
#if TMNEXT
    if(UI::MenuItem("\\$f0c\\$s" + Icons::Trophy + "\\$z COTD Live Qualifying", "", windowVisible)) {
        windowVisible = !windowVisible;
    }
#endif
}

void Main()
{  
#if TMNEXT    
    NadeoServices::AddAudience("NadeoLiveServices");

    while (!NadeoServices::IsAuthenticated("NadeoLiveServices"))
    {
        yield();
    }

    while(true)
    {
        if (hasPermissionAndIsQualifyingRunning())
        {
            QualifyingSession::RunLoop();
        }
        else
        {
            PluginState::Reset();
        }

        QualifyingSession::AwaitRefresh();
    }
#endif
}

void OnSettingsChanged()
{
    state_settingsChanged = true;
}

// COTD, COTW, and Grand Enduro all use the same qualifier game mode script.
bool hasPermissionAndIsQualifyingRunning()
{
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);
    auto server_info = cast<CTrackManiaNetworkServerInfo>(network.ServerInfo);
    string mode = server_info.CurGameModeStr;
    return Permissions::PlayOnlineCompetition()
        && network.ClientManiaAppPlayground !is null
        && network.ClientManiaAppPlayground.Playground !is null
        && network.ClientManiaAppPlayground.Playground.Map !is null
        && mode == "TM_COTDQualifications_Online";
}
