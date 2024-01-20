[SettingsTab name="Info"]
void RenderSettingsAbout() {
    UI::Text("Limitations:");
    UI::Text("Clubs are supported up to 100 players (1000 when using MapMonitor), otherwise not all results of the players can be tracked.");
    UI::Text("Same applies to Uplay friends.");
    UI::Separator();
    UI::Text("Tips:");
    UI::Text("You can get the club id by searching for the club at trackmania.io.");
    UI::Text("The Account ID of a player can be found on a trackmania.io player profile and looks like this: a1a2a3a4-b1b2-c1c2-d1d1-e1e2e3e4e5e6");
}

[Setting category="Display Settings" name="Window visible" description="To move the table, click and drag while the Openplanet overlay is visible"]
bool windowVisible = true;

[Setting category="Display Settings" name="Only show when Openplanet visible" description="Hides the table when the Openplanet overlay is not visible"]
bool onlyOnOverlay = false;

[Setting category="Display Settings" name="Only show when Game UI is visible" description="deactivating will always show the table"]
bool settings_hideIfUIHidden = true;

[Setting category="Display Settings" name="Club" description="Shows club members in the leaderboard"]
bool settings_showClub = true;

[Setting category="Display Settings" name="Friends" description="Shows online friends in the leaderboard"]
bool settings_showFriends = false;

[Setting category="Display Settings" name="Custom Players" description="Shows selected players in the leaderboard"]
bool settings_showCustomPlayers = false;

[Setting category="Display Settings" name="Show offline Friends, Required to display PlayStation Friends"]
bool settings_showOfflineFriends = false;

[Setting category="Display Settings" name="Number of displayed Players" description="The maximum number of shown players."]
uint numberOfPlayerDisplay = 10;

[Setting category="Display Settings" name="Display club tags for players"]
bool setttings_showClubTag = true;

[Setting category="Display Settings" name="Show division 1 cutoff"]
bool settings_showDivOneCutoff = false;

[Setting category="Display Settings" name="Show refresh progress bar"]
bool settings_showProgressBar = true;

[Setting category="Club" name="Club id of the club" description="All players from the club will be tracked"]
int settings_clubId = 0;

[Setting category="Custom Players" multiline name="Custom list of players to show" description="Enter a list of account-ids, each in a new line e.g.: a1a2a3a4-b1b2-c1c2-d1d1-e1e2e3e4e5e6"]
string settings_customPlayers = "";

[Setting category="API" name="Select which API to use"]
CotdApi settings_cotdApi = CotdApi::Nadeo;