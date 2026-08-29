# M5 — STAMM `opups` is unbounded

**Severity:** Low availability
**Status:** Patched in the worktree

The caller supplies `Leg.opups` for a STAMM leg and the router forwards it to
the pinned budget application. There is no explicit maximum. Large values can
cause dynamic budget failure, consume group capacity or create caller-funded
no-op overhead.

The effect is atomic self-DoS rather than a router-float drain because inner
fees are zero. The worktree now enforces `MAX_STAMM_OPUPS = 8` in the contract
and builder, fuzzes the boundary with Hypothesis, and verifies the accepted and
rejected values against LocalNet. The strict mainnet measurement suite also
passes with a routed floor of 7.

Any future increase requires a new provider measurement and deployment review.
