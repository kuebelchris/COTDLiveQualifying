// Global variables  
int totalPlayers = 0;

UserResultVM vm = UserResultVM();

void Render() {
#if TMNEXT
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);
    auto server_info = cast<CTrackManiaNetworkServerInfo>(network.ServerInfo);

    if (Permissions::PlayOnlineCompetition() && windowVisible && app.CurrentPlayground !is null && server_info.CurGameModeStr == "TM_TimeAttackDaily_Online") 
    {
        COTDClubLiveUI::renderUI(vm);
    }
#endif
}

void RenderMenu() {
#if TMNEXT
    if(UI::MenuItem("\\$f0c\\$s" + Icons::Bold + "\\$z COTD Live Qualifying", "", windowVisible)) {
        windowVisible = !windowVisible;
    }
#endif
}

void Main() 
{
#if TMNEXT
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);
    auto server_info = cast<CTrackManiaNetworkServerInfo>(network.ServerInfo);

    NadeoServices::AddAudience("NadeoClubServices");

    int currentChallengeid = 0;
    int currentClubId = 0;
    string currentClubName = "";
    DisplayMode currentDisplayMode = Club; //0 == Club, 1 == Friends
    array<string> currentAccountIds;

    while (!NadeoServices::IsAuthenticated("NadeoClubServices")) 
    {
        yield();
    }

    while(true) 
    {
        //Only active with Club edition and during COTD Time Attack
        if (Permissions::PlayOnlineCompetition() && network.ClientManiaAppPlayground !is null && network.ClientManiaAppPlayground.Playground !is null && network.ClientManiaAppPlayground.Playground.Map !is null && server_info.CurGameModeStr == "TM_TimeAttackDaily_Online") 
        {
            string mapid = network.ClientManiaAppPlayground.Playground.Map.MapInfo.MapUid;

            if (currentChallengeid == 0) 
            {
                currentChallengeid = NadeoLiveServicesAPI::GetCurrentCOTDChallengeId();
            }

            array<Result@> allResults = {};
            array<Result@> topResults = {};

            bool newMembersFound = true;

            if(settings_displayMode == 0)
            {
                //Only reload club members if new club was selected or if displaymode was changed from club to friends
                if (currentAccountIds.Length == 0 || currentDisplayMode != settings_displayMode || currentClubId != settings_clubId)
                {
                    currentClubId = settings_clubId;
                    currentClubName = "Club: " + ColoredString(NadeoLiveServicesAPI::GetClubName(currentClubId));
                    //Show warning if more than 100 members
                    int offset = 0;
                    int length = 100;
                    currentAccountIds = NadeoLiveServicesAPI::GetMemberIdsFromClub(currentClubId, offset, length);
                }
                currentDisplayMode = Club;
            }
            else if(settings_displayMode == 1)
            {
                //Refresh if displaymode was changed from club to friends
                if (currentAccountIds.Length == 0 || currentDisplayMode != settings_displayMode)
                {
                    currentAccountIds = NadeoCoreAPI::GetFriendList();
                    currentClubName = "Friends";
                    //Warn wenn mehr als 100
                }
                currentDisplayMode = Friends;
            }
                
            array<Result@> playerResults = NadeoLiveServicesAPI::GetCurrentStandingForPlayers(currentAccountIds, currentChallengeid, mapid);

            for(uint n = 0; n < playerResults.Length; n++ )
            {
                allResults.InsertLast(playerResults[n]);
            }
            allResults.SortAsc();

            for(uint n = 0; n < numberOfPlayerDisplay && n < allResults.Length; n++ )
            {
                topResults.InsertLast(allResults[n]);
            }
            vm = VMMapper::ToUserResultVM(currentClubName, topResults);

        } else {
            //Reset state once COTD quali ends
            currentChallengeid = 0;
            vm = UserResultVM();
            currentAccountIds = {};
        }
        sleep(15000);
    }
#endif
}