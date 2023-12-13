class MapMonitorCotdApi : ICotdApi
{ 

	int GetCurrentCOTDChallengeId()
	{
		auto matchstatus = MapMonitor::GetCotdCurrent();
		if (matchstatus.GetType() == Json::Type::Null)
	    {
			warn("could not retreive cotd from Map Monitor");
			return 0;
		}
	    string challengeName = matchstatus["challenge"]["name"];
	    return matchstatus["challenge"]["id"];
	}

	Result@ GetDiv1CutoffTime(const int&in challengeid, const string&in mapid)
	{
        auto divOneCutoff = MapMonitor::GetChallengeRecords(challengeid, mapid, 1, 63);
		if (divOneCutoff.GetType() == Json::Type::Null)
	    {
			warn("could not retreive div 1 cutoff from Map Monitor");
			return null;
		}
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
		array<Result@> results = {};
        auto currentStanding = MapMonitor::GetPlayersRank(challengeid, mapid, players);
		if (currentStanding.GetType() == Json::Type::Null)
	    {
			warn("could not retreive cotd from Map Monitor");
			return results;
		}

	    totalPlayers = currentStanding["cardinal"];
	    Json::Value@ records = currentStanding["records"];

	    
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