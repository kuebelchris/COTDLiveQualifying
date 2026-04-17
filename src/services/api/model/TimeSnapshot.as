// Captures a player's time and rank at a specific point during the qualifying session
class TimeSnapshot {
    string accountId;
    int timeMs;      // Player's current best time in milliseconds
    int secsRemaining; // Seconds remaining at this snapshot point
    int rank;        // Player's rank at this snapshot
    
    TimeSnapshot(const string &in accountId, const int &in timeMs, const int &in secsRemaining, const int &in rank) {
        this.accountId = accountId;
        this.timeMs = timeMs;
        this.secsRemaining = secsRemaining;
        this.rank = rank;
    }
}

// Tracks all time snapshots for a single player across the qualifying session
class PlayerTimeSeries {
    string accountId;
    string displayName; // Cached for UI display
    array<TimeSnapshot@> snapshots;
    
    PlayerTimeSeries(const string &in accountId, const string &in displayName) {
        this.accountId = accountId;
        this.displayName = displayName;
        this.snapshots = {};
    }
    
    void AddSnapshot(const int &in timeMs, const int &in secsRemaining, const int &in rank) {
        snapshots.InsertLast(TimeSnapshot(accountId, timeMs, secsRemaining, rank));
    }
    
    // Get the first/best time recorded for this player
    int GetFirstTime() {
        if (snapshots.Length > 0) {
            return snapshots[0].timeMs;
        }
        return -1;
    }
    
    // Get the latest time recorded for this player
    int GetLatestTime() {
        if (snapshots.Length > 0) {
            return snapshots[snapshots.Length - 1].timeMs;
        }
        return -1;
    }
}
