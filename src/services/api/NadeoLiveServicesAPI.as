namespace NadeoLiveServicesAPI
{
	int GetCurrentCOTDChallengeId()
	{
	    string compUrl = NadeoServices::BaseURLCompetition();
	    auto matchstatus = FetchEndpoint(compUrl + "/api/daily-cup/current");
	    string challengeName = matchstatus["challenge"]["name"];
	    return matchstatus["challenge"]["id"];
	}


	string GetClubName(const int &in clubId)
	{
		string nadeoURL = NadeoServices::BaseURL();

	    Json::Value clubInfo = FetchEndpointLiveServices(nadeoURL + "/api/token/club/" + Text::Format("%d", clubId));
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

	array<string> GetMemberIdsFromClub(const int &in clubId, const int &in offset, const int &in length)
	{
	    string nadeoURL = NadeoServices::BaseURL();

	    Json::Value clubInfo = FetchEndpointLiveServices(nadeoURL + "/api/token/club/" + Text::Format("%d", clubId) + "/member?offset=" + Text::Format("%d", offset) + "&length=" + Text::Format("%d", length));
	    //Check if result was found
	    if (clubInfo.Length <= 1)
	    {
	    	return {};
	    }
	    Json::Value members = clubInfo["clubMemberList"];

	    array<string> clubMembers = {};
	    for(uint n = 0; n < members.Length; n++)
	    {
	        string accountId = members[n]["accountId"];
	        clubMembers.InsertLast(accountId);
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

	array<Result@> GetCurrentStandingForPlayers(const array<string> &in players, const int &in challengeid, const string &in mapid)
	{
	    string compUrl = NadeoServices::BaseURLCompetition();
	    string playersString = string::Join(players, ",");
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
            	if (playerResult.get_Length() > 0)
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

	Json::Value FetchEndpoint(const string &in route) {
	    auto req = NadeoServices::Get("NadeoClubServices", route);
	    req.Start();
	    while(!req.Finished()) {
	        yield();
	    }
	    return Json::Parse(req.String());
	}

	Json::Value FetchEndpointLiveServices(const string &in route) {
	    auto req = NadeoServices::Get("NadeoLiveServices", route);
	    req.Start();
	    while(!req.Finished()) {
	        yield();
	    }
	    return Json::Parse(req.String());
	}
}