[SettingsTab name="Info"]
void RenderSettingsAbout() {
    UI::Text("Limitations:");
    UI::Text("Clubs are supported up to 100 players, otherwise not all results of the players can be tracked.");
    UI::Text("Same applies to Uplay friends.");
    UI::Text("Offline Uplay friends will not be tracked.");
    UI::Separator();
    UI::Text("Tipps:");
    UI::Text("You can get the club id by searching for the club at trackmania.io.");
}

[Setting category="Display Settings" name="Window visible" description="To move the table, click and drag while the Openplanet overlay is visible"]
bool windowVisible = true;

[Setting category="Display Settings" name="Display Mode" description="Show club members or online Uplay friends"]
DisplayMode settings_displayMode = Club;

[Setting category="Display Settings" name="Number of displayed Players" description="The maximum number of shown players."]
uint numberOfPlayerDisplay = 10;

[Setting category="Display Settings" name="Display club tags for players"]
bool setttings_showClubTag = true;

[Setting category="Club" name="Club id of the club" description="All players from the club will be tracked"]
int settings_clubId = 0;