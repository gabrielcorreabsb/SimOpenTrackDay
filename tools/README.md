# Development tools

Local helpers for development. Nothing here ships with the app: the app is the `SimOpenTrackDay/` folder only.

## `logsummary.py`: summarize and compare CSP logs

Reads `custom_shaders_patch.log` (read-only) and prints normalized metrics for the app's log lines. Python 3, standard library only. Its output is in Portuguese.

```
python tools/logsummary.py --save NAME     # copy the current game log to "sot-saved" next to it
python tools/logsummary.py                 # summarize the current log
python tools/logsummary.py --cars 20       # also normalize per 10 car-minutes
python tools/logsummary.py A.log B.log     # compare two sessions
python tools/logsummary.py --skip 20 --json
```

**CSP overwrites the log on every game launch.** Run `--save` before starting the game again, or the session is lost.

Metrics: contacts (with the player, AI-AI, with the track, heavy), app collisions, off-tracks (real: 3+ wheels, or track limits: 1-2 wheels), spins, stopped cars, wrong-way, yellow zones (count, duration, open at the end), lateral avoidance (count, engage distance, late engagements, requested vs actual offset), `[LINE]` samples (distance to the racing line, lateral rate against the 1.25 m/s limit), hot spots, app errors, logger truncation.

Comparison rules:
- Change **one** thing between sessions and use the same track, car and grid size.
- The log does not record the app settings: note what changed in each test.
- Use sessions of similar length. The tool warns when the length, the CSP build, the app version or the track differ.

Not measured yet: time held up in a queue and laps per car. The current log has no data for them.

This is a measurement aid, not an automated test suite: behavior is still validated in game ([IN_GAME_VALIDATION.md](../docs/guides/IN_GAME_VALIDATION.md)).
