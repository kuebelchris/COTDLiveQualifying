// --- Custom Players settings state ---
string newPlayerId = "";
dictionary resolvedNames;
bool namesLoading = false;

void ResolveCustomPlayerNames()
{
    string[] players = settings_customPlayers.Split("\n");
    for (uint i = 0; i < players.Length; i++) {
        string id = players[i];
        if (id.Length > 0 && !resolvedNames.Exists(id)) {
            string name = UserManager::GetDisplayNameForAccount(id);
            resolvedNames.Set(id, name);
        }
    }
    namesLoading = false;
}

[SettingsTab name="Custom Players" icon="UserPlus" order="2"]
void RenderSettingsCustomPlayers()
{
    // Kick off background name resolution for any unresolved IDs.
    if (!namesLoading) {
        string[] check = settings_customPlayers.Split("\n");
        for (uint i = 0; i < check.Length; i++) {
            if (check[i].Length > 0 && !resolvedNames.Exists(check[i])) {
                namesLoading = true;
                startnew(ResolveCustomPlayerNames);
                break;
            }
        }
    }

    // -- Add player row --
    UI::SetNextItemWidth(UI::GetContentRegionAvail().x * 0.8f);
    newPlayerId = UI::InputText("##newplayer", newPlayerId);
    UI::SameLine();
    if (UI::Button(Icons::Plus + " Add")) {
        if (newPlayerId.Length > 0) {
            string[] existing = settings_customPlayers.Split("\n");
            bool alreadyExists = false;
            for (uint i = 0; i < existing.Length; i++) {
                if (existing[i] == newPlayerId) {
                    alreadyExists = true;
                    break;
                }
            }
            if (!alreadyExists) {
                if (settings_customPlayers.Length > 0) {
                    settings_customPlayers += "\n" + newPlayerId;
                } else {
                    settings_customPlayers = newPlayerId;
                }
                state_forceRefreshPlayers = true;
                if (!namesLoading) {
                    namesLoading = true;
                    startnew(ResolveCustomPlayerNames);
                }
            }
            newPlayerId = "";
        }
    }

    UI::Separator();

    // -- Player list --
    string[] players = settings_customPlayers.Split("\n");
    int removeIndex = -1;
    for (uint i = 0; i < players.Length; i++) {
        string id = players[i];
        if (id.Length == 0) continue;

        string displayName = id;
        if (resolvedNames.Exists(id)) {
            string resolved;
            resolvedNames.Get(id, resolved);
            if (resolved.Length > 0) {
                displayName = resolved;
            }
        }

        UI::Text(displayName);
        UI::SameLine();
        if (UI::Button(Icons::Trash + "##remove_" + id)) {
            removeIndex = int(i);
        }
    }

    if (removeIndex >= 0) {
        players.RemoveAt(uint(removeIndex));
        string newList = "";
        for (uint i = 0; i < players.Length; i++) {
            if (players[i].Length > 0) {
                if (newList.Length > 0) newList += "\n";
                newList += players[i];
            }
        }
        settings_customPlayers = newList;
        state_forceRefreshPlayers = true;
    }
}
