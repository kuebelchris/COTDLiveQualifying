class RankingModel
{
    array<SingleUserResultVM@> userResults;
    string selectedModesDescription;
    int totalPlayers;
    int secsRemaining;

    RankingModel()
    {
        this.userResults = {};
        this.selectedModesDescription = "";
        this.totalPlayers = 0;
        this.secsRemaining = 900;
    }

    RankingModel(
        const array<SingleUserResultVM@> &in userResults,
        const string &in selectedModesDescription,
        int totalPlayers,
        int secsRemaining = 900
    ) {
        this.userResults = userResults;
        this.selectedModesDescription = selectedModesDescription;
        this.totalPlayers = totalPlayers;
        this.secsRemaining = secsRemaining;
    }
}
