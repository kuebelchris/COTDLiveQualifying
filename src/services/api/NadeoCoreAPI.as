namespace NadeoCoreAPI {

	array<string> GetFriendList() {
		array<string> FriendList;
		auto app = cast<CTrackMania>(GetApp());
		
		CWebServicesTaskResult_FriendListScript@ friendListResult = app.ManiaPlanetScriptAPI.UserMgr.Friend_GetList(GetMainUserId());
		while (friendListResult.IsProcessing) yield();
		if (friendListResult.HasSucceeded) {
			MwFastBuffer<CFriend@> uplayFriendList = friendListResult.FriendList;
			for (uint i = 0; i < uplayFriendList.Length; i++) {
				if ((settings_showOfflineFriends || uplayFriendList[i].Presence != "Offline") && uplayFriendList.Length < 100)
				{
					FriendList.InsertLast(uplayFriendList[i].AccountId);
				}
			}
		} else {
			print("error getting uplay FriendList");
		}
		app.ManiaPlanetScriptAPI.UserMgr.TaskResult_Release(friendListResult.Id);

		return FriendList;
	}

	string GetPlayerDisplayName(const string &in accountId) 
	{
        auto ums = GetApp().UserManagerScript;
        MwFastBuffer<wstring> playerIds = MwFastBuffer<wstring>();
        playerIds.Add(accountId);
       
        auto req = ums.GetDisplayName(GetMainUserId(), playerIds);
        while (req.IsProcessing) 
        {
        	yield();
        }
        
        string[] playerNames = array<string>(playerIds.Length);
        for (uint i = 0; i < playerIds.Length; i++) 
        {
            playerNames[i] = string(req.GetDisplayName(wstring(playerIds[i])));
        }
        return playerNames[0];
    }

    string GetPlayerTag(const string &in accountId)
    {
    	auto ums = GetApp().UserManagerScript;
        MwFastBuffer<wstring> playerIds = MwFastBuffer<wstring>();
        playerIds.Add(accountId);
       
        auto req = ums.Tag_GetClubTagList(GetMainUserId(), playerIds);
        while (req.IsProcessing) 
        {
        	yield();
        }
        
        string[] playerNames = array<string>(playerIds.Length);
        for (uint i = 0; i < playerIds.Length; i++) 
        {
            playerNames[i] = string(req.GetClubTag(wstring(playerIds[i])));
        }
        return playerNames[0];
    }


	MwId GetMainUserId() {
		auto app = cast<CTrackMania>(GetApp());
		if (app.ManiaPlanetScriptAPI.UserMgr.MainUser !is null) {
			return app.ManiaPlanetScriptAPI.UserMgr.MainUser.Id;
		}
		if (app.ManiaPlanetScriptAPI.UserMgr.Users.Length >= 1) {
			return app.ManiaPlanetScriptAPI.UserMgr.Users[0].Id;
		} else {
			return MwId();
		}
	}

	string getCurrentWebServicesUserId() {
		auto app = cast<CTrackMania>(GetApp());
		return cast<CTrackManiaPlayerInfo>(cast<CTrackManiaNetwork>(app.Network).PlayerInfo).WebServicesUserId;
	}

}

