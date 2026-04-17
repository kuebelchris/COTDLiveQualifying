# COTDLiveQualifying — Architecture Reference

Openplanet plugin for Trackmania (TM2020). Tracks friends, club members, and custom player lists during the 15-minute Cup of the Day qualifier. Shows live rank, div estimate, and time for each tracked player.

- **Language**: AngelScript (Openplanet dialect) — statically typed, C++-like, no custom generics
- **Plugin ID**: `238` | Author: `KuebelChris` | Category: `Race`
- **Dependency**: `NadeoServices` (Openplanet built-in)
- **Build**: `buildPlugin.ps1` packages the plugin into a `.op` zip for distribution — it does **not** compile or validate code

---

## File Map

```
src/
  Main.as                          # Entry point: Render(), RenderMenu(), Main() coroutine
                                   # Handles permission/cup checks; delegates all logic to services
  Result.as                        # Data model: accountId, rank, div, time (comparable via opCmp)
  services/
    QualifyingSession.as           # Main session loop: loads players, resolves challenge, builds VMs
    PlayerLoaderService.as         # Loads player lists (friends, club, custom) into accountIds[]
    CutoffService.as               # Cutoff row logic + power-law prediction formula
    UserManager.as                 # Display name resolution with dictionary cache; prepends colored club tag
    api/
      NadeoCoreAPI.as              # Game API: GetFriendList, GetPlayerDisplayName, GetMainUserId
      NadeoLiveServicesAPI.as      # Nadeo Live REST: GetClubName, GetAllMemberIdsFromClub, GetAllClubs()
      model/
        ClubInfo.as                # ClubInfo class: id (int), name (string), tag (string)
      cotd/
        ICotdApi.as                # Interface: GetDiv1CutoffTime, GetCurrentStandingForPlayers
        NadeoCotdApi.as            # ICotdApi impl via NadeoServices (primary, default)
        MapMonitorCotdApi.as       # ICotdApi impl via MapMonitor proxy API (backup, best-effort)
        MapMontior.as              # Raw MapMonitor HTTP client — unauthenticated, Net::HttpRequest directly
  settings/
    settings.as                    # All [Setting] attributes (Display/Club/Custom/API categories)
    SettingsInfo.as                # [SettingsTab name="Info"] about/tips panel
    SettingsClubPicker.as          # [SettingsTab name="Club"] — club picker: LoadMyClubs() coroutine, combo + manual ID input
    SettingsCustomPlayers.as       # [SettingsTab name="Custom Players"] — add/remove tracked account IDs with name resolution
  ui/
    CotdApi.as                     # Enum CotdApi { Nadeo=0, MapMonitor=1 }
    COTDClubLiveUI.as              # ImGui window: header table, ranking table, progress bar
    SingleUserResultVM.as          # VM for one player row: colored rank/div/time/name strings; named factory functions
    UserResultVM.as                # VM for full list: selectedModes[] + userResults[]
    VMMapper.as                    # Maps Result[] → SingleUserResultVM[] (resolves display names)
    UIState.as                     # Runtime state mirror of settings + checkSettingsChanged()
```

---

## Data Flow

```
Main() coroutine
  │
  ├── hasPermissionAndIsQualifyingRunning()
  │
  ├── QualifyingSession::RunLoop()
  │     ├── checkSettingsChanged()               [UIState.as]  → compare state_* vs settings_*
  │     │
  │     ├── On change: accountIds = {}  +  ResolveCotdApi()
  │     │
  │     ├── PlayerLoaderService::LoadAll()
  │     │     ├── NadeoLiveServicesAPI::GetAllMemberIdsFromClub()   [club mode]
  │     │     ├── NadeoCoreAPI::GetFriendList()                     [friends mode]
  │     │     ├── settings_customPlayers.Split("\n")                [custom mode]
  │     │     └── AddSelf()                                         [always]
  │     │
  │     ├── NadeoCotdApi::GetCurrentChallengeIdByType()    → state_currentChallengeid
  │     ├── ICotdApi::GetCurrentStandingForPlayers()       → Result[]
  │     ├── CutoffService::AppendCutoffRows()              → adds cutoff/prediction rows
  │     │
  │     ├── VMMapper::ToUserResultVM()           → resolves names via UserManager
  │     └── COTDClubLiveUI::renderUI(vm, progress)
  │
  └── QualifyingSession::AwaitRefresh()          → 15-second sleep loop with progress bar update
```

---

## Interface: ICotdApi

```angelscript
interface ICotdApi {
    Result@ GetDiv1CutoffTime(const int &in challengeid, const string &in mapid);
    array<Result@> GetCurrentStandingForPlayers(
        const array<string> &in players,
        const int &in challengeid,
        const string &in mapid
    );
}
```

Challenge ID resolution (`GetCurrentChallengeIdByType`) is always done via `NadeoCotdApi` directly (not through the interface), since `MapMonitorCotdApi` does not implement it.

Two implementations selected by `settings_cotdApi` (`CotdApi` enum):

- `NadeoCotdApi` — **default**; uses `NadeoServices::BaseURLMeet()` + `"NadeoLiveServices"` audience
- `MapMonitorCotdApi` — **backup**; uses `https://map-monitor.xk.io` via `Net::HttpRequest`, no auth

**Source policy**: Implement new features for Nadeo first. Add MapMonitor support best-effort. Do not block on MapMonitor parity.

---

## Key API Patterns

| Use case                        | API                                                                   |
| ------------------------------- | --------------------------------------------------------------------- |
| Authenticated Nadeo REST        | `NadeoServices::Get("NadeoLiveServices", url)`                        |
| Nadeo COTD challenge/standings  | `NadeoServices::BaseURLMeet() + "/api/cups-of-the-day?type=..."`      |
| Nadeo club/member data          | `NadeoServices::BaseURLLive() + "/api/token/club/<id>/..."`           |
| MapMonitor proxy                | `Net::HttpRequest` — `https://map-monitor.xk.io/cached/api/...`       |
| Game API (friends, names, tags) | `GetApp().UserManagerScript`, `app.ManiaPlanetScriptAPI.UserMgr.*`    |
| Auth guard                      | `NadeoServices::IsAuthenticated("NadeoLiveServices")` before any call |

---

## Settings Pattern

Simple boolean/int/string settings are declared in `settings/settings.as` with `[Setting]` attributes — Openplanet auto-generates their UI:

```angelscript
[Setting category="Club" name="Club id of the club" description="..."]
int settings_clubId = 0;
```

For settings that require interactive UI (dropdowns, dynamic lists, add/remove items), use `[SettingsTab]`-annotated render functions in `settings/`. The club picker and custom player list are both implemented this way:

```angelscript
[SettingsTab name="Custom Players" icon="UserPlus" order="2"]
void RenderSettingsCustomPlayers() { ... }
```

Runtime state is mirrored in `UIState.as`. `checkSettingsChanged()` compares `state_*` vs `settings_*` to trigger reloads.

---

## UIState Pattern

`UIState.as` holds runtime state separate from settings:

- `state_currentChallengeid`, `state_currentClubId`, `state_currentClubName`, `state_activeCupType`
- `state_showClub`, `state_showFriends`, `state_showCustom`, `state_showDivOneCutoff`, `state_showCutoffPrediction`
- `state_cotdApi` — mirrors `settings_cotdApi`; change triggers `ResolveCotdApi()`
- `state_forceRefreshPlayers` — force a reload next loop
- `checkSettingsChanged()` — returns true when any setting diverges from its state mirror

---

## CutoffService

`services/CutoffService.as` handles both the real-time cutoff row and the prediction row:

- `GetSecondsRemaining(app)` — reads `RulesStateEndTime` / `GameTime` from the game to get seconds left in qualifying
- `PredictFinalCutoff(currentCutoffMs, secsRemaining)` — power-law model fitted from recorded sessions:  
  `correction = 1 - 0.0824 × (R / 840)^1.5962`
- `AppendCutoffRows(...)` — appends cutoff and/or prediction `SingleUserResultVM` rows to the display list

The formula constants (`a`, `b`) are updated by running `analysis/fit-formula.ps1` after collecting more session data.

---

## Coding Conventions

- **Always fetch `https://openplanet.dev/docs/api/UI` before using any `UI::` function** — do not guess signatures; `UI::Combo` does not exist, use `UI::BeginCombo` / `UI::Selectable` / `UI::EndCombo`
- All TM2020 code inside `#if TMNEXT` guards — do not remove them
- Coroutines **always** use `yield()` inside `while(!req.Finished())` — never block
- Handle types use `@` prefix: `Result@ r`, null-check with `!is null`
- Display strings use TM color codes: `"\\$f80"` (orange), `"\\$3F0"` (green), `"\\$aaa"` (grey), `"\\$z"` (reset)
- `ColoredString()` utility converts/strips color codes for display
- `NadeoCoreAPI::GetMainUserId()` returns a `MwId` for game script API calls
- `NadeoCoreAPI::getCurrentWebServicesUserId()` returns the player's `accountId` string (UUID)
- `SingleUserResultVM` is constructed via named factory functions (`ToSingleUserResultVM`, `ToSingleUserResultCutoffVM`, `ToSingleUserResultPredictionVM`) — do not construct it directly

---

## Club Picker

- `ClubInfo` class (`services/api/model/ClubInfo.as`): `id` (int), `name` (string), `tag` (string)
- `NadeoLiveServicesAPI::GetAllClubs()` — fetches `GET /api/token/club/mine?offset=0&length=100`, returns `array<ClubInfo@>`
- Club picker state and UI live in `settings/SettingsClubPicker.as` — `g_myClubs`, `LoadMyClubs()` coroutine, `RenderSettingsClubPicker()` tab function
- Manual ID entry available via `UI::InputInt` inside the same tab
- Tag color codes stripped with `Text::StripFormatCodes()` for combo display

---

## Pending TODOs in Codebase

_(none outstanding)_
