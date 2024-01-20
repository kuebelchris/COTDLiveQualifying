// Global variables
int totalPlayers = 0;
array<string> accountIds;
UserResultVM vm = UserResultVM();
float refreshProgress = 0;

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
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);

    NadeoServices::AddAudience("NadeoClubServices");
    NadeoServices::AddAudience("NadeoLiveServices");

    int currentChallengeid = 0;
    int currentClubId = 0;  
    int friendsRefreshIndicator = 4; //Refreshes friends every 60 seconds

    string currentDisplayGroupText; //Display text in top of MenuItem, shows [Club Name] [Friends] [Custom]
    array<bool> displayGroup = {settings_showClub, settings_showFriends, settings_showCustomPlayers};
    array<bool> displayGroupUpdate = {false,false,false};
    array<string> customPlayerListArray;
    int customPlayerListLength = settings_customPlayers.Length;

    while (!NadeoServices::IsAuthenticated("NadeoClubServices") && !NadeoServices::IsAuthenticated("NadeoLiveServices"))
    {
        yield();
    }

    while(true)
    {
        if (hasPermissionAndIsCOTDRunning())
        {
            //Rebuilds the GUI if any setting has changed
            if(customPlayerListLength != settings_customPlayers.Length || settings_showClub != displayGroup[0] || settings_showFriends != displayGroup[1] || settings_showCustomPlayers != displayGroup[2]){
                currentDisplayGroupText = "";
                displayGroupUpdate = {false,false,false};
                accountIds = {};
            }
            displayGroup = {settings_showClub, settings_showFriends, settings_showCustomPlayers};
            customPlayerListLength = settings_customPlayers.Length;

            NadeoCotdApi nadeoCotdApi;
            MapMonitorCotdApi mapMonitorCotdApi;

            ICotdApi@ cotdApi;
            if (settings_cotdApi == CotdApi::Nadeo)
            {
                @cotdApi = @nadeoCotdApi;
            }
            else if (settings_cotdApi == CotdApi::MapMonitor)
            {
                @cotdApi = @mapMonitorCotdApi;
            }
                  
            string currentUserId = NadeoCoreAPI::getCurrentWebServicesUserId();           
            string mapid = network.ClientManiaAppPlayground.Playground.Map.MapInfo.MapUid;

            friendsRefreshIndicator++;
            
            if (currentChallengeid == 0)
            {
                currentChallengeid = cotdApi.GetCurrentCOTDChallengeId();
            }

            array<Result@> allResults = {};
            array<Result@> topResults = {};

            if(!settings_showClub && !settings_showFriends && !settings_showCustomPlayers)
            {
                currentDisplayGroupText = ColoredString("$F33") + "No opponents selected!\n" + ColoredString("$FFF") + "You can select\n-Club\n-Friends\n-Custom Players";
                accountIds = {};
            }

            //Club
            if(settings_showClub)
            {
                //Only reload club members if new club was selected or if displaymode was changed from club to friends
                if (accountIds.Length == 0 || currentClubId != settings_clubId)
                {
                    currentClubId = settings_clubId;
                    if (currentClubId == 0)
                    {
                        currentDisplayGroupText = ColoredString("$F33") + "Please select a Club in the settings" + ColoredString("$FFF");
                        accountIds = {};
                    }
                    else
                    {
                        currentDisplayGroupText = "List: " + ColoredString(NadeoLiveServicesAPI::GetClubName(currentClubId)) + ColoredString("$FFF");                 
                        accountIds = NadeoLiveServicesAPI::GetAllMemberIdsFromClub(currentClubId, getMaxedTrackedPlayers());
                        displayGroupUpdate[0] = true;
                    }
                }
            }

            //Friends
            if(settings_showFriends)
            {
                if(friendsRefreshIndicator >= 4)
                {
                    addToAccountIds(NadeoCoreAPI::GetFriendList(getMaxedTrackedPlayers()));
                    friendsRefreshIndicator = 0;
                    if(!displayGroupUpdate[1]) //Check if Friends is not already displayed
                    {
                        if (displayGroupUpdate[0]) //If Club is displayed
                        {
                            currentDisplayGroupText = currentDisplayGroupText + " + Friends";
                        }
                        else
                        {
                            currentDisplayGroupText = currentDisplayGroupText + "List: Friends";                          
                        }         
                        displayGroupUpdate[1] = true;   
                    }                                                    
                } 
            }
            //Custom Players
            if(settings_showCustomPlayers)
            {
                if(customPlayerListLength >= 36) //atleast 1 player    
                {     
                    customPlayerListArray = settings_customPlayers.Split("\n");
                    addToAccountIds(customPlayerListArray);
                
                    if(!displayGroupUpdate[2]) //Check if Custom is not already displayed
                    {
                        if(displayGroupUpdate[0] || displayGroupUpdate[1]) //If Club or Friends is displayed
                        {
                            currentDisplayGroupText = currentDisplayGroupText + " + Custom";  
                        }
                        else
                        {
                            currentDisplayGroupText = "List: Custom";
                        }     
                        displayGroupUpdate[2] = true;
                    }
                } 
                else 
                {
                    if(displayGroupUpdate[0] || displayGroupUpdate[1]) //If Club or Friends is displayed
                    {
                        currentDisplayGroupText = currentDisplayGroupText + " + Custom (" + ColoredString("$F33None selected") + ColoredString("$FFF)");  
                    }
                    else
                    {
                        currentDisplayGroupText = "List: Custom(" + ColoredString("$F33None selected") + ColoredString("$FFF)");
                    }
                }
            }           

            //Add local user if not already included
            if (accountIds.Find(currentUserId) < 0)
            {
                accountIds.InsertLast(currentUserId);
            }

            array<Result@> playerResults = cotdApi.GetCurrentStandingForPlayers(accountIds, currentChallengeid, mapid);

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
                Result@ cutoff = cotdApi.GetDiv1CutoffTime(currentChallengeid, mapid);
                if (@cutoff != null)
                {
                    SingleUserResultVM@ cutoffVM = VMMapper::ToSingleUserResultCutoffVM(cutoff);
                    singleResultVMs.InsertLast(cutoffVM);
                    singleResultVMs.SortAsc();
                }
            }

            vm = VMMapper::ToUserResultVM(currentDisplayGroupText, singleResultVMs);

        } else {
            //Reset state once COTD quali ends
            currentChallengeid = 0;
            vm = UserResultVM();
            accountIds = {};
        }

        float progress = 100;
        int progressBarInterval = 10;
        float refreshTime = 15000;
        while(refreshTime >= progress)
        {
            if (progress != 0)
            {
                refreshProgress = 1 - (progress / refreshTime);
            }
            progress = progress + progressBarInterval;
            sleep(progressBarInterval);
        }       
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

uint getMaxedTrackedPlayers()
{
    if (settings_cotdApi == CotdApi::Nadeo)
    {
        return 100;
    }
    else if (settings_cotdApi == CotdApi::MapMonitor)
    {
        return 1000;
    }
    return 0;
}

void addToAccountIds(array<string> fetchedPlayers)
{
    for(uint p = 0; p < fetchedPlayers.Length; p++)
    {
        if (accountIds.Find(fetchedPlayers[p]) < 0)
        {
            accountIds.InsertLast(fetchedPlayers[p]);
        }
    }
}
