int state_currentChallengeid = 0;
int state_currentClubId = settings_clubId;  
string state_currentClubName = "--";
string state_currentCustomName = "--";

bool state_showFriends = settings_showFriends;
bool state_showClub = settings_showClub;
bool state_showCustom = settings_showCustomPlayers;
bool state_showDivOneCutoff = settings_showDivOneCutoff;

array<string> state_customPlayerListArray = {};
string state_customPlayerList = settings_customPlayers;

bool checkSettingsChanged()
{
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
    return false;
}