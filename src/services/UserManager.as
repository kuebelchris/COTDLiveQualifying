namespace UserManager 
{
	dictionary displayNameCache = {};

	string GetDisplayNameForAccount(const string &in accountId)
	{
		//If displayName is known already, get it from dict. Otherwise get from the game
	    if(displayNameCache.Exists(accountId))
	    {
	        string foundDisplayName;
	        displayNameCache.Get(accountId, foundDisplayName);
	        if(foundDisplayName == "")
	        {
	        	return getDisplayNameFromCoreAPI(accountId);
	        }
	        return foundDisplayName;
	    }
	    else 
	    {
	    	return getDisplayNameFromCoreAPI(accountId);
	    }	
	}

	string getDisplayNameFromCoreAPI(const string &in accountId)
	{
		string displayName = NadeoCoreAPI::GetPlayerDisplayName(accountId);
		if (setttings_showClubTag)
		{
			string unformattedClubTag = NadeoCoreAPI::GetPlayerTag(accountId);
			if (unformattedClubTag != "")
			{
				displayName = "[" + Text::OpenplanetFormatCodes(unformattedClubTag) + "\\$z] " + displayName;
			}
		}
		
		return displayName;
	}
}
