# Backlog — track-day realism ideas

Distilled from the [original technical roadmap](archive/SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md) (Portuguese, sections 6–14). These are **ideas, not commitments**. Before a backlog item can become a milestone, it needs:

- a CSP capability check against the [audit](reference/CSP_CAPABILITY_AUDIT.md);
- an approved ticket, as described in [ROADMAP.md](ROADMAP.md).

The principles below apply to every item:
- Observe before you actuate.
- Fail closed when an API or data is missing.
- Never invent physics (no extra grip, fuel drain, teleport or fake damage).
- New features are off by default.

## Drivers and traffic (→ M3, M4)

- **Per-driver personality.** Skill, consistency, spatial awareness, caution, patience, line fluency and mechanical sympathy, rather than a single aggression slider.
  - Seeded per session.
  - Pace varies slowly.
  - Presets: Beginner, Intermediate, Experienced, Mixed Trackday.
  - The distribution between presets is configurable.
- **Traffic perception.** Free distance along the track, closing speed, a simple TTC, and lateral feasibility.
  - Filter out false neighbours: laps, pit lane, parallel sections, hairpins.
  - Hysteresis and a minimum time before moving or cancelling a lateral move.
  - Incoherent data means risk is `unknown`, never "safe".
- **Per-sector learning** (optional, inspired by Full Send AI). Adjust only caution and yield timing; never grip.

## Pit lifecycle (→ M5, M6)

- **Discovery first.** `physics.setAIPitStopRequest` exists from CSP build 2278 according to RARE. Check that it works in Track Day on each track.
  - Fail closed, falling back to "suggest pit only".
  - Never teleport to the pit.
- **Per-car pit state machine:** request pending → approaching → in pit lane → service → exit.
  - Keep intent, command sent, entry observed, service performed and exit observed as separate facts.
- **Reasons to stop:** low fuel, worn tyres, end of stint, real overheating, an external mechanical event, a damaging incident.
  - Cold tyres never force a pit stop.
- **Service and timing** only in a confirmed, stationary pit box; respect pit-lane speed and safe exit spacing.

## Session phases (→ M2)

- Two clocks: the global session (`SessionDetails`) and a per-driver phase.
- Phases: Pit/Inactive → **Sighting** (optional) → **Warm-up** → **Free running** → **Cool-down** → Return to pit.
  - Each phase has a timeout and a safe fallback.
- **Warm-up** uses tyre telemetry when it is available, otherwise laps or time, and is labelled "estimated". Never penalize grip twice.
- Stint length is configurable by experience; there is no universal "3 laps to warm up".

## Tyres, wear, damage and failures (→ M7)

- Keep three concepts separate:
  1. physical state observed from AC/CSP;
  2. a synthetic risk indicator, which never changes physics;
  3. failures with a physical effect, only through a validated car-script contract.
- **Mechanical Realism Framework (MRF, MIT) integration** works per car and per version, through an explicit provider contract. Never inject car scripts silently.
- Risk model: hazard rate → probability per `dt`. It must not depend on FPS, and it must not invent real-world failure rates.
- Escalation: observe → warn → recommend pit → pit intent → confirmed service.

## Weather and environment (→ M7)

- **Adapter (Lua App).** Read rain, wetness and temperature when the CSP API exposes them.
  - Map them to Dry / Damp / Wet / HeavyWet / Unknown, with hysteresis.
  - Adjust caution and TTC margins, never grip.
- **A weather generator** (a WeatherFX controller) is a separate project and must not run from this app.

## Incidents, recovery and flags (→ S-phase, M8)

- Observe incidents separately from blame.
  - Group nearby contacts into one incident.
  - Tell legitimate slow running (pit, queue) apart from an immobilized car.
  - Detect spins and wrong-way driving using heading against the track tangent.
- Safe recovery states: monitor → wait for gap → a single recovery attempt → verify motion.
  - No teleporting in front of traffic.
  - Never leave collisions permanently disabled.
- Flags: give zones an owner and a priority, with debounce.
  - Hazard lights respect manual override.
  - No sporting penalties in early versions.

## Track Day Logbook and engineer UI (→ M8)

- A local, lightweight debrief:
  - time on track vs in the pits;
  - stints;
  - fuel per stint;
  - tyre and damage evolution;
  - pit requests vs pit entries;
  - incidents by zone;
  - traffic delays;
  - driver consistency.
- Event schema with `observed` / `estimated` / `unknown` labels.
- Never write full JSON every frame; no cloud upload.
- A non-intrusive "Session" view showing phase, stint, fuel estimate, tyres, conditions, pit capability and safety notices.

## Coexistence with other mods (→ M4+)

- Each domain gets a mode: `Disabled`, `MonitorOnly` or `Control`. Domains: lateral traffic, pace personality, extra grip, pit request, weather, virtual mechanics, recovery, flags.
- Default to `MonitorOnly` or `Disabled` wherever Verve, Full Send AI, ApexFlow or RARE may write the same parameters.
- Never claim universal detection of other mods.

## Further future (not committed to v1.0)

- A standalone WeatherFX-compatible controller.
- Deep MRF car-script integration.
- Per-team pit service with real physics integration.
- Advisory safe-overtaking-zone detection.
- An offline virtual instructor.
- A local incident replay viewer.
- Marshalling and real procedures, only if a viable API exists.
- Official data exchange with other mods, only if both sides expose an interface.
