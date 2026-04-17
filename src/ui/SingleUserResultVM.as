class SingleUserResultVM 
{
    private int rank;
    private int div;
    private int time;
    private string playerDisplayName;
    private bool isPrediction;
    private bool isCutoff;

    SingleUserResultVM(const int &in rank, const int &in div, const int &in time, const string &in playerDisplayName, const bool &in isPrediction, const bool &in isCutoff) {
        this.rank = rank;
        this.div = div;
        this.time = time;
        this.playerDisplayName = playerDisplayName;
        this.isPrediction = isPrediction;
        this.isCutoff = isCutoff;
    }

    string DivString() {
        return Text::Format("%d", this.div) + "\\$z";
    }

    string TimeString() {
        if (this.isPrediction)
        {
            return "\\$ff0" + Time::Format(this.time) + "\\$z";
        }
        if (this.isCutoff)
        {
            return "\\$f80" + Time::Format(this.time) + "\\$z";
        }
        return "\\$0ff" + Time::Format(this.time) + "\\$z";
    }

    string PlayerDisplayName() {
        return this.playerDisplayName;
    }

    bool IsCutoff() {
        return this.isCutoff;
    }

    int Time() {
        return this.time;
    }

    string RankString() {
        if (this.isPrediction)
        {
            return "\\$ff0-";
        }
        if (this.isCutoff)
        {
            return "\\$f80" + Text::Format("%d", this.rank);
        }
        return "\\$3F0" + Text::Format("%d", this.rank);
    }

    /* Sort by time ascending. On a tie, regular player rows appear before cutoff rows,
        and cutoff rows appear before prediction rows. */
    int opCmp(SingleUserResultVM@ other) {
        int timeDiff = this.time - other.time;
        if (timeDiff != 0) 
        {
            return (timeDiff > 0) ? 1 : -1;
        }
        // Tie-break: regular player (0) < cutoff (1) < prediction (2)
        int myTie = this.isPrediction ? 2 : (this.isCutoff ? 1 : 0);
        int otherTie = other.isPrediction ? 2 : (other.isCutoff ? 1 : 0);
        int tieDiff = myTie - otherTie;
        return (tieDiff == 0) ? 0 : ((tieDiff > 0) ? 1 : -1);
    }

}