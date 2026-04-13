// Remote plugin config fetched from https://api.openplanet.dev/plugin/cotdlivequalifying/config/<name>
// All fields carry sane defaults so the plugin functions correctly even if the fetch fails.

class PredictionConfig {
    // Coefficient in: correction = 1 - a * (secsRemaining / 840)^b
    float a = 0.0824f;
    // Exponent in the power-law decay formula
    float b = 1.5962f;
    // AR(1) residual correction weight (lambda).
    // predicted = staticPred + lambda * (currentCutoff - staticPred(prev))
    float lambda = 0.45f;
    // Maximum seconds left in qualifying at which the prediction row is shown
    int windowSecs = 300;
}

namespace ConfigService {
    const string CONFIG_BASE_URL = "https://api.openplanet.dev/plugin/cotdlivequalifying/config/";

    PredictionConfig@ g_predictionConfig = PredictionConfig();

    // Fetches all remote configs. Called once per qualifying session on first RunLoop.
    void FetchAll() {
        FetchPredictionConfig();
        state_configLoaded = true;
    }

    // Resets config data so it is re-fetched on the next qualifying session.
    void Reset() {
        @g_predictionConfig = PredictionConfig();
        state_configLoaded = false;
    }

    void FetchPredictionConfig() {
        Json::Value@ json = FetchConfig("cotd-prediction");
        if (json is null || json.GetType() == Json::Type::Null) {
            warn("[ConfigService] Could not load prediction config, using defaults.");
            return;
        }

        PredictionConfig config;
        if (json["a"].GetType() == Json::Type::Number) {
            config.a = float(json["a"]);
        }
        if (json["b"].GetType() == Json::Type::Number) {
            config.b = float(json["b"]);
        }
        if (json["window_secs"].GetType() == Json::Type::Number) {
            config.windowSecs = int(json["window_secs"]);
        }
        if (json["lambda"].GetType() == Json::Type::Number) {
            config.lambda = float(json["lambda"]);
        }
        @g_predictionConfig = config;
        trace("[ConfigService] Loaded prediction config: a=" + config.a + " b=" + config.b + " windowSecs=" + config.windowSecs);
    }

    Json::Value@ FetchConfig(const string &in name) {
        string url = CONFIG_BASE_URL + name;
        Net::HttpRequest@ req = Net::HttpRequest();
        req.Url = url;
        auto plugin = Meta::ExecutingPlugin();
        req.Headers['User-Agent'] = plugin.Name + '/' + plugin.Version + '/Openplanet-Plugin/contact=@' + plugin.Author;
        req.Start();
        while (!req.Finished()) { yield(); }
        return Json::Parse(req.String());
    }
}
