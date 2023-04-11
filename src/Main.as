// Global variables  
int totalPlayers = 0;

UserResultVM vm = UserResultVM();

void Render() 
{
#if TMNEXT

    if (hasPermissionAndIsCOTDRunning())
    {
        if (!UI::IsGameUIVisible() && settings_hideIfUIHidden)
        {
            return;
        }

        if(!UI::IsOverlayShown() && onlyOnOverlay) 
        {
            return;
        }

        COTDClubLiveUI::renderUI(vm);
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

    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);

    NadeoServices::AddAudience("NadeoClubServices");
    NadeoServices::AddAudience("NadeoLiveServices");

    int currentChallengeid = 0;
    int currentClubId = 0;
    string currentClubName = "";
    DisplayMode currentDisplayMode = Club; //0 == Club, 1 == Friends
    array<string> currentAccountIds;
    int friendsRefreshIndicator = 0;

    while (!NadeoServices::IsAuthenticated("NadeoClubServices") && !NadeoServices::IsAuthenticated("NadeoLiveServices")) 
    {
        yield();
    }

    while(true) 
    {
        if (hasPermissionAndIsCOTDRunning())
        {

            string currentUserId = NadeoCoreAPI::getCurrentWebServicesUserId();
            friendsRefreshIndicator++;
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
                    if (currentClubId == 0)
                    {
                        currentClubName = "Please select a Club in the settings";
                        currentAccountIds = {};
                    }
                    else
                    {
                        currentClubName = "Club: " + ColoredString(NadeoLiveServicesAPI::GetClubName(currentClubId));
                        //Show warning if more than 100 members
                        int offset = 0;
                        int length = 100;
                        currentAccountIds = NadeoLiveServicesAPI::GetMemberIdsFromClub(currentClubId, offset, length);
                    }
                }
                currentDisplayMode = Club;
            }
            else if(settings_displayMode == 1)
            {
                //Refresh if displaymode was changed from club to friends, refresh every minute
                if (currentAccountIds.Length == 0 || currentDisplayMode != settings_displayMode || friendsRefreshIndicator >= 4)
                {
                    currentAccountIds = NadeoCoreAPI::GetFriendList();
                    friendsRefreshIndicator = 0;
                    currentClubName = "Friends";
                }
                currentDisplayMode = Friends;
            }
             
            //Add current user if not already included  
            if (currentAccountIds.Find(currentUserId) < 0)
            {
                currentAccountIds.InsertLast(currentUserId);
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

            array<SingleUserResultVM@> singleResultVMs = VMMapper::ToSingleUserResultVMs(topResults);

            //Show Div 1 Cutoff
            if (settings_showDivOneCutoff)
            {
                Result@ cutoff = NadeoLiveServicesAPI::GetDiv1CutoffTime(currentChallengeid, mapid);
                if (@cutoff != null)
                {
                    SingleUserResultVM@ cutoffVM = VMMapper::ToSingleUserResultCutoffVM(cutoff);
                    singleResultVMs.InsertLast(cutoffVM);
                    singleResultVMs.SortAsc();
                }
            }

            vm = VMMapper::ToUserResultVM(currentClubName, singleResultVMs);

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

 //Only active with Club edition and during COTD Time Attack
bool hasPermissionAndIsCOTDRunning()
{
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);
    auto server_info = cast<CTrackManiaNetworkServerInfo>(network.ServerInfo);
    return Permissions::PlayOnlineCompetition() && network.ClientManiaAppPlayground !is null && network.ClientManiaAppPlayground.Playground !is null && network.ClientManiaAppPlayground.Playground.Map !is null && server_info.CurGameModeStr == "TM_COTDQualifications_Online";
}