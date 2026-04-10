// --- Club picker state ---
array<ClubInfo@> myClubs;
bool clubsLoading = false;
bool clubsLoaded = false;
int selectedClubIndex = -1;

void LoadMyClubs()
{
    myClubs = NadeoLiveServicesAPI::GetAllClubs();
    selectedClubIndex = -1;
    clubsLoading = false;
    clubsLoaded = true;
}

[SettingsTab name="Club" icon="UsersAlt" order="1"]
void RenderSettingsClubPicker()
{
    if (!clubsLoaded && !clubsLoading) {
        clubsLoading = true;
        startnew(LoadMyClubs);
    }

    if (clubsLoading) {
        UI::Text("Loading clubs...");
        return;
    }

    // Keep selectedClubIndex in sync with settings_clubId.
    if (selectedClubIndex < 0
        || selectedClubIndex >= int(myClubs.Length)
        || myClubs[selectedClubIndex].id != settings_clubId)
    {
        selectedClubIndex = -1;
        for (uint i = 0; i < myClubs.Length; i++) {
            if (myClubs[i].id == settings_clubId) {
                selectedClubIndex = int(i);
                break;
            }
        }
    }

    if (myClubs.Length == 0) {
        UI::Text("No clubs found.");
    } else {
        array<string> labels;
        for (uint i = 0; i < myClubs.Length; i++) {
            string label = Text::OpenplanetFormatCodes(myClubs[i].name);
            string formattedTag = Text::OpenplanetFormatCodes(myClubs[i].tag) + "\\$z";
            if (formattedTag.Length > 0) {
                label = "[" + formattedTag + "] " + label;
            }
            labels.InsertLast(label);
        }
        string currentLabel = (selectedClubIndex >= 0 && selectedClubIndex < int(labels.Length))
            ? labels[selectedClubIndex]
            : "Select a club...";
        if (UI::BeginCombo("Club", currentLabel)) {
            for (uint i = 0; i < labels.Length; i++) {
                bool isSelected = (int(i) == selectedClubIndex);
                if (UI::Selectable(labels[i], isSelected)) {
                    selectedClubIndex = int(i);
                    settings_clubId = myClubs[selectedClubIndex].id;
                    state_forceRefreshPlayers = true;
                }
                if (isSelected) {
                    UI::SetItemDefaultFocus();
                }
            }
            UI::EndCombo();
        }
    }

    if (UI::Button("Reload")) {
        clubsLoaded = false;
        clubsLoading = true;
        startnew(LoadMyClubs);
    }

    UI::Separator();
    UI::Text("Or enter the Club ID manually:");
    int newClubId = UI::InputInt("Club ID", settings_clubId);
    if (newClubId != settings_clubId) {
        settings_clubId = newClubId;
        selectedClubIndex = -1;
        for (uint i = 0; i < myClubs.Length; i++) {
            if (myClubs[i].id == settings_clubId) {
                selectedClubIndex = int(i);
                break;
            }
        }
        state_forceRefreshPlayers = true;
    }
}
