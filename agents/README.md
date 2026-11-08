# work/agents: the City AI Mayor structure (player's design, 2026-11-06)

All agents are advisory. None touches the game. The main session executes within the lanes, under the player's rules and a checkpoint.

```
Mayor Agent (mayor-agent.md)
│
├── Chief of Staff Agent (chief-of-staff-agent.md)
│
├── Economy Agent (economy-agent.md)
├── Population Agent (population-agent.md)
├── Infrastructure & Zoning Agent (infrastructure-agent.md)
├── Transportation & Transit Agent (transport-agent.md)
├── Public Transportation Director (public-transportation-director.md; the player's text verbatim, reads current_state.json + economy/transport/mayor reports)
├── Logistics Agent (logistics-agent.md)
├── Utilities Agent (utilities-agent.md)
├── Public Services Agent (public-services-agent.md)
├── Emergency Services Agent (emergency-services-agent.md)
└── Environment Agent (environment-agent.md)
```

| Agent | Writes |
|---|---|
| each department | `reports/<name>-report.md` (economy, population, infrastructure, transport, public-transportation, logistics, utilities, public-services, emergency-services, environment) |
| Chief of Staff | `reports/chief-of-staff-brief.md` (Daily Brief, Weekly Brief, Executive Action List, scored projects) |
| Mayor | `reports/mayor-report.md` (Daily Executive Brief, Strategic Review, Decisions, OVERALL STATUS) |

Each role file is the player's text (Mission, Responsibilities, Inputs, Outputs, Priority Order) followed by a "Kit notes" section that names the exact `city_summary.json` keys that department reads, what the bridge cannot measure, and the player's standing rules.

Data: every department reads only its listed slice of `state/city_summary.json` (written by `Update-State` from the checksum-validated `state/current_state.json`); `state/history.jsonl` holds one row per state write for trends. The Chief of Staff reads the whole summary and all nine reports; the Mayor reads the Chief of Staff brief and the whole summary. Agents ignore missing or null values and never invent metrics not in the summary.

Chain (player decision 2026-11-06): departments recommend → Chief of Staff compiles, scores, Approve/Delay/Reject → Mayor decides → **Claude executes every APPROVED item**. No owner labels and no protected areas: every road, interchange and building in the city is in scope for recommendations and execution; bridge controls being on is the approval. Checkpoint before every change, log in `decisions/`.

Cadence (usage budget, player decision 2026-11-06, to stay inside the 5-hour limit):
- **Full council at most every 2 hours**: `Update-State` (add `-WithZoning` only when zoning changed; ~3.5 min) → 10 departments in parallel on Sonnet (skip any whose summary keys have not moved since its last report, unless two councils have passed) → Chief of Staff on Sonnet → Mayor → execute APPROVED items under a checkpoint → `Go-Game 2` → log in `decisions/`.
- **Light tick every 20-30 min, no agents**: `Update-State`, a 10-line delta from `city_summary.json`, execute the next approved items from the Mayor's standing Decisions, `Go-Game 2`, one log line.
- Reports ≤ 60 lines; hand-back replies ≤ 3 lines.

Archive: `archive-2026-11-06-transport-agent-v1-roads.md`, `archive-2026-11-06-mayor-agent-v1.md`; previous state writer `tools/archive-2026-11-06-state-v2.ps1`.

Scratch: cursor/window save files from `gamewin.ps1`, dry-run outputs, screenshots. One subfolder per session is fine; safe to delete after the session.

