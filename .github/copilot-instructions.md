# COTDLiveQualifying — Architecture Reference

Openplanet plugin for Trackmania (TM2020). Tracks friends, club members, and custom player lists during the 15-minute Cup of the Day qualifier. Shows live rank, div estimate, and time for each tracked player.

- **Language**: AngelScript (Openplanet dialect) — statically typed, C++-like, no custom generics
- **Plugin ID**: `238` | Author: `KuebelChris` | Category: `Race`
- **Dependency**: `NadeoServices` (Openplanet built-in)
- **Build**: `buildPlugin.bat` packages the plugin into a `.op` zip for distribution — it does **not** compile or validate code

---

## File Map

```
src/
  Main.as                          # Coroutine entry: Render(), RenderMenu(), Main() loop
  Result.as                        # Data model: accountId, rank, div, time (comparable via opCmp)
  services/
    UserManager.as                 # Display name resolution with dictionary cache; prepends colored club tag
    api/
      NadeoCoreAPI.as              # Game API: GetFriendList, GetPlayerDisplayName, GetPlayerTag, GetMainUserId
      NadeoLiveServicesAPI.as      # Nadeo Live REST: GetClubName, GetAllMemberIdsFromClub, GetAllClubs()
      ClubInfo.as                  # ClubInfo class: id (int), name (string), tag (string)
      cotd/
        ICotdApi.as                # Interface: GetCurrentCOTDChallengeId, GetDiv1CutoffTime, GetCurrentStandingForPlayers
        NadeoCotdApi.as            # ICotdApi impl via NadeoServices (primary, default)
        MapMonitorCotdApi.as       # ICotdApi impl via MapMonitor proxy API (backup, best-effort)
        MapMontior.as              # Raw MapMonitor HTTP client — unauthenticated, Net::HttpRequest directly
  settings/
    settings.as                    # All [Setting] attributes (Display/Club/Custom/API categories)
    SettingsInfo.as                # [SettingsTab name="Info"] about/tips panel
    SettingsClubPicker.as          # [SettingsTab name="Club" order="2"] — club picker: state, LoadMyClubs() coroutine, combo + manual ID input
  ui/
    CotdApi.as                     # Enum CotdApi { Nadeo=0, MapMonitor=1 }
    COTDClubLiveUI.as              # ImGui window: header table, ranking table, progress bar
    SingleUserResultVM.as          # VM for one player row: colored rank/div/time/name strings
    UserResultVM.as                # VM for full list: selectedModes[] + userResults[]
    VMMapper.as                    # Maps Result[] → SingleUserResultVM[] (resolves display names)
    UIState.as                     # Runtime state mirror of settings + checkSettingsChanged()
```

---

## Data Flow

```
Main() coroutine
  │
  ├── checkSettingsChanged()         [UIState.as]  → compare state_* vs settings_*
  │
  ├── On change: reload player lists
  │     ├── NadeoLiveServicesAPI::GetAllMemberIdsFromClub()   [club mode]
  │     ├── NadeoCoreAPI::GetFriendList()                     [friends mode]
  │     └── settings_customPlayers.Split("\n")                [custom mode]
  │
  ├── ICotdApi::GetCurrentCOTDChallengeId()         → state_currentChallengeid
  ├── ICotdApi::GetCurrentStandingForPlayers()      → Result[]
  │
  ├── VMMapper::ToSingleUserResultVMs()             → resolves names via UserManager
  └── COTDClubLiveUI::renderUI(vm, progress)        → ImGui render
```

---

## Interface: ICotdApi

```angelscript
interface ICotdApi {
    int GetCurrentCOTDChallengeId();
    Result@ GetDiv1CutoffTime(const int &in challengeid, const string &in mapid);
    array<Result@> GetCurrentStandingForPlayers(
        const array<string> &in players,
        const int &in challengeid,
        const string &in mapid
    );
}
```

Two implementations selected by `settings_cotdApi` (`CotdApi` enum):

- `NadeoCotdApi` — **default**; uses `NadeoServices::BaseURLMeet()` + `"NadeoLiveServices"` audience
- `MapMonitorCotdApi` — **backup**; uses `https://map-monitor.xk.io` via `Net::HttpRequest`, no auth

**Source policy**: Implement new features for Nadeo first. Add MapMonitor support best-effort. Do not block on MapMonitor parity.

---

## Key API Patterns

| Use case                        | API                                                                   |
| ------------------------------- | --------------------------------------------------------------------- |
| Authenticated Nadeo REST        | `NadeoServices::Get("NadeoLiveServices", url)`                        |
| Nadeo COTD challenge/standings  | `NadeoServices::BaseURLMeet() + "/api/cup-of-the-day/current"`        |
| Nadeo club/member data          | `NadeoServices::BaseURLLive() + "/api/token/club/<id>/..."`           |
| MapMonitor proxy                | `Net::HttpRequest` — `https://map-monitor.xk.io/cached/api/...`       |
| Game API (friends, names, tags) | `GetApp().UserManagerScript`, `app.ManiaPlanetScriptAPI.UserMgr.*`    |
| Auth guard                      | `NadeoServices::IsAuthenticated("NadeoLiveServices")` before any call |

---

## Settings Pattern

Declared in `settings/settings.as` with `[Setting]` attributes — Openplanet auto-generates the settings UI:

```angelscript
[Setting category="Club" name="Club id of the club" description="..."]
int settings_clubId = 0;
```

**Never add manual settings UI** — use `[Setting]` only.  
Runtime state is mirrored in `UIState.as`. `checkSettingsChanged()` compares `state_*` vs `settings_*` to trigger reloads.

---

## UIState Pattern

`UIState.as` holds runtime state separate from settings:

- `state_currentChallengeid`, `state_currentClubId`, `state_currentClubName`
- `state_showClub`, `state_showFriends`, `state_showCustom`, `state_showDivOneCutoff`
- `state_forceRefreshPlayers` — force a reload next loop
- `checkSettingsChanged()` — returns true when any setting diverges from its state mirror

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

---

## Club Picker

- `ClubInfo` class (global scope in `NadeoLiveServicesAPI.as`): `id` (int), `name` (string), `tag` (string)
- `NadeoLiveServicesAPI::GetAllClubs()` — fetches `GET /api/token/club/mine?offset=0&length=100`, returns `array<ClubInfo@>`
- Club picker state and UI live in `settings/SettingsClubPicker.as` — `g_myClubs`, `LoadMyClubs()` coroutine, `RenderSettingsClubPicker()` tab function
- Manual ID entry available via `UI::InputInt` inside the same tab
- Tag color codes stripped with `Text::StripFormatCodes()` for combo display

---

## Pending TODOs in Codebase

_(none outstanding)_
