# Installation

The repository's `SimOpenTrackDay/` folder **is** the app. Installing means copying that folder into `<Assetto Corsa>\apps\lua\`, so you end up with `<Assetto Corsa>\apps\lua\SimOpenTrackDay\SimOpenTrackDay.lua`. Everything outside that folder (`docs/`, `sdk/`, `experimental/`, repo files) is for development and is never copied.

**Never copy the modules directly into the game root.** Same-named files there can be loaded before the app's own modules and leave the tabs blank. See the [incident record](../archive/MODULE_LOADING_HARDENING.md).

## Requirements

- Assetto Corsa (Steam, Epic or GOG) with Custom Shaders Patch and Lua Apps enabled; the game folder already contains `apps\lua\`.
- The app folder from a release zip or from a clone. A clone must include the compatibility submodule: `git clone --recurse-submodules ...` or `git submodule update --init`. Without it, `SimOpenTrackDay\lib\AssettoCorsaCSPLuaCompatibilityManager\` is empty and the app fails to load.

## Install or update

1. Close the game and the launcher.
2. If an older version is installed, back up `<Assetto Corsa>\apps\lua\SimOpenTrackDay\` to a folder **outside** the game (see [TESTING §3.1](TESTING.md)).
3. Delete the old `<Assetto Corsa>\apps\lua\SimOpenTrackDay\` folder (so removed files do not linger), then copy the repository's `SimOpenTrackDay\` folder into `<Assetto Corsa>\apps\lua\`.
4. Start the game, enable SimOpenTrackDay in CSP Lua Apps if needed, and open an offline session with AI cars.

Example (Steam default path, PowerShell, game closed):

```powershell
$dest = "C:\Program Files (x86)\Steam\steamapps\common\assettocorsa\apps\lua"
Copy-Item -Recurse -Force .\SimOpenTrackDay $dest
```

App settings live in CSP's Lua storage, not in the app folder, so replacing the folder keeps them. Do not delete settings to update or to troubleshoot the UI.

> If you edited files inside the installed folder for local testing (for example observability flags in `Logger.lua` or `Constants.lua`), those edits are overwritten by the copy. Back them up first.

## Rollback

Close the game, delete `<Assetto Corsa>\apps\lua\SimOpenTrackDay\`, and copy your backup back in its place. Settings are preserved.

## If something fails

- **App missing from the Lua Apps list:** the folder is in the wrong place or nested twice (`apps\lua\SimOpenTrackDay\SimOpenTrackDay\...`). `manifest.ini` and `SimOpenTrackDay.lua` must sit directly in `apps\lua\SimOpenTrackDay\`.
- **Load error mentioning `CSPCompatibilityManager`:** the submodule folder is empty; initialize the submodule and copy again.
- **Blank tabs / `drawContent` nil:** follow [TESTING §6](TESTING.md#6-operational-troubleshooting). Reinstalling the app folder does not remove stray copies of project modules in the game root.
- Errors are logged in `%USERPROFILE%\Documents\Assetto Corsa\logs\custom_shaders_patch.log`.

Copying files does not validate loading, rendering or behavior in CSP; use [IN_GAME_VALIDATION.md](IN_GAME_VALIDATION.md).
