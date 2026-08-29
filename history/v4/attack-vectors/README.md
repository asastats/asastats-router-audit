# Attack Vectors — Smart Router v4

This directory catalogs every attack vector analyzed during the v4 audit. The vectors are organized by surface area:

| Subdirectory | Surface | Vectors |
|--------------|---------|--------:|
| [`general/`](general/README.md) | Group, MBR, reentrancy, gas, deployment | ~50 |
| [`route/`](route/README.md) | Path validation, multi-hop, slippage, conservation | ~25 |
| [`provider/`](provider/README.md) | Per-provider (Tinyman v2, Pact, STAMM, AlgoFi) | ~60 |
| [`pact/`](pact/README.md) | Pact-specific (constant-product, stableswap, **MWPT**) | ~40 |

**Total: ~175 vectors.** (The "134" count in v3 was per-vector, not per-attack-surface; v4 adds 27 MWPT vectors plus the I2 widening-policy observation.)

## Vector numbering

Each vector has a stable identifier of the form `SUBCATEGORY-NN-TITLE`:

- `GENERAL-NN` — group/transaction/MBR/reentrancy/gas/deployment
- `ROUTE-NN` — route correctness, multi-hop, slippage
- `TINYMAN-NN` — Tinyman v2 specific
- `PACT-NN` — Pact constant-product / stableswap specific
- `MWPT-NN` — Pact MWPT specific
- `STAMM-NN` — STAMM specific
- `ALGOFI-NN` — AlgoFi specific
- `CROSS-NN` — cross-provider interactions

## Verdict vocabulary

Each vector resolves to one of the following five verdicts:

- **Defended** — code actively prevents the attack.
- **Not applicable** — attack impossible on Algorand or in this design.
- **By design** — intentional behaviour, not a vulnerability.
- **Admin-controlled** — attack succeeds only if admin acts in bad faith.
- **Accepted** — documented residual risk.

The verdict for each vector is recorded in its file. Cross-references to `findings/` are provided where a vector produced a finding.

## Differences from v3

The v3 audit enumerated 134 vectors in 9 categories. v4:

1. **Inherits all v3 vectors** with verdicts re-verified for the new MWPT code path.
2. **Adds 27 new MWPT vectors** (`MWPT-01` through `MWPT-27`) in `pact/mwpt.md`.
3. **Restructures** the vectors into subdirectories by attack surface rather than by category.
4. **Cross-references** v3 finding IDs (`M1 (v3)`, etc.) where vectors map to v3 findings.

The v3 attack-vectors are retained in `../router-audit-v3/attack-vectors/` for historical reference. This directory supersedes them.

## How to read

For a specific attack vector:

1. Find the file by subcategory (`ls general/`, `ls provider/`, etc.).
2. Each file is one vector (or a small group of related vectors).
3. Each vector file includes:
   - **ID** (e.g., `GENERAL-07-rekey-attack`)
   - **Verdict** (one of the five above)
   - **Threat description** (what could go wrong)
   - **Code reference** (which contract method or assert defends against it)
   - **Test reference** (which test exercises the defence)
   - **Cross-reference** (link to v3 finding if any, link to v4 finding if any)

## Reading order

For an auditor first encountering the contract:

1. [`general/group-transactions.md`](general/group-transactions.md) — group-level attacks.
2. [`route/path-validation.md`](route/path-validation.md) — path sanitisation.
3. [`provider/`](provider/README.md) — per-provider surfaces.
4. [`pact/mwpt.md`](pact/mwpt.md) — MWPT-specific (the v4 addition).
5. [`general/resource-limits.md`](general/resource-limits.md) — MBR / opcode / box exhaustion.
6. [`route/conservation.md`](route/conservation.md) — value conservation.

For a focused MWPT review:

1. [`pact/mwpt.md`](pact/mwpt.md) — the 27 MWPT vectors.
2. [`provider/pact.md`](provider/pact.md) — the inherited Pact vectors (MWPT is a sub-type).
3. [`findings/M1-mwpt-weight-asymmetry-quoting.md`](../findings/M1-mwpt-weight-asymmetry-quoting.md) — the headline new finding.
