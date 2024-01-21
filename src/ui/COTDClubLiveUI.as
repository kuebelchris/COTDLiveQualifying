namespace COTDClubLiveUI
{
	void renderUI(const UserResultVM@ &in vm, const float &in refreshBarProgress)
	{
		int windowFlags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoDocking;

        if (!UI::IsOverlayShown()) {
            windowFlags |= UI::WindowFlags::NoInputs;
        }
    
        UI::Begin("COTD Live Qualifying", windowFlags);

        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(0, 0));
        UI::Dummy(vec2(0, 0));
        UI::PopStyleVar();

        UI::BeginGroup();

        UI::BeginTable("header", 1, UI::TableFlags::SizingFixedFit);
        UI::TableNextRow();
        UI::TableNextColumn();
        UI::Text("COTD Live Qualifying");
        UI::TableNextRow();
        UI::TableNextColumn();
        UI::Text("Cup info: \\$aaa" + totalPlayers + " players (" + Math::Ceil(totalPlayers/64.0) + " divs)\\$z");
        UI::TableNextRow();
        UI::TableNextColumn();
        UI::Text(getDisplayModeDescription(vm.selectedModes));
        UI::EndTable();

        UI::BeginTable("ranking", 4, UI::TableFlags::SizingFixedFit);

        UI::TableNextRow();
        UI::TableNextColumn();
        UI::Text("Rank");
        UI::TableNextColumn();
        UI::Text("Div");
        UI::TableNextColumn();
        UI::Text("Player");
        UI::TableNextColumn();
        UI::Text("Time");

        for(uint i = 0; i < vm.userResults.Length; i++) {
            SingleUserResultVM@ result = vm.userResults[i];
            UI::TableNextRow();
            UI::TableNextColumn();
            UI::Text(result.RankString());
            UI::TableNextColumn();
            UI::Text(result.DivString());
            UI::TableNextColumn();
            UI::Text(result.PlayerDisplayName());
            UI::TableNextColumn();
            UI::Text(result.TimeString());
        }

        UI::EndTable();

        if (settings_showProgressBar)
        {
            UI::ProgressBar(refreshBarProgress, vec2(-1,1));
        }
    
        
        UI::EndGroup();
        
        UI::End();
	}

    string getDisplayModeDescription(array<string> selectedModes)
    {
        string displayMode = "List: ";
        for(uint i = 0; i < selectedModes.Length; i++) {
            if (i == selectedModes.Length - 1)
            {
                displayMode = displayMode + selectedModes[i] + "$z";
            }
            else
            {
                displayMode = displayMode + " " + selectedModes[i] + "$z + ";
            }
        }
        return ColoredString(displayMode);
    }
}