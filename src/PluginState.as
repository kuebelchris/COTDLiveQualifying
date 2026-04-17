int state_currentChallengeid = 0;
// "cotd" | "cotw" | "grand_race" — resolved by matching current map UID
string state_activeCupType = "cotd";
string state_currentMapUid = "";
string state_currentClubName = "--";
string state_currentCustomName = "--";

bool state_forceRefreshPlayers = true;
bool state_settingsChanged = false;
bool state_configLoaded = false;

int state_totalPlayers = 0;
array<string> state_accountIds;
RankingModel state_rankingModel = RankingModel();
float state_refreshProgress = 0;

namespace PluginState
{
    void Reset()
    {
        state_currentChallengeid = 0;
        state_activeCupType = "cotd";
        state_rankingModel = RankingModel();
        state_accountIds = {};
        state_totalPlayers = 0;
        state_forceRefreshPlayers = true;
        state_settingsChanged = false;
        state_configLoaded = false;
        ConfigService::Reset();
        CutoffService::ResetArState();
        TimeSeriesService::Reset();
    }
}