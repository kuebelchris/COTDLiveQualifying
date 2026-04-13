class RankingModel
{
    array<SingleUserResultVM@> userResults;
    string selectedModesDescription;
    int totalPlayers;

    RankingModel()
    {
        this.userResults = {};
        this.selectedModesDescription = "";
        this.totalPlayers = 0;
    }

    RankingModel(
        const array<SingleUserResultVM@> &in userResults,
        const string &in selectedModesDescription,
        int totalPlayers
    ) {
        this.userResults = userResults;
        this.selectedModesDescription = selectedModesDescription;
        this.totalPlayers = totalPlayers;
    }
}
