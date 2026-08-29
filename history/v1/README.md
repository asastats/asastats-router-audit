# Smart Router Security Audit

A comprehensive audit plan and findings repository for the ASA Stats smart router application (`contracts/router_app.py`) and its off-chain quoting/execution stack.

**Audit status:** Plan + initial findings + source-level mitigations applied.  
**Verdict (preliminary):** No critical vulnerability that allows theft of a caller's trade under the current restricted deployment, **with one exception**: the permissionless `convert_and_distribute` path can drain accrued platform fees to an attacker-controlled pool if the router is ever deployed unrestricted. That finding has been patched in `router/contracts/router_app.py`.

## Where to find what

| You want to... | Read |
|----------------|------|
| Plain-English safety overview | [IS-IT-SAFE.md](IS-IT-SAFE.md) |
| Full technical report and recommendations | [REPORT.md](REPORT.md) |
| A specific finding | [findings/](findings/) |
| Attack-vector matrix | [attack-vectors/](attack-vectors/) |
| Scope, methodology, source identification | [methodology/](methodology/) |
| Contract deep-dive and per-method notes | [contracts/router_app.md](contracts/router_app.md) |
| Proposed audit timeline and tooling | [methodology/audit-plan.md](methodology/audit-plan.md) |

## Findings at a glance

| Severity | Count | Mitigated in source |
|----------|-------|---------------------|
| Critical | 1 | Yes (C1) |
| High | 1 | Proposed |
| Medium | 4 | 1 implemented, 3 proposed |
| Low | 5 | Partially |
| Informational | 6 | Documented |

The most important take-aways are:

1. **`convert_and_distribute` must not be permissionless with a caller-supplied pool.** It is now admin-only.
2. **The residual risk from T5 (a compromised widget passing `minimum_received = 0`) is real.** The strongest fix is a backend-signed floor, mirroring the voucher design.
3. **Route paths are not sanitised on-chain.** Cycles and duplicate assets can be submitted; we added on-chain checks.
4. **There is no deadline / quote-expiry parameter.** Stale quotes can execute as long as they meet the floor.

## What was audited

- `router/contracts/router_app.py` — the on-chain router application (Stage 4)
- `router/router/{contract,legs,build,quote,voucher}.py` — the off-chain group builder
- `router/SECURITY.md` — the threat model
- `router/tests/test_router_contract.py` — unit-level guard tests
- `router/tests/test_contract_localnet.py` — LocalNet integration tests
- `router/tests/test_contract_testnet.py` — testnet smoke tests

Out of scope by construction: Stages 0–3 (off-chain quote and group assembly), the liquidity engine, the frontend widget, and the economic modelling of the STAMM protocol itself.

## License

The audit material is released under the same license as the rest of the project repository.
