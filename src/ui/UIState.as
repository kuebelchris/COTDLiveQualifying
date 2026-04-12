int state_currentChallengeid = 0;
// "cotd" | "cotw" | "grand_race" — resolved by matching current map UID
string state_activeCupType = "cotd";
int state_currentClubId = settings_clubId;  
string state_currentClubName = "--";
string state_currentCustomName = "--";

bool state_showFriends = settings_showFriends;
bool state_showClub = settings_showClub;
bool state_showCustom = settings_showCustomPlayers;
bool state_showDivOneCutoff = settings_showDivOneCutoff;
bool state_showCutoffPrediction = settings_showCutoffPrediction;
CotdApi state_cotdApi = settings_cotdApi;
bool state_forceRefreshPlayers = true;

array<string> state_customPlayerListArray = {};
string state_customPlayerList = settings_customPlayers;

bool checkSettingsChanged()
{
    if(state_forceRefreshPlayers)
    {
        return true;
    }
    if(state_currentClubId != settings_clubId)
    {
        return true;
    }
    if(state_showClub != settings_showClub)
    {
        return true;
    }
    if(state_showFriends != settings_showFriends)
    {
        return true;
    }
    if(state_showCustom != settings_showCustomPlayers)
    {
        return true;
    }
    if(state_customPlayerList != settings_customPlayers)
    {
        return true;
    }
    if(state_showDivOneCutoff != settings_showDivOneCutoff)
    {
        return true;
    }
    if(state_showCutoffPrediction != settings_showCutoffPrediction)
    {
        return true;
    }
    if(state_cotdApi != settings_cotdApi)
    {
        return true;
    }
    return false;
}