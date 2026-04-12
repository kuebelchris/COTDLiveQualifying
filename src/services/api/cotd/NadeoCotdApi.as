class NadeoCotdApi : ICotdApi
{
	// Returns the qualifier challenge ID for the current cup.
	// type: "cotd" | "cotw" | "grand_race"
	// Finds the first crossplay entry where now is between (startDate - 2 min) and endDate.
	// Returns 0 if qualifying has not started yet or has already ended.
	int GetCurrentChallengeIdByType(const string &in type)
	{
		string compUrl = NadeoServices::BaseURLMeet();
		//Usually, we will get 15 entries for a whole set of daily cotds (evening, night and morning COTD for crossplay, pc, luna, xb1 and psn), so we need to at least get the 15 newest cups to find the currently active one.
		Json::Value@ data = FetchEndpoint(compUrl + "/api/cups-of-the-day?type=" + type + "&length=20&offset=0");
		if (data.GetType() == Json::Type::Null)
		{
			warn("could not retrieve cups-of-the-day for type=" + type);
			return 0;
		}
		Json::Value@ cups = data["COTDs"];
		if (cups.GetType() != Json::Type::Array || cups.Length == 0)
		{
			warn("no cups found for type=" + type);
			return 0;
		}

		int64 now = Time::Stamp;

		for (uint i = 0; i < cups.Length; i++)
		{
			Json::Value@ cup = cups[i];
			string partition = cup["competition"]["partition"];
			if (partition != "crossplay")
			{
				continue;
			}

			int64 startDate = int64(cup["startDate"]) - 120; // 2 min early, servers open a minute before the qualifying officially starts
			int64 endDate   = int64(cup["endDate"]);

			if (now < startDate)
			{
				continue;
			}
			if (now > endDate)
			{
				continue;
			}

			int challengeId = cup["challenge"]["id"];
			return challengeId;
		}

		warn("no active cup found for type=" + type + "; qualifying has not started yet or has already ended");
		return 0;
	}

	Result@ GetDiv1CutoffTime(const int&in challengeid, const string&in mapid)
	{
        string compUrl = NadeoServices::BaseURLMeet();
		string cotdEndpoint = compUrl + "/api/challenges/" + challengeid + "/records/maps/" + mapid + "?offset=63&length=1";
		Json::Value divOneCutoff = FetchEndpoint(cotdEndpoint);

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

        string compUrl = NadeoServices::BaseURLMeet();
	    string playersEndpoint = compUrl + "/api/challenges/" + challengeid + "/records/maps/" + mapid + "/players?players[]=";

	    for(uint n = 0; n < players.Length; n++ )
	    {
	        playersEndpoint += "&players[]=" + players[n];
	    }

	    Json::Value currentStanding = FetchEndpoint(playersEndpoint);
		if (currentStanding.GetType() == Json::Type::Null)
	    {
			warn("could not retrieve player standings from Nadeo API");
			return results;
		}

	    totalPlayers = currentStanding["cardinal"];
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