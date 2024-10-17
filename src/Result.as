class Result {
    string accountId;
    int rank;
    int div;
    int time;

    Result(const string &in accountId, const int &in rank, const int &in div, const int &in time) {
        this.accountId = accountId;
        this.rank = rank;
        this.div = div;
        this.time = time;
    }

    int opCmp(Result@ other) {
        int diff = this.rank - other.rank;
        return (diff == 0) ? 0 : ((diff > 0) ? 1 : -1);
    }
}