namespace RankingView
{
	void renderUI(const RankingModel@ &in model)
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
        UI::Text("Cup info: \\$aaa" + model.totalPlayers + " players (" + Math::Ceil(model.totalPlayers/64.0) + " divs)\\$z");
        UI::TableNextRow();
        UI::TableNextColumn();
        UI::Text(model.selectedModesDescription);
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

        for(uint i = 0; i < model.userResults.Length; i++) {
            SingleUserResultVM@ result = model.userResults[i];
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

        // Auto-show chart when qualifying ends if setting is enabled
        if (model.secsRemaining == 0 && settings_showChartAfterQuali)
        {
            settings_showChart = true;
        }

        // Button to toggle chart visibility (only show if recording is enabled)
        if (settings_recordProgress)
        {
            string buttonLabel = settings_showChart ? "Hide Progress Chart" : "Display Progress Chart";
            if (UI::Button(buttonLabel, vec2(0, 0)))
            {
                settings_showChart = !settings_showChart;
            }
        }

        if (settings_showProgressBar)
        {
            UI::ProgressBar(state_refreshProgress, vec2(-1,1));
        }

        // Render the time evolution chart (if enabled)
        if (settings_showChart && settings_recordProgress)
        {
            int div1CutoffTimeMs = ExtractDiv1CutoffTime(model);
            ChartView::RenderTimeEvolutionChart(div1CutoffTimeMs);
        }
    
        UI::EndGroup();
        
        UI::End();
	}

	int ExtractDiv1CutoffTime(const RankingModel@ &in model)
	{
		// Find the cutoff row in the results
		for (uint i = 0; i < model.userResults.Length; i++)
		{
			SingleUserResultVM@ result = model.userResults[i];
			if (result.IsCutoff())
			{
				return result.Time();
			}
		}
		return -1; // No cutoff found
	}
}