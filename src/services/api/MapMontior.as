const string MM_API_PROD_ROOT = "https://map-monitor.xk.io";
const string MM_API_DEV_ROOT = "http://localhost:8000";

// requires `defines = ["DEV"]` in info.toml
#if DEV
[Setting category="[DEV] Debug" name="Local Dev Server"]
bool S_LocalDev = true;
#else
bool S_LocalDev = false;
#endif

const string MM_API_ROOT {
    get {
        if (S_LocalDev) return MM_API_DEV_ROOT;
        else return MM_API_PROD_ROOT;
    }
}

namespace MapMonitor {
    Json::Value@ GetNbPlayersForMap(const string &in mapUid) {
        return CallMapMonitorApiPath('/map/' + mapUid + '/nb_players/refresh');
    }

    Json::Value@ GetCotdCurrent() {
        return CallMapMonitorApiPath("/cached/api/cup-of-the-day/current");
    }

    Json::Value@ GetChallengeRecords(int challengeId, const string &in mapUid, uint length, uint offset) {
        return CallMapMonitorApiPath("/cached/api/challenges/" + challengeId + "/records/maps/" + mapUid + "?" + LengthAndOffset(length, offset));
    }

    Json::Value@ GetChallengeCutoffs(int challengeId, const string &in mapUid) {
        return CallMapMonitorApiPath("/cached/api/challenges/" + challengeId + "/records/maps/" + mapUid + "?cutoffs");
    }

    Json::Value@ GetPlayerRank(int challengeid, const string &in mapid, const string &in userId) {
        return CallMapMonitorApiPath("/cached/api/challenges/" + challengeid + "/records/maps/" + mapid + "/players?players[]=" + userId);
    }

    Json::Value@ GetPlayersRank(int challengeid, const string &in mapid, const string[]&in userIds) {
        auto data = Json::Object();
        data['players'] = Json::Array();
        for (uint i = 0; i < userIds.Length; i++) {
            data['players'].Add(userIds[i]);
        }
        return CallMapMonitorApiPath("/cached/api/challenges/" + challengeid + "/records/maps/" + mapid + "/players", Net::HttpMethod::Post, data);
    }

    Json::Value@ CallMapMonitorApiPath(const string &in path, Net::HttpMethod method = Net::HttpMethod::Get, Json::Value@ postData = null) {
        auto url = MM_API_ROOT + path;
        // trace("[CallMapMonitorApiPath] Requesting: " + url);
        Net::HttpRequest@ req = Net::HttpRequest();
        req.Url = url;
        auto plugin = Meta::ExecutingPlugin();
        req.Headers['User-Agent'] = plugin.Name + '/' + plugin.Version + '/Openplanet-Plugin/contact=@' + plugin.Author;
        req.Method = method;
        if (method == Net::HttpMethod::Post && postData !is null) {
            req.Body = Json::Write(postData);
        }
        req.Start();
        while(!req.Finished()) { yield(); }
        auto respStr = req.String();
        // trace("[CallMapMonitorApiPath] Response: " + respStr);
        return Json::Parse(respStr);
    }

    const string LengthAndOffset(uint length, uint offset) {
        return "length=" + length + "&offset=" + offset;
    }
}
