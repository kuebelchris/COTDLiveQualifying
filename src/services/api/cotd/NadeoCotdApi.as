class NadeoCotdApi : ICotdApi
{
    
	Result@ GetDiv1CutoffTime(const int&in challengeid, const string&in mapid)
	{
        string compUrl = NadeoServices::BaseURLMeet();
		string cotdEndpoint = compUrl + "/api/challenges/" + challengeid + "/records/maps/" + mapid + "?offset=63&length=1";
		Json::Value divOneCutoff = FetchEndpoint(cotdEndpoint);
		if (divOneCutoff.Length > 0)
		{
			uint playerTime = divOneCutoff[0]["score"];
	    	string playerId = divOneCutoff[0]["player"];
	    	int playerRank = divOneCutoff[0]["rank"];
			return Result(playerId, playerRank, 1, playerTime);
		}
		return null;
	}

	array<Result@> GetCurrentStandingForPlayers(const array<string>&in players, const int&in challengeid, const string&in mapid)
	{
        string compUrl = NadeoServices::BaseURLMeet();
	    string playersEndpoint = compUrl + "/api/challenges/" + challengeid + "/records/maps/" + mapid + "/players?players[]=";

	    for(uint n = 0; n < players.Length; n++ )
	    {
	        playersEndpoint += "&players[]=" + players[n];
	    }

	    Json::Value currentStanding = FetchEndpoint(playersEndpoint);
	    totalPlayers = currentStanding["cardinal"];
	    Json::Value records = currentStanding["records"];

	    array<Result@> results = {};
            for(uint n = 0; n < records.Length; n++ )
            {
            	Json::Value playerResult = records[n];
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

    Json::Value@ FetchEndpoint(const string &in route) {
	    auto req = NadeoServices::Get("NadeoClubServices", route);
	    req.Start();
	    while(!req.Finished()) {
	        yield();
	    }
	    return Json::Parse(req.String());
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