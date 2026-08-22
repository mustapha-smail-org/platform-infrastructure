# platform-infrastructure / docs

Reference docs for running and evolving the CityPulse single-host deployment.
For first-time **setup**, use the step-by-step [`../wiki/`](../wiki/Home.md);
these docs are the day-to-day / how-do-I references.

- [operations-cheatsheet.md](operations-cheatsheet.md) — everyday + debugging
  commands (logs, restart vs recreate, deploy, staging on/off, health checks,
  resource checks, reboot recovery) and the gotchas to remember.
- [adding-a-service.md](adding-a-service.md) — the **infrastructure** steps to
  add a new service to the stack (topology, env vars, deploy script, secrets,
  optional edge exposure).
- [local-development.md](local-development.md) — running the stack on your own
  machine, and where the local compose lives (this repo's `local/`).
- [remaining-work.md](remaining-work.md) — the optional/last items still open
  (real domain, staging auto-off, small tidies).

Related:
- [`../README.md`](../README.md) — repo overview + topology.
- [`../wiki/`](../wiki/Home.md) — full setup guide (provision → deploy → verify).
- [`../../docs/VPS/vps-deployment-design.md`](../../docs/VPS/vps-deployment-design.md)
  — the design rationale (the *why*).
