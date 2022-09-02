class SingleUserResultVM 
{
    private int rank;
    private int div;
    private int time;
    private string playerDisplayName;

    SingleUserResultVM(const int &in rank, const int &in div, const int &in time, const string &in playerDisplayName) {
        this.rank = rank;
        this.div = div;
        this.time = time;
        this.playerDisplayName = playerDisplayName;
    }

    string DivString() {
        return Text::Format("%d", this.div) + "\\$z";
    }

    string TimeString() {
        return "\\$0ff" + Time::Format(this.time) + "\\$z";
    }

    string PlayerDisplayName() {
        return this.playerDisplayName;
    }

    string RankString() {
        return "\\$3F0" + Text::Format("%d", this.rank);
    }

}