namespace PlayerLoader
{
    int friendsRefreshIndicator = 4;

    void LoadAll(bool settingsChanged)
    {
        print("PlayerLoader::LoadAll settingsChanged=" + settingsChanged + " showClub=" + settings_showClub + " showFriends=" + settings_showFriends + " showCustom=" + settings_showCustomPlayers);
        if (settings_showClub && settingsChanged)
        {
            LoadClub();
        }

        if (settings_showFriends)
        {
            LoadFriends(settingsChanged);
        }

        if (settings_showCustomPlayers && settingsChanged && settings_customPlayers.Length >= 36)
        {
            LoadCustomPlayers();
        }

        AddSelf();
        print("PlayerLoader::LoadAll done, accountIds.Length=" + accountIds.Length);
    }

    void LoadClub()
    {
        print("PlayerLoader::LoadClub clubId=" + settings_clubId);
        if (settings_clubId == 0)
        {
            state_currentClubName = "$F33Please select a Club in the settings.";
            return;
        }
        state_currentClubName = NadeoLiveServicesAPI::GetClubName(settings_clubId);
        array<string> members = NadeoLiveServicesAPI::GetAllMemberIdsFromClub(settings_clubId, QualifyingSession::GetMaxTrackedPlayers());
        print("PlayerLoader::LoadClub fetched " + members.Length + " members");
        AddAccountIds(members);
    }

    void LoadFriends(bool settingsChanged)
    {
        friendsRefreshIndicator++;
        print("PlayerLoader::LoadFriends indicator=" + friendsRefreshIndicator + " settingsChanged=" + settingsChanged);
        if (settingsChanged || friendsRefreshIndicator >= 4)
        {
            array<string> friends = NadeoCoreAPI::GetFriendList(QualifyingSession::GetMaxTrackedPlayers());
            print("PlayerLoader::LoadFriends fetched " + friends.Length + " friends");
            AddAccountIds(friends);
            friendsRefreshIndicator = 0;
        }
    }

    void LoadCustomPlayers()
    {
        state_customPlayerListArray = settings_customPlayers.Split("\n");
        AddAccountIds(state_customPlayerListArray);
    }

    void AddSelf()
    {
        string currentUserId = NadeoCoreAPI::getCurrentWebServicesUserId();
        if (accountIds.Find(currentUserId) < 0)
        {
            accountIds.InsertLast(currentUserId);
        }
    }

    void AddAccountIds(array<string> fetchedPlayers)
    {
        uint maxPlayers = QualifyingSession::GetMaxTrackedPlayers();
        for (uint p = 0; p < fetchedPlayers.Length; p++)
        {
            if (accountIds.Find(fetchedPlayers[p]) < 0 && accountIds.Length < maxPlayers)
            {
                accountIds.InsertLast(fetchedPlayers[p]);
            }
        }
    }
}
