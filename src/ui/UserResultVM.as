class UserResultVM
{
    string clubName;
    array<SingleUserResultVM@> userResults;

    UserResultVM()
    {
        this.clubName = "--";
        this.userResults = {};
    }

    UserResultVM(const string &in clubName, const array<SingleUserResultVM@> &in userResults)
    {
        this.clubName = clubName;
        this.userResults = userResults;
    }
}