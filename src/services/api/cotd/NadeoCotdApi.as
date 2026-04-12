class NadeoCotdApi : ICotdApi
{
    
	int GetCurrentCOTDChallengeId()
	{
	    string compUrl = NadeoServices::BaseURLMeet();
	    auto matchstatus = FetchEndpoint(compUrl + "/api/cup-of-the-day/current");
		if (matchstatus.GetType() == Json::Type::Null)
	    {
			warn("could not retreive cotd from Nadeo API");
			return 0;
		}
	    string challengeName = matchstatus["challenge"]["name"];
	    return matchstatus["challenge"]["id"];
	}

	// Returns the qualifier challenge ID for a named cup type.
	// type: "cotd" | "cotw" | "grand_race"
	// Queries /api/cups-of-the-day?type={type}&length=1 which works for all three cup types.
	int GetCurrentChallengeIdByType(const string &in type)
	{
		string compUrl = NadeoServices::BaseURLMeet();
		Json::Value@ data = FetchEndpoint(compUrl + "/api/cups-of-the-day?type=" + type + "&length=1&offset=0");
		if (data.GetType() == Json::Type::Null) {
			warn("could not retrieve cups-of-the-day for type=" + type);
			return 0;
		}
		Json::Value@ cups = data["COTDs"];
		print("NadeoCotdApi::GetCurrentChallengeIdByType raw cups JSON: " + Json::Write(cups));
		if (cups.GetType() != Json::Type::Array || cups.Length == 0) {
			warn("no cups found for type=" + type);
			return 0;
		}
		return cups[0]["challenge"]["id"];
	}

	Result@ GetDiv1CutoffTime(const int&in challengeid, const string&in mapid)
	{
        string compUrl = NadeoServices::BaseURLMeet();
		print("NadeoCotdApi::GetDiv1CutoffTime challengeid=" + challengeid + " mapid=" + mapid);
		string cotdEndpoint = compUrl + "/api/challenges/" + challengeid + "/records/maps/" + mapid + "?offset=63&length=1";
		Json::Value divOneCutoff = FetchEndpoint(cotdEndpoint);
		print("NadeoCotdApi::GetDiv1CutoffTime");

		if (divOneCutoff.GetType() == Json::Type::Null)
	    {
			warn("could not retrieve div 1 cutoff from Nadeo API");
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

	array<Result@> GetCurrentStandingForPlayers(const array<string>&in players, const int&in challengeid, const string&in mapid)
	{
		array<Result@> results = {};
		print("NadeoCotdApi::GetCurrentStandingForPlayers challengeid=" + challengeid + " mapid=" + mapid + " players=" + players.Length);

        string compUrl = NadeoServices::BaseURLMeet();
	    string playersEndpoint = compUrl + "/api/challenges/" + challengeid + "/records/maps/" + mapid + "/players?players[]=";

	    for(uint n = 0; n < players.Length; n++ )
	    {
	        playersEndpoint += "&players[]=" + players[n];
	    }

		print("NadeoCotdApi: fetching " + playersEndpoint);
	    Json::Value currentStanding = FetchEndpoint(playersEndpoint);
		if (currentStanding.GetType() == Json::Type::Null)
	    {
			warn("could not retrieve player standings from Nadeo API");
			return results;
		}

	    totalPlayers = currentStanding["cardinal"];
		print("NadeoCotdApi: cardinal=" + totalPlayers + " records=" + currentStanding["records"].Length);
	    Json::Value records = currentStanding["records"];

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
	    auto req = NadeoServices::Get("NadeoLiveServices", route);
	    req.Start();
	    while(!req.Finished()) {
	        yield();
	    }
	    string raw = req.String();
	    print("NadeoCotdApi::FetchEndpoint raw response: " + raw);
	    return Json::Parse(raw);
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