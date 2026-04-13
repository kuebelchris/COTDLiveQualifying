namespace RankingController
{
    void Render()
    {
        if (state_rankingModel is null) { 
            return; 
        }
        RankingView::renderUI(state_rankingModel);
    }

    RankingModel@ BuildModel(const array<SingleUserResultVM@> &in userResults)
    {
        return RankingModel(
            userResults,
            BuildSelectedModesDescription(),
            state_totalPlayers
        );
    }

    string BuildSelectedModesDescription()
    {
        array<string> modes = BuildDisplayModeList();

        if (modes.Length == 1 && modes[0].SubStr(0, 3) == "$F3")
        {
            // Error/no-selection message — return as-is
            return modes[0];
        }

        string displayMode = "List: ";
        for (uint i = 0; i < modes.Length; i++)
        {
            if (i == modes.Length - 1)
            {
                displayMode = displayMode + modes[i] + "$z";
            }
            else
            {
                displayMode = displayMode + modes[i] + "$z + ";
            }
        }
        return Text::OpenplanetFormatCodes(displayMode);
    }

    array<string> BuildDisplayModeList()
    {
        if (!settings_showClub && !settings_showFriends && !settings_showCustomPlayers)
        {
            return {"$F33No opponents selected!\n $FFFYou can select\n- Club\n- Friends\n- Custom Players"};
        }

        array<string> modes = {};
        if (settings_showClub)
        {
            modes.InsertLast(state_currentClubName);
        }
        if (settings_showFriends)
        {
            modes.InsertLast("Friends");
        }
        if (settings_showCustomPlayers)
        {
            modes.InsertLast("Custom");
        }
        return modes;
    }
}
