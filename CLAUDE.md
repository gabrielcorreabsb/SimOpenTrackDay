@AGENTS.md

## Claude Code notes

- `AGENTS.md` (imported above) is the shared rule set with OpenCode. Put project rules there, not here; this file only holds Claude Code specifics.
- Read [docs/ROADMAP.md](docs/ROADMAP.md) for current status before planning work. The detailed history in `docs/archive/` is Portuguese and read-only.
- Never edit `.slim/` (oh-my-opencode-slim lanes, worktrees, codemap settings), the OpenCode configuration, or the managed `oh-my-opencode-slim` block in `.gitignore`/`.ignore`.
- Do not commit into, clean, or remove a branch that has a live worktree under `.slim/worktrees/`. Check `git worktree list` first.
- The shell is Windows. The only local check is the LuaJIT compile one-liner in [docs/guides/TESTING.md](docs/guides/TESTING.md); behavior needs in-game validation by the user. Report only checks actually run.
- The live install is manual (copy `SimOpenTrackDay/` into `apps\lua\`). Never copy files into the game unless the user asks.
