 // The interface declaration
  interface ICotdApi
  {
    int GetCurrentCOTDChallengeId();

    Result@ GetDiv1CutoffTime(const int &in challengeid, const string &in mapid);

    array<Result@> GetCurrentStandingForPlayers(const array<string> &in players, const int &in challengeid, const string &in mapid);
  }