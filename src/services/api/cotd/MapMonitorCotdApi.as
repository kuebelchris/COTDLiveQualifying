class MapMonitorCotdApi : ICotdApi
{ 

	Result@ GetDiv1CutoffTime(const int&in challengeid, const string&in mapid)
	{
        auto divOneCutoff = MapMonitor::GetChallengeRecords(challengeid, mapid, 1, 63);
		if (divOneCutoff.Length > 0)
		{
			uint playerTime = divOneCutoff[0]["score"];
	    	string playerId = divOneCutoff[0]["player"];
	    	int playerRank = divOneCutoff[0]["rank"];
			return Result(playerId, playerRank, 1, playerTime);
		}
		return null;
	}

    array<Result@> GetCurrentStandingForPlayers(const array<string>&in players, const int &in challengeid, const string &in mapid)
    {
        auto currentStanding = MapMonitor::GetPlayersRank(challengeid, mapid, players);
	    totalPlayers = currentStanding["cardinal"];
	    Json::Value@ records = currentStanding["records"];

	    array<Result@> results = {};
            for(uint n = 0; n < records.Length; n++ )
            {
            	Json::Value@ playerResult = records[n];
            	if (playerResult.Length > 0)
            	{
            		uint playerTime = playerResult["score"];
	    			string playerId = playerResult["player"];
	    			int playerRank = playerResult["rank"];
	    			int currentDiv = calculateDiv(playerRank);

            		Result@ playerDivTime = Result(playerId, playerRank, currentDiv, playerTime);
                	results.InsertLast(playerDivTime);
            	}

            }
        return results;
    }

    int calculateDiv(const int &in playerRank)
	{
		if (playerRank == 1)
		{
			return 1;
	    }
	    else
		{
			return ((playerRank - 1) / 64) + 1;
		}
	}
}