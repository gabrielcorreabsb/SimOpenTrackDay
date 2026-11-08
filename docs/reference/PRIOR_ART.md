# Prior art: open AC AI projects

These are other Assetto Corsa / CSP projects that inform the [roadmap](../ROADMAP.md). They were **read, not executed in CSP**. Stars and activity were checked on 2026-11-08 and will change.

**Licence policy**
- Only code under a compatible permissive licence (MIT) may be reused, and only with attribution and an approved ticket.
- Code under GPL/AGPL licences, restrictive licences or no licence is **ideas only**, re-implemented clean-room. Do not copy code, structure or text from those projects.

| Project | Licence | Allowed use | Ideas we take, adapted to a track day | Phase |
| --- | --- | --- | --- | --- |
| [Realistic Trackday](https://github.com/dreasgrech/AssettoCorsaRealisticTrackday) (Andreas Grech) | MIT | Upstream and original base of this app | Per-track lateral offsets (default / yield / overtake); a per-car state machine; a grace period at session start | Base |
| [Full Send AI](https://github.com/Eddlm/Full-Send-AI) (Eddlm) | GPL-3.0 | Ideas only | Per-sector learning on 50 m sections. Here it may adjust caution and yield timing only, never grip | F1/F2 |
| [RARE](https://github.com/ac-sim-improvement-mods/ac-rules-and-race-enhancements) | AGPL-3.0 | Ideas only | A build gate before the pit request (`>=2278`). Its fuel-drain fallback is rejected | F4 |
| [ApexFlow](https://github.com/Silxyst/ApexFlow) | MIT | Reuse with attribution | Strategy, tyre and fuel reading | F4/F5 |
| [ConditionReports](https://github.com/otherchriso/AC_ConditionReports) | see repo | Reference | Reading conditions (`rainWetness`) | F5 |
| [app-csp-defaults](https://github.com/ac-custom-shaders-patch/app-csp-defaults) | MIT | API usage reference | AISplineEditor, DynamicReturn | F1 |
| [acc-lua-sdk](https://github.com/ac-custom-shaders-patch/acc-lua-sdk) | MIT | Official SDK | API contracts. The installed SDK (`extension/internal/lua-sdk`) is authoritative for the target build | All |
| [csp-traffic-tool-extended](https://github.com/jakzo/csp-traffic-tool-extended) | No licence found | Do not reuse | Semi-dynamic rigid bodies for traffic collisions (concept only) | — |

## What we improve on

These projects are race-oriented or rewrite the AI's driving. SimOpenTrackDay differs in four ways:
- **Track-day semantics:** stints, warm-up and cool-down, mixed experience and classes. There are no positions to defend.
- **Arbitration:** every write goes through owners, priorities and leases (`CarOperations.lua`), so features do not fight each other or other mods.
- **Fail closed:** player and autopilot isolation, a pause/replay gate and generation-tagged identity.
- **Observability first:** the bounded `[RTD-DIAG-*]` records and an opt-in inspector come before new actuation.
