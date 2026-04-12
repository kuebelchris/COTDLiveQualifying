namespace NadeoLiveServicesAPI
{
	
	string GetClubName(const uint &in clubId)
	{
		string nadeoURL = NadeoServices::BaseURLLive();

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

	array<string> GetAllMemberIdsFromClub(const int &in clubId, const int &in maximum)
	{
		string nadeoURL = NadeoServices::BaseURLLive();
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
		while (currPage < Math::Min(10, maxPage)) {
			Json::Value@ clubInfo = FetchEndpointLiveServices(nadeoURL + "/api/token/club/" + clubId + "/member?offset=" + offset + "&length=" + length);
			if (clubInfo.Length <= 1) {
				break;
			}
			Json::Value@ members = clubInfo["clubMemberList"];
			maxPage = clubInfo['maxPage'];
			itemCount = clubInfo['itemCount'];
			offset += length;
			currPage += 1;

			for(uint n = 0; n < members.Length; n++) {
				string accountId = members[n]["accountId"];
				clubMembers.InsertLast(accountId);
			}
			if (offset == maximum)
			{
				break;
			}
			else if (offset > maximum)
			{
				length = maximum - offset;
			}
		}
		if (maxPage > 10) {
			auto msg = "Your chosen club has more than 1000 members, but only the first 1000 members are loaded and checked.";
			UI::ShowNotification(Meta::ExecutingPlugin().Name, msg, vec4(1, .5, 0, 1), 12500);
			warn(msg);
		}

	    return clubMembers;
	}

	array<ClubInfo@> GetAllClubs()
	{
		array<ClubInfo@> clubs;
		string nadeoURL = NadeoServices::BaseURLLive();

		Json::Value@ clubResult = FetchEndpointLiveServices(nadeoURL + "/api/token/club/mine?offset=0&length=100");
		if (clubResult.GetType() == Json::Type::Null) {
			return clubs;
		}

		Json::Value@ clubList = clubResult["clubList"];
		for (uint n = 0; n < clubList.Length; n++) {
			int clubId = clubList[n]["id"];
			string name = clubList[n]["name"];
			string tag = clubList[n]["tag"];
			clubs.InsertLast(ClubInfo(clubId, name, tag));
		}

		return clubs;
	}

	// Returns the map UID for the current Cup of the Week map.
	// Endpoint: GET /api/campaign/cup-of-the-week?length=1
	string GetCotwMapUid()
	{
		string nadeoURL = NadeoServices::BaseURLLive();
		Json::Value@ data = FetchEndpointLiveServices(nadeoURL + "/api/campaign/cup-of-the-week?length=1&offset=0");
		if (data.GetType() == Json::Type::Null) { 
			return ""; 
		}
		Json::Value@ list = data["campaignList"];
		if (list.GetType() != Json::Type::Array || list.Length == 0) { 
			return ""; 
		}
		Json::Value@ playlist = list[0]["playlist"];
		if (playlist.GetType() != Json::Type::Array || playlist.Length == 0) { 
			return ""; 
		}
		return playlist[0]["mapUid"];
	}

	// Returns the map UID for the current Grand Enduro map.
	// Endpoint: GET /api/campaign/weekly-grands?length=1
	string GetGrandEnduroMapUid()
	{
		string nadeoURL = NadeoServices::BaseURLLive();
		Json::Value@ data = FetchEndpointLiveServices(nadeoURL + "/api/campaign/weekly-grands?length=1&offset=0");
		if (data.GetType() == Json::Type::Null) { 
			return ""; 
		}
		Json::Value@ list = data["campaignList"];
		if (list.GetType() != Json::Type::Array || list.Length == 0) { 
			return ""; 
		}
		Json::Value@ playlist = list[0]["playlist"];
		if (playlist.GetType() != Json::Type::Array || playlist.Length == 0) { 
			return ""; 
		}
		return playlist[0]["mapUid"];
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
