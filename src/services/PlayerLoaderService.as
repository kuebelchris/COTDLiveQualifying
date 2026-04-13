namespace PlayerLoaderService
{
    int friendsRefreshIndicator = 4;

    void LoadClubAndCustomPlayers()
    {
        if (settings_showClub)
        {
            LoadClub();
        }

        if (settings_showCustomPlayers && settings_customPlayers.Length >= 36)
        {
            LoadCustomPlayers();
        }

        AddSelf();
    }

    void LoadClub()
    {
        if (settings_clubId == 0)
        {
            state_currentClubName = "$F33Please select a Club in the settings.";
            return;
        }
        state_currentClubName = NadeoLiveServicesAPI::GetClubName(settings_clubId);
        array<string> members = NadeoLiveServicesAPI::GetAllMemberIdsFromClub(settings_clubId, QualifyingSession::GetMaxTrackedPlayers());
        AddAccountIds(members);
    }

    void LoadFriends(bool settingsChanged)
    {
        friendsRefreshIndicator++;
        if (settingsChanged || friendsRefreshIndicator >= 4)
        {
            array<string> friends = NadeoCoreAPI::GetFriendList(QualifyingSession::GetMaxTrackedPlayers());
            AddAccountIds(friends);
            friendsRefreshIndicator = 0;
        }
    }

    void LoadCustomPlayers()
    {
        AddAccountIds(settings_customPlayers.Split("\n"));
    }

    void AddSelf()
    {
        string currentUserId = NadeoCoreAPI::getCurrentWebServicesUserId();
        if (state_accountIds.Find(currentUserId) < 0)
        {
            state_accountIds.InsertLast(currentUserId);
        }
    }

    void AddAccountIds(array<string> fetchedPlayers)
    {
        uint maxPlayers = QualifyingSession::GetMaxTrackedPlayers();
        for (uint p = 0; p < fetchedPlayers.Length; p++)
        {
            if (state_accountIds.Find(fetchedPlayers[p]) < 0 && state_accountIds.Length < maxPlayers)
            {
                state_accountIds.InsertLast(fetchedPlayers[p]);
            }
        }
    }
}
