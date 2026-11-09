# Defaults audit (2026-11-09)

This audit reviews the default values in `SimOpenTrackDay/StorageManager.lua` against the CSP SDK (build 4305) and the lateral-offset calibration recorded in the [CSP audit](CSP_CAPABILITY_AUDIT.md) on 2026-11-09. It is a review only: **no default has been changed yet.**

- Defaults apply only to a track and session mode that has no saved settings yet. Settings already saved per track keep their values.
- Calibration (one AI car, Interlagos): `setAISplineOffset` is measured from the **track middle** (0 = middle, ±1 = edges), on the same scale as `ac.worldCoordinateToTrack().x`. It is **not** measured from the AI racing line.

## Findings

| # | Setting (default) | What it actually does | Risk | Recommendation |
| --- | --- | --- | --- | --- |
| D1 | `defaultLateralOffset` (0), requested every frame in normal driving with owner `NORMAL_TRAFFIC` | Holds every AI on the **track middle** instead of the racing line. In the calibration, with a request of 0 the car stayed around x ≈ 0 while the computed AI line was at x ≈ −0.24 to −0.77 | High: no racing line, slower and unnatural, more bunching; probably present since upstream | Do not request any offset in normal driving (release the lateral control and let the native AI follow its line). Keep offsets only for the yield and overtake lanes. Validate lap times and the line in game |
| D2 | `yieldingLateralOffset` (0.8) / `overtakingLateralOffset` (−0.8) | Car centre at 80% of the half width from the middle. On a 12 m track: 4.8 m from the middle, about 0.25 m between the car's side and the edge | Medium: kerbs and grass when yielding/overtaking; worse on narrow tracks | Use ±0.6 by default, or compute from the track width: edge − half the car width − 0.5 m |
| D3 | `overrideAiAwareness` (true), passed to `setAISplineOffset` | Default in CSP is `false`. With `true`, the offset overrides the AI's own awareness of nearby cars | Medium: lane changes may ignore cars alongside (possible cause of side contacts) | Default to `false`; test yield and overtake with side checking |
| D4 | `defaultAIDifficultyLevel` (0.8) with `overrideOriginalAIDifficultyLevel_drivingNormally` (true) | Replaces the launcher AI level of **every** car with 80% | Medium: ignores the player's launcher choice; all cars at the same level | Default the override to `false` (keep the launcher level); keep 0.8 only as the value used when the override is on |
| D5 | `AIDifficultyLevel_OvertakingWithNoObstacleInFront` (2) / `...WithObstacleInFront` (1.5) | `setAILevel` accepts 0–2, so 2 means 200% of normal AI pace while overtaking | High: sudden pace spikes during passes, braking-point misses, contacts | Cap at about +10% over the car's own level (for example min(level × 1.1, 1.0)) |
| D6 | `defaultAIAggression` (0.5) with the override on | Replaces the launcher aggression of every car | Low/medium: same issue as D4 | Default the override to `false` |
| D7 | `AIAggression_OvertakingWithNoObstacleInFront` (1.0) | The SDK says the launcher's 100% shows up as 0.95; the code comment says the max is 0.95 | Low: out of the documented range | Use 0.95 |
| D8 | `defaultAICaution` (3), applied to every car in normal driving | The SDK default is **1** ("distance it keeps from the car in front") | Medium: about 3× the native following distance, so traffic behaves differently from native AI | Default to 1; keep higher values only in yellow zones and when yielding |
| D9 | `globalTopSpeedLimitKmh` (0) | 0 means no cap (`cap > 0` check) | None | Keep; label it "0 = off" in the UI |
| D10 | `humanErrorEnabled` (true) | The app injects AI mistakes by default | Low; product choice | Keep, but note that it is on by default; F3 personalities will scale it |

## Tickets

#9 (D1+D3), #10 (D5+D2), #11 (D4+D6+D7+D8).

- **#9 lane (branch `fix/defaults-d1-d3`):** normal driving targets the AI racing line, `(L - R) / (L + R)` from the spline sides, because CSP has no documented way to clear an offset and 0 is the track middle. `overrideAiAwareness` defaults to `false`. The A/B session in game is pending.

## Proposed order

1. **D1** (racing line) and **D3** (awareness): biggest realism and safety gain. Change behind an A/B test in game.
2. **D5** and **D2**: reduce contact risk during passes.
3. **D4, D6, D7, D8**: respect the launcher; align with the SDK.

Each change needs its own ticket (roadmap rules) and in-game evidence. D1 affects every AI car all the time, so it should be validated first in a short A/B session: lap times and the visible line with the current default vs no offset in normal driving.
