class UserResultVM
{
    array<string> selectedModes;
    array<SingleUserResultVM@> userResults;

    UserResultVM()
    {
        this.selectedModes = {};
        this.userResults = {};
    }

    UserResultVM(const array<string> &in clubName, const array<SingleUserResultVM@> &in userResults)
    {
        this.selectedModes = clubName;
        this.userResults = userResults;
    }
}