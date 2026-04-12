namespace VMMapper 
{

	UserResultVM@ ToUserResultVM(const array<string> &in clubName, const array<SingleUserResultVM@> &in results)
	{
		return UserResultVM(clubName, results);
	}

	array<SingleUserResultVM@> ToSingleUserResultVMs(const array<Result@> &in results)
	{
		array<SingleUserResultVM@> resultVMs = {};
		for(uint n = 0; n < results.Length; n++ )
		{
			Result@ result = results[n];
			SingleUserResultVM@ vm = SingleUserResultVM(result.rank, result.div, result.time, UserManager::GetDisplayNameForAccount(result.accountId));
			resultVMs.InsertLast(vm);
		}
		return resultVMs;
	}

	SingleUserResultVM@ ToSingleUserResultCutoffVM(const Result &in result)
	{
		return SingleUserResultVM(result.rank, result.div, result.time, "Div 1 Cutoff");
	}

	SingleUserResultVM@ ToSingleUserResultCutoffPredictionVM(const Result &in result, const int &in predictedTimeMs)
	{
		return SingleUserResultVM(result.rank, result.div, predictedTimeMs, "Div 1 Cutoff ~", true);
	}

}