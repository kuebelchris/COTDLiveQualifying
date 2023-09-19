namespace NadeoLiveServicesAPI
{
	int GetCurrentCOTDChallengeId()
	{
		auto matchstatus = MapMonitor::GetCotdCurrent();
	    string challengeName = matchstatus["challenge"]["name"];
	    return matchstatus["challenge"]["id"];
	}


	string GetClubName(const int &in clubId)
	{
		string nadeoURL = NadeoServices::BaseURL();

		if (clubId == 0)
		{
			return "Please select a Club in the settings";
		}
	    Json::Value@ clubInfo = FetchEndpointLiveServices(nadeoURL + "/api/token/club/" + clubId);
	    //Check if result was found
	    if (clubInfo.Length > 1)
	    {
	    	return clubInfo["name"];
	    }
	    else
	    {
	    	return "Could not load club";
	    }

	}

	array<string> GetAllMemberIdsFromClub(const int &in clubId)
	{
	    string nadeoURL = NadeoServices::BaseURL();
		int offset = 0;
		int length = 100;

		array<string> clubMembers = {};
	    if (clubId == 0)
	    {
	    	return clubMembers;
	    }

		int maxPage = 1;
		int currPage = 0;
		int itemCount = -1;
		while (currPage < maxPage) {
			Json::Value@ clubInfo = FetchEndpointLiveServices(nadeoURL + "/api/token/club/" + clubId + "/member?offset=" + offset + "&length=" + length);
			if (clubInfo.Length <= 1) {
				break;
			}
			Json::Value@ members = clubInfo["clubMemberList"];
			maxPage = clubInfo['maxPage'];
			itemCount = clubInfo['itemCount'];
			offset += length;
			currPage += 1;

			for(uint n = 0; n < members.Length && n < 100; n++) {
				string accountId = members[n]["accountId"];
				clubMembers.InsertLast(accountId);
			}
		}

	    return clubMembers;
	}

	//TODO for later: feature to select a club via UI Dropdown.
	/*array<ClubSelectItem@> GetAllCLubs()
	{
		string nadeoURL = NadeoServices::BaseURL();

		Json::Value clubResult = FetchEndpointLiveServices(nadeoURL + "/api/token/club/mine?offset=0&length=100");
		Json::Value clubList = clubResult["clubList"];

		array<ClubSelectItem@> clubs;
		for (uint n = 0; n < clubList.Length; n++)
		{
			int clubId = clubList[n]["id"];
			string name = clubList[n]["name"];

			Json::Value memberInfo = FetchEndpointLiveServices(nadeoURL + "/api/token/club/" + Text::Format("%d", clubId) + "/member?offset=0&length=1");
			int memberCount = memberInfo["itemCount"];

			clubs.InsertLast(ClubSelectItem(name, clubId, memberCount));
		}

	    return clubs;
	}*/

	Result@ GetDiv1CutoffTime(const int &in challengeid, const string &in mapid)
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

	array<Result@> GetCurrentStandingForPlayers(const array<string> &in players, const int &in challengeid, const string &in mapid)
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

	Json::Value@ FetchEndpoint(const string &in route) {
	    auto req = NadeoServices::Get("NadeoClubServices", route);
	    req.Start();
	    while(!req.Finished()) {
	        yield();
	    }
	    return Json::Parse(req.String());
	}

	Json::Value@ FetchEndpointLiveServices(const string &in route) {
	    auto req = NadeoServices::Get("NadeoLiveServices", route);
	    req.Start();
	    while(!req.Finished()) {
	        yield();
	    }
	    return Json::Parse(req.String());
	}
}
