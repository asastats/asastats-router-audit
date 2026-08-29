# Tools — v4 Smart Router Audit

This directory contains the tool results for the v4 audit: static analysis output (Tealer) and the Trail of Bits Algorand vulnerability scanner results.

## Files

- [`tealer-results.md`](tealer-results.md) — Tealer static analysis sweep on the compiled TEAL.
- [`scanner-results.md`](scanner-results.md) — Trail of Bits 11-pattern vulnerability checklist evaluation.

## Other tools used (not archived here)

- **`puyapy 5.9.0`** — Algorand Python compiler. Used to compile the contract from `router/contracts/router_app.py` to TEAL.
- **`pytest`** — Test runner. Used for offline, LocalNet, mainnet-state, and testnet tests.
- **`Hypothesis`** — Property-based testing framework. Used for fuzz tests.
- **`algokit`** — LocalNet + AlgoKit utilities. Used for integration tests.
- **`py-algorand-sdk`** — Algorand Python SDK. Used for on-chain state queries.

## Reproducing the tool results

### Tealer sweep

```bash
cd <router>
bash run_tealer.sh --watch
```

The sweep runs 12 detectors and produces one `.log` and one `.err` file per detector at `router/build/tealer/`. Two detectors (`is-updatable`, `is-deletable`, `group-size-check`) may time out at the 8 GB ulimit on a 16 GB host; they produce `*.covered` supplementary files with a static-vacuousness proof.

### Vulnerability scanner

The scanner is the Trail of Bits Algorand vulnerability scanner skill at `<audit>/router-audit-v3/algorand-vulnerability-scanner/SKILL.md`. Apply its 11-pattern checklist manually against the compiled TEAL; the results are summarised in `scanner-results.md`.
