# Installation

The installer copies the runtime files listed in `tools/payload.manifest` to `<Assetto Corsa>\apps\lua\SimOpenTrackDay\`.

**Never copy the modules directly into the game root.** Same-named files there can be loaded before the current modules and leave the tabs blank. See the [incident and prevention plan](../archive/MODULE_LOADING_HARDENING.md).

The current installer **deletes the contents of the destination folder before copying**. It has no automatic backup or rollback. Before you continue:
- close the game and the launcher;
- back up the existing installation;
- make sure your settings are preserved.

## Requirements

- Windows with PowerShell 5.1 (the Windows 10/11 default).
- An Assetto Corsa installation (Steam, Epic or GOG) that already contains `apps\lua\` — any version that runs with CSP.

## Install

1. In the checkout, open `tools\install.bat`. A terminal window opens.
2. When it asks for the installation path, enter the **Assetto Corsa root**. Do not add `apps\lua`. Examples:
   - Steam: `D:\Steam\steamapps\common\assettocorsa`
   - Other: `C:\Games\AssettoCorsa`
3. Check the destination it shows: `<root>\apps\lua\SimOpenTrackDay\`. The script appends `apps\lua` for you.
4. Type `YES` and press Enter to confirm. Case does not matter, and any other answer cancels.
5. Read the result. The `.bat` waits for a key press at the end. Confirm the copy finished without errors before you start the game.

The parameter takes the game root, but files are copied only into the app folder. To install manually, use the same destination and the payload listed in the manifest. Never extract the whole repository into the AC root.

## Update

1. Make a fresh backup.
2. Close the game and the launcher.
3. Run `tools\install.bat` again.

The installer replaces the contents of the app folder, so any extra files you put there are removed too. You do not need to delete the installation first. Settings stored outside the app folder must not be deleted to update or to troubleshoot the UI.

## If something fails

The window shows a short message. The PowerShell engine logs the destination, the copy operations and the error to:

```
%LOCALAPPDATA%\SimOpenTrackDay\InstallerLogs\installer-yyyyMMdd-HHmmss.txt
```

To open it, press Win+R, enter `%LOCALAPPDATA%\SimOpenTrackDay\InstallerLogs`, and open the newest `.txt` file in a text editor.

Common errors:

- **`Folder not found` / `Assetto Corsa root not found`:** check the installation path.
- **`Missing apps\lua under` / `Expected apps\lua folder under`:** enter the game root that contains `apps\lua`, not the `apps\lua` folder itself.
- **`Aborted`:** the confirmation was not `YES`, so nothing was installed in that run.
- **Access denied:** close the game and launcher and check permissions. The message alone does not identify the cause.
- **Blank tabs / `drawContent` nil:** follow the [troubleshooting](TESTING.md#6-operational-troubleshooting) steps. Reinstalling only the app folder does not remove conflicting module copies in the game root, and the installer does not detect that situation yet.

## What the installer copies

It copies everything listed in `tools/payload.manifest`:
- the root Lua modules;
- `manifest.ini` and `LICENSE`;
- the runtime paths in the declared subfolders.

The list is the source of truth. Do not copy development files because their names look similar. To add a runtime file, add its relative path to the manifest and review the payload.

## For developers

`installer.ps1` is the engine and can be called directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\installer.ps1" -AssettoCorsaRoot "C:\Games\AssettoCorsa"
```

Called directly, the engine **does not ask for the `YES` confirmation**, which belongs to the `.bat`. Check the destination and make a backup before you run it. You always pass the installation root; the script picks the destination inside `apps\lua`.

Local checks are `tools/test_*.lua` and `tools/check_lua_syntax.ps1`; their limits are described in [Testing](TESTING.md). The installer does not validate loading, rendering or behavior in CSP.

To roll back an update, close the game and restore the backup of the app folder manually, preserving your settings.
