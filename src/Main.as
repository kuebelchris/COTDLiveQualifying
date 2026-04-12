// Global variables
int totalPlayers = 0;
array<string> accountIds;
UserResultVM vm = UserResultVM();
float refreshProgress = 0;

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

        COTDClubLiveUI::renderUI(vm, refreshProgress);
    }
#endif
}

void RenderMenu()
{
#if TMNEXT
    if(UI::MenuItem("\\$f0c\\$s" + Icons::Bold + "\\$z COTD Live Qualifying", "", windowVisible)) {
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
            QualifyingSession::Reset();
        }

        QualifyingSession::AwaitRefresh();
    }
#endif
}

// COTD, COTW, and Grand Enduro all use the same qualifier game mode script.
// TM_TimeAttackDaily_Online is the older name for the qualifier (pre-2023).
bool hasPermissionAndIsQualifyingRunning()
{

    return true;

    /*auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);
    auto server_info = cast<CTrackManiaNetworkServerInfo>(network.ServerInfo);
    string mode = server_info.CurGameModeStr;
    bool modeMatch = mode == "TM_COTDQualifications_Online"
                  || mode == "TM_TimeAttackDaily_Online";
    return Permissions::PlayOnlineCompetition()
        && network.ClientManiaAppPlayground !is null
        && network.ClientManiaAppPlayground.Playground !is null
        && network.ClientManiaAppPlayground.Playground.Map !is null
        && modeMatch;*/
}
