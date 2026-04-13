int state_currentChallengeid = 0;
// "cotd" | "cotw" | "grand_race" — resolved by matching current map UID
string state_activeCupType = "cotd";
string state_currentClubName = "--";
string state_currentCustomName = "--";

bool state_forceRefreshPlayers = true;
bool state_settingsChanged = false;

array<string> state_customPlayerListArray = {};