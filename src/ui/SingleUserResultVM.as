class SingleUserResultVM 
{
    private int rank;
    private int div;
    private int time;
    private string playerDisplayName;
    private bool isPrediction;

    SingleUserResultVM(const int &in rank, const int &in div, const int &in time, const string &in playerDisplayName) {
        this.rank = rank;
        this.div = div;
        this.time = time;
        this.playerDisplayName = playerDisplayName;
        this.isPrediction = false;
    }

    SingleUserResultVM(const int &in rank, const int &in div, const int &in time, const string &in playerDisplayName, const bool &in isPrediction) {
        this.rank = rank;
        this.div = div;
        this.time = time;
        this.playerDisplayName = playerDisplayName;
        this.isPrediction = isPrediction;
    }

    string DivString() {
        return Text::Format("%d", this.div) + "\\$z";
    }

    string TimeString() {
        if (this.isPrediction)
        {
            return "\\$ff0" + Time::Format(this.time) + "\\$z";
        }
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
        if (this.isPrediction)
        {
            return "\\$ff0" + Text::Format("%d", this.rank);
        }
        if (this.rank == 64)
        {
            return "\\$f80" + Text::Format("%d", this.rank);
        }
        return "\\$3F0" + Text::Format("%d", this.rank);
    }

    int opCmp(SingleUserResultVM@ other) {
        int diff = this.rank - other.rank;
        return (diff == 0) ? 0 : ((diff > 0) ? 1 : -1);
    }

}