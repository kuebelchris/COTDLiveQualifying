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

    /* Sort by rank. Cutoff and prediction rows use a artificial high rank so they always
        appear below real player rows on a tie. */
    int opCmp(SingleUserResultVM@ other) {
        int myRank    = this.isPrediction ? 0x7FFFFFFF : (this.isCutoff ? 0x7FFFFFFE : this.rank);
        int otherRank = other.isPrediction ? 0x7FFFFFFF : (other.isCutoff ? 0x7FFFFFFE : other.rank);
        int rankDiff = myRank - otherRank;
        return (rankDiff == 0) ? 0 : ((rankDiff > 0) ? 1 : -1);
    }

}