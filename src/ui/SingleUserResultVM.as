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
        if (this.rank == 64)
        {
            return "\\$f80" + Time::Format(this.time) + "\\$z";
        }
        return "\\$0ff" + Time::Format(this.time) + "\\$z";
    }

    string PlayerDisplayName() {
        return this.playerDisplayName;
    }

    string RankString() {
        if (this.rank == 64)
        {
            return "\\$f80" + Text::Format("%d", this.rank);
        }
        return "\\$3F0" + Text::Format("%d", this.rank);
    }

    int opCmp(SingleUserResultVM@ other) {
        int diff = this.time - other.time;
        return (diff == 0) ? 0 : ((diff > 0) ? 1 : -1);
    }

}