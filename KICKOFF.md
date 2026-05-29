# Autonomous Build — Kickoff Instructions

The Agent tool requires the Claude session's cwd to be a git repo. This directory now has an empty `.git`, but you must **start Claude from inside this folder** so the cwd matches.

## One-time setup

```bash
cd /Users/mernxl/Documents/Work/PaulAyire/excalibur/order-management
```

Then start Claude Code with permissive auto-accept so the build runs uninterrupted:

```bash
# Option A — recommended: bypass all permission prompts (only do this inside this tree)
claude --permission-mode bypassPermissions

# Option B — slightly safer: auto-accept edits, prompt only for shell + network
claude --permission-mode acceptEdits
```

> Note: `--permission-mode bypassPermissions` is sometimes aliased as `--dangerously-skip-permissions`. Either name works. Use it only inside this isolated repo — never at the home / parent dir level.

## Kickoff message (paste this into the new Claude session)

```
Read /Users/mernxl/Documents/Work/PaulAyire/excalibur/PROMPT.md in full — that is your contract. Execute Phases 1 through 4 (Junior → Senior Associate) sequentially. The directory tree and root files are already scaffolded; extend, don't recreate. No git commits — I'll commit at the end. When done, write HANDOFF.md per the format in your brief and stop. You can use Sonnet 4.6 — no need for a sub-agent, just work directly in this session.
```

That's it. Walk away. Come back to a finished codebase + `HANDOFF.md`.

## When you return

```bash
# 1. Read what was built
cat HANDOFF.md

# 2. Validate locally
cp .env.example .env
docker compose up -d
make seed
make test
make e2e          # optional — needs Playwright browsers installed

# 3. Commit (one commit, as planned)
git add -A
git commit -m "feat: scaffold tier-4 order management"
```

## If the agent stops mid-build

Just say `continue` — it will pick up where it left off, since the file system is its memory.
