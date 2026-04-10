[SettingsTab name="Info" icon="InfoCircle" order="3"]
void RenderSettingsAbout() {
    UI::Text("Limitations:");
    UI::Text("Clubs are supported up to 100 players (1000 when using MapMonitor), otherwise not all results of the players can be tracked.");
    UI::Text("Same applies to Uplay friends.");
    UI::Separator();
    UI::Text("Tips:");
    UI::Text("You can get the club id by searching for the club at trackmania.io.");
    UI::Text("The Account ID of a player can be found on a trackmania.io player profile and looks like this: a1a2a3a4-b1b2-c1c2-d1d1-e1e2e3e4e5e6");
    UI::Separator();
    UI::Text("Contributors:");
    UI::Text("Thanks to JanVan8ern, XertroV and huhen for contributing with new features and improvements.");
}
