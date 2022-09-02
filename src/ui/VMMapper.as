namespace VMMapper 
{

	UserResultVM@ ToUserResultVM(const string &in clubName, const array<Result@> &in results)
	{
		array<SingleUserResultVM@> resultVMs = {};
		for(uint n = 0; n < results.Length; n++ )
		{
			Result@ result = results[n];
			resultVMs.InsertLast(SingleUserResultVM(result.rank, result.div, result.time, UserManager::GetDisplayNameForAccount(result.accountId)));
		}
		return UserResultVM(clubName, resultVMs);
	}

}