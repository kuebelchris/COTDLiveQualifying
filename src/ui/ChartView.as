namespace ChartView
{
    // Chart dimensions (in pixels, will be scaled by UI scale)
    const float CHART_WIDTH = 600.0f;
    const float CHART_HEIGHT = 300.0f;
    const float MARGIN_LEFT = 60.0f;
    const float MARGIN_RIGHT = 100.0f;  // Increased to accommodate player names
    const float MARGIN_TOP = 20.0f;
    const float MARGIN_BOTTOM = 40.0f;

    void RenderTimeEvolutionChart(int div1CutoffTimeMs)
    {
        UI::Separator();
        UI::Text("Qualifying Times Progression");
        
        // Get all time series data
        array<PlayerTimeSeries@> allSeries = TimeSeriesService::GetAllTimeSeries();
        if (allSeries.Length == 0)
        {
            UI::TextDisabled("Waiting for tracking data...");
            return;
        }

        // If no cutoff time provided from model, try to get it from TimeSeriesService
        if (div1CutoffTimeMs <= 0)
        {
            div1CutoffTimeMs = TimeSeriesService::GetDiv1CutoffTime();
        }

        // Get the window draw list for rendering
        UI::DrawList@ drawList = UI::GetWindowDrawList();
        
        // Get the current cursor position for chart placement
        vec2 chartPos = UI::GetCursorScreenPos();
        
        // Draw the chart background and frame
        DrawChartFrame(drawList, chartPos);
        
        // Calculate min/max times for scaling - based on actual player data (exclude cutoff progression entry)
        float minTimeMs = 1e30;;
        float maxTimeMs = 0.0f;
        
        for (uint i = 0; i < allSeries.Length; i++)
        {
            PlayerTimeSeries@ series = allSeries[i];
            for (uint j = 0; j < series.snapshots.Length; j++)
            {
                TimeSnapshot@ snap = series.snapshots[j];
                if (snap.timeMs > 0)
                {
                    minTimeMs = Math::Min(minTimeMs, float(snap.timeMs));
                    maxTimeMs = Math::Max(maxTimeMs, float(snap.timeMs));
                }
            }
        }
        
        // Include div1 cutoff in the range if available
        if (div1CutoffTimeMs > 0)
        {
            minTimeMs = Math::Min(minTimeMs, float(div1CutoffTimeMs));
            maxTimeMs = Math::Max(maxTimeMs, float(div1CutoffTimeMs));
        }
        
        // Add some padding to the time axis
        float timePadding = (maxTimeMs - minTimeMs) * 0.1f;
        maxTimeMs = maxTimeMs + timePadding;
        minTimeMs = Math::Max(0.0f, minTimeMs - timePadding);
        
        DrawTimeGridLines(drawList, chartPos, minTimeMs, maxTimeMs);
        
        // Draw lines for each player (skip cutoff progression entry)
        for (uint i = 0; i < allSeries.Length; i++)
        {
            PlayerTimeSeries@ series = allSeries[i];
            DrawPlayerTimeSeries(drawList, chartPos, series, minTimeMs, maxTimeMs, i, uint(allSeries.Length));
        }
        
        // Draw player names at the end of their lines
        DrawPlayerLabels(drawList, chartPos, allSeries, minTimeMs, maxTimeMs);
        
        // Handle hover tooltips for rank information
        HandleHoverTooltips(drawList, chartPos, allSeries, minTimeMs, maxTimeMs);
        
        // Draw the static div1 cutoff line at the end (highest z-index)
        if (div1CutoffTimeMs > 0)
        {
            DrawCutoffLine(drawList, chartPos, div1CutoffTimeMs, minTimeMs, maxTimeMs);
        }
        
        // Advance cursor for next UI elements
        UI::Dummy(vec2(CHART_WIDTH + MARGIN_LEFT + MARGIN_RIGHT, CHART_HEIGHT + MARGIN_TOP + MARGIN_BOTTOM));
    }

    void DrawChartFrame(UI::DrawList@ drawList, vec2 chartPos)
    {
        float w = CHART_WIDTH;
        float h = CHART_HEIGHT;
        float ml = MARGIN_LEFT;
        float mt = MARGIN_TOP;
        
        // Draw outer frame, not sure why to calculation of the width doesn't work, manually added the correct values
        vec4 frameRect = vec4(chartPos.x + ml, chartPos.y + mt, chartPos.x + w - 85, chartPos.y + h -350);
        drawList.AddRect(frameRect, vec4(0.5f, 0.5f, 0.5f, 1.0f), 0.0f, 1.0f);
        
        // Draw background
        drawList.AddRectFilled(frameRect, vec4(0.1f, 0.1f, 0.1f, 0.8f));
    }

    void DrawTimeGridLines(UI::DrawList@ drawList, vec2 chartPos, float minTimeMs, float maxTimeMs)
    {
        float w = CHART_WIDTH;
        float h = CHART_HEIGHT;
        float ml = MARGIN_LEFT;
        float mt = MARGIN_TOP;
        
        // Draw horizontal grid lines for time (every 1000ms / 1 second)
        float timeRange = maxTimeMs - minTimeMs;
        float gridInterval = CalculateNiceGridInterval(timeRange);
        
        for (float t = Math::Ceil(minTimeMs / gridInterval) * gridInterval; t <= maxTimeMs; t += gridInterval)
        {
            float normalizedY = (t - minTimeMs) / timeRange;
            float screenY = mt + h - (normalizedY * h);
            
            vec2 pt1 = chartPos + vec2(ml - 3.0f, screenY);
            vec2 pt2 = chartPos + vec2(ml + w, screenY);
            
            drawList.AddLine(pt1, pt2, vec4(0.3f, 0.3f, 0.3f, 0.5f), 0.5f);
            
            // Add time label on Y axis
            string label = Time::Format(int(t));
            drawList.AddText(chartPos + vec2(5.0f, screenY - 7.0f), vec4(0.6f, 0.6f, 0.6f, 0.8f), label);
        }
        
        // Draw vertical grid lines for seconds remaining (every 60 seconds / 1 minute)
        for (int secsRemaining = 840; secsRemaining >= 0; secsRemaining -= 60)
        {
            float normalizedX = float(840 - secsRemaining) / 840.0f;
            float screenX = ml + (normalizedX * w);
            
            vec2 pt1 = chartPos + vec2(screenX, mt);
            vec2 pt2 = chartPos + vec2(screenX, mt + h + 3.0f);
            
            drawList.AddLine(pt1, pt2, vec4(0.3f, 0.3f, 0.3f, 0.5f), 0.5f);
            
            // Add time label on X axis
            int minutesRemaining = secsRemaining / 60;
            string label = minutesRemaining + "m";
            drawList.AddText(chartPos + vec2(screenX - 10.0f, mt + h + 10.0f), vec4(0.6f, 0.6f, 0.6f, 0.8f), label);
        }
    }

    void DrawPlayerTimeSeries(UI::DrawList@ drawList, vec2 chartPos, PlayerTimeSeries@ series, 
                              float minTimeMs, float maxTimeMs, uint index, uint totalSeries)
    {
        if (series.snapshots.Length < 2)
        {
            return; // Need at least 2 points to draw a line
        }
        
        float w = CHART_WIDTH;
        float h = CHART_HEIGHT;
        float ml = MARGIN_LEFT;
        float mt = MARGIN_TOP;
        float timeRange = maxTimeMs - minTimeMs;
        
        // Generate a color for this player
        vec4 playerColor = GeneratePlayerColor(index, totalSeries);
        
        // Draw line connecting all points
        for (uint i = 1; i < series.snapshots.Length; i++)
        {
            TimeSnapshot@ prev = series.snapshots[i - 1];
            TimeSnapshot@ curr = series.snapshots[i];
            
            // Skip invalid times
            if (prev.timeMs <= 0 || curr.timeMs <= 0)
            {
                continue;
            }
            
            // Convert data coordinates to screen coordinates
            float normalizedX1 = float(840 - prev.secsRemaining) / 840.0f;
            float normalizedY1 = (float(prev.timeMs) - minTimeMs) / timeRange;
            
            float normalizedX2 = float(840 - curr.secsRemaining) / 840.0f;
            float normalizedY2 = (float(curr.timeMs) - minTimeMs) / timeRange;
            
            float screenX1 = ml + normalizedX1 * w;
            float screenY1 = mt + h - normalizedY1 * h;
            
            float screenX2 = ml + normalizedX2 * w;
            float screenY2 = mt + h - normalizedY2 * h;
            
            vec2 pt1 = chartPos + vec2(screenX1, screenY1);
            vec2 pt2 = chartPos + vec2(screenX2, screenY2);
            
            drawList.AddLine(pt1, pt2, playerColor, 2.0f);
        }
    }

    void DrawCutoffLine(UI::DrawList@ drawList, vec2 chartPos, int cutoffTimeMs,
                        float minTimeMs, float maxTimeMs)
    {
        if (cutoffTimeMs <= 0)
        {
            return;
        }
        
        float w = CHART_WIDTH;
        float h = CHART_HEIGHT;
        float ml = MARGIN_LEFT;
        float mt = MARGIN_TOP;
        float timeRange = maxTimeMs - minTimeMs;
        
        // Draw horizontal line at cutoff time
        float normalizedY = (float(cutoffTimeMs) - minTimeMs) / timeRange;
        float screenY = mt + h - (normalizedY * h);
        
        vec2 pt1 = chartPos + vec2(ml, screenY);
        vec2 pt2 = chartPos + vec2(ml + w, screenY);
        
        // Draw line in white
        drawList.AddLine(pt1, pt2, vec4(1.0f, 1.0f, 1.0f, 0.9f), 2.0f);
        
        // Add label in white
        drawList.AddText(chartPos + vec2(ml + w - 80.0f, screenY - 15.0f), vec4(1.0f, 1.0f, 1.0f, 0.9f), "Div 1 Cutoff");
    }

    void DrawPlayerLabels(UI::DrawList@ drawList, vec2 chartPos, const array<PlayerTimeSeries@> &in allSeries,
                          float minTimeMs, float maxTimeMs)
    {
        float w = CHART_WIDTH;
        float ml = MARGIN_LEFT;
        float mt = MARGIN_TOP;
        const float LABEL_HEIGHT = 14.0f;  // Approximate text height
        const float LABEL_PAD = 2.0f;      // Padding between labels
        
        // First pass: collect all label info with ranks (exclude cutoff progression entry)
        array<int> ranks;                  // Final rank for each player
        array<PlayerTimeSeries@> labelSeries;  // Associated series
        array<uint> originalIndices;       // Original index for color generation
        
        for (uint i = 0; i < allSeries.Length; i++)
        {
            PlayerTimeSeries@ series = allSeries[i];

            if (series.snapshots.Length == 0)
            {
                continue;
            }
            
            // Find the last valid snapshot
            TimeSnapshot@ lastSnap = null;
            for (int j = series.snapshots.Length - 1; j >= 0; j--)
            {
                if (series.snapshots[j].timeMs > 0)
                {
                    @lastSnap = series.snapshots[j];
                    break;
                }
            }
            
            if (lastSnap is null)
            {
                continue;
            }
            
            ranks.InsertLast(lastSnap.rank);
            labelSeries.InsertLast(series);
            originalIndices.InsertLast(i);
        }
        
        // Second pass: sort by rank (descending, so highest rank/lowest number is first)
        // Simple bubble sort
        for (uint i = 0; i < ranks.Length; i++)
        {
            for (uint j = i + 1; j < ranks.Length; j++)
            {
                if (ranks[j] > ranks[i])
                {
                    // Swap ranks
                    int tempRank = ranks[i];
                    ranks[i] = ranks[j];
                    ranks[j] = tempRank;
                    
                    // Swap series
                    PlayerTimeSeries@ tempSeries = labelSeries[i];
                    @labelSeries[i] = labelSeries[j];
                    @labelSeries[j] = tempSeries;
                    
                    // Swap original indices
                    uint tempIdx = originalIndices[i];
                    originalIndices[i] = originalIndices[j];
                    originalIndices[j] = tempIdx;
                }
            }
        }
        
        // Third pass: draw labels in rank order at fixed positions on the right
        float labelX = ml + w + 10.0f;  // 10px to the right of the chart
        float labelY = mt;               // Start at top of chart
        
        for (uint i = 0; i < labelSeries.Length; i++)
        {
            vec4 playerColor = GeneratePlayerColor(originalIndices[i], uint(allSeries.Length));
            vec2 textPos = chartPos + vec2(labelX, labelY);
            drawList.AddText(textPos, playerColor, labelSeries[i].displayName);
            
            // Move down for next label
            labelY += LABEL_HEIGHT + LABEL_PAD;
        }
    }

    float CalculateNiceGridInterval(float range)
    {
        // Find a nice round interval for grid lines
        if (range < 1000.0f)
            return 100.0f;
        if (range < 5000.0f)
            return 500.0f;
        if (range < 10000.0f)
            return 1000.0f;
        if (range < 50000.0f)
            return 5000.0f;
        return 10000.0f;
    }

    vec4 GeneratePlayerColor(uint index, uint total)
    {
        if (total <= 1)
        {
            return vec4(0.2f, 0.8f, 1.0f, 1.0f); // Cyan
        }
        
        // Generate evenly distributed hues
        float hue = float(index) / float(total);
        
        // Use HSV to RGB conversion for nice colors
        vec4 hsv = UI::HSV(hue, 0.8f, 0.9f);
        return vec4(hsv.x, hsv.y, hsv.z, 1.0f);
    }

    void HandleHoverTooltips(UI::DrawList@ drawList, vec2 chartPos, const array<PlayerTimeSeries@> &in allSeries,
                             float minTimeMs, float maxTimeMs)
    {
        float ml = MARGIN_LEFT;
        float mt = MARGIN_TOP;
        float w = CHART_WIDTH;
        float h = CHART_HEIGHT;
        float timeRange = maxTimeMs - minTimeMs;
        const float HOVER_RADIUS = 8.0f;
        
        vec2 mousePos = UI::GetMousePos();
        
        // Collect unique players near the mouse (track by account ID)
        array<string> seenAccountIds;  // Track which players we've already added
        array<array<string>> hoveredPlayers;  // Array of player info strings
        
        // Check each data point for hover (skip cutoff progression entry)
        for (uint i = 0; i < allSeries.Length; i++)
        {
            PlayerTimeSeries@ series = allSeries[i];
            
            for (uint j = 0; j < series.snapshots.Length; j++)
            {
                TimeSnapshot@ snap = series.snapshots[j];
                if (snap.timeMs <= 0)
                {
                    continue;
                }
                
                float normalizedX = float(840 - snap.secsRemaining) / 840.0f;
                float normalizedY = (float(snap.timeMs) - minTimeMs) / timeRange;
                
                float screenX = ml + normalizedX * w;
                float screenY = mt + h - normalizedY * h;
                
                vec2 dataPointPos = chartPos + vec2(screenX, screenY);
                
                // Check if mouse is hovering over this point
                float distX = mousePos.x - dataPointPos.x;
                float distY = mousePos.y - dataPointPos.y;
                float dist = Math::Sqrt(distX * distX + distY * distY);
                
                if (dist < HOVER_RADIUS)
                {
                    // Only add this player if we haven't already added them
                    bool alreadyAdded = false;
                    for (uint k = 0; k < seenAccountIds.Length; k++)
                    {
                        if (seenAccountIds[k] == series.accountId)
                        {
                            alreadyAdded = true;
                            break;
                        }
                    }
                    
                    if (!alreadyAdded)
                    {
                        // Collect player info for this hover point
                        string timeLabel = Time::Format(snap.timeMs);
                        int div = (snap.rank - 1) / 64 + 1;
                        array<string> playerInfo = {series.displayName, "" + snap.rank, "" + div, timeLabel};
                        hoveredPlayers.InsertLast(playerInfo);
                        seenAccountIds.InsertLast(series.accountId);
                    }
                }
            }
        }
        
        // Draw composite tooltip if any players are hovered
        if (hoveredPlayers.Length > 0)
        {
            vec2 tooltipPos = mousePos + vec2(10.0f, -25.0f);
            
            // Build multi-line tooltip text
            for (uint i = 0; i < hoveredPlayers.Length; i++)
            {
                string playerName = hoveredPlayers[i][0];
                string rankStr = hoveredPlayers[i][1];
                string divStr = hoveredPlayers[i][2];
                string timeStr = hoveredPlayers[i][3];
                string line = playerName + " - Div " + divStr + " - Rank #" + rankStr + " - " + timeStr;
                
                drawList.AddText(tooltipPos, vec4(1.0f, 1.0f, 1.0f, 1.0f), line);
                
                // Move down for next line
                tooltipPos.y += 15.0f;
            }
        }
    }
}
