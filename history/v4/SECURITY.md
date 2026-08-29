# Smart Router Security Policy & Threat Model (v4)

## 1. Security Architecture & Threat Model

The ASA Stats Smart Router is designed under a strict multi-party threat model. The MWPT integration introduced in v4 does not change the trust model — MWPT pools are authenticated the same way legacy Pact pools are.

```
+-------------------------------------------------------------------------------+
|                          THREAT MODEL MATRIX (v4)                             |
+----------------------+--------------------+-----------------------------------+
| Actor / Component    | Trust Level        | Threat Boundary / Defenses        |
+----------------------+--------------------+-----------------------------------+
| End User / Caller    | Untrusted          | Cannot rekey, steal float, or    |
|                      |                    | drain other users' swaps          |
+----------------------+--------------------+-----------------------------------+
| Frontend / Widget    | Untrusted          | Cannot set zero floor (floor is   |
|                      |                    | backend-signed by quote signer)   |
+----------------------+--------------------+-----------------------------------+
| External AMM Pools   | Untrusted          | Authenticated via:                |
|   Tinyman v2         |                    |   - LogicSig hash derivation     |
|   Pact (constant)    |                    |   - Creator pin (PACT_POOL_       |
|   Pact (stableswap)  |                    |     CREATORS, multi-entry)       |
|   Pact MWPT (new)    |                    |   - Same creator pin, new         |
|   STAMM              |                    |     selector branch in _pact_leg  |
|   AlgoFi             |                    |   - Creator pin (STAMM_POOL_      |
|                      |                    |     CREATORS)                    |
|                      |                    |   - Whitelist (ALGOFI_POOLS)      |
+----------------------+--------------------+-----------------------------------+
| Quote Signer Key     | Semi-Trusted       | Signs floor only; cannot move     |
|                      |                    | funds or alter governance         |
+----------------------+--------------------+-----------------------------------+
| Voucher Signer Key   | Semi-Trusted       | Authorizes fee discount only;     |
|                      |                    | revocable by admin                |
+----------------------+--------------------+-----------------------------------+
| Administrator Key    | Trusted Operator   | Bounded fee (<=1%); cannot drain  |
|                      |                    | user trades; treasury target set  |
+----------------------+--------------------+-----------------------------------+
```

### 1.1 Pact MWPT additions

The MWPT integration introduces one new creator address to the trusted pool list:

```
H2XDAFUDTEPTN24HNUAZI6RCKQ2KDIIO45U767FEHGSGSEGCWWOK4QEIXM
```

This is appended to `PACT_POOL_CREATORS` (already multi-entry since v3's M3 fix). The selector branch in `_pact_leg` decides between `PACT_SWAP` and `PACT_MWPT_SWAP` based on which creator address deployed the pool — the same authentication check that has defended legacy Pact pools since v3 now defends MWPT pools.

### 1.2 Residual trust boundaries (v4)

These trust boundaries were inherited from v3 and re-confirmed in v4:

- **Quote-signer key:** the floor mechanism's single trust point. Compromising it permits a one-shot per-trade MEV extraction.
- **Voucher-signer key:** can authorise unlimited fee discounts. Compromise is bounded by `MAX_DISCOUNT` (currently 100%) but admin can revoke by setting `voucher_signer = NO_VOUCHER_SIGNER`.
- **Admin key:** can redirect where converted fees are paid (within `MAX_FEE_BPS = 100` ceiling) and which conversion pool is used (must be pre-approved via `set_conversion_pool`). Cannot drain user trades.
- **AlgoFi pool list (`ALGOFI_POOLS`):** admin-curated list of 23 pools. List widening policy is **not currently documented** — see [findings/I2-algofi-list-widening-policy.md](findings/I2-algofi-list-widening-policy.md).
- **MWPT factory creator address:** hardcoded in `_pact_leg` selector branch. **If the upstream Pact team migrates the MWPT factory to a new creator address, the router's selector branch will fall back to the legacy `PACT_SWAP`, which the new pool will reject.** This is a *residual risk* not flagged as a vulnerability because the migration would require an explicit, coordinated router redeploy. See DISCLAIMER.md §5.4.

---

## 2. Key Management & Operational Runbook

### 2.1 Admin Key Operations
- Hold offline in hardware / multisig custody.
- Actions: `set_admin`, `set_escrow`, `set_fee`, `set_voucher_signer`, `set_quote_signer`, `set_conversion_pool`, `delete_application`, `close_holding`.
- v4: the `RESTRICT_TO_ADMIN` template var remains in source; mainnet runs unrestricted.

### 2.2 Quote Signer Key Operations
- Resides on quote generation server.
- Must co-sign the last transaction of every routed swap group with a note binding application ID, caller, output asset, and per-position input amounts.
- If compromised: Admin immediately rotates the key using `set_quote_signer(new_key)`.

### 2.3 Voucher Signer Key Operations
- Resides on web backend.
- Signs 80-byte fee discount vouchers.
- If compromised: Admin immediately revokes by setting `set_voucher_signer(NO_VOUCHER_SIGNER)`.

### 2.4 AlgoFi Pool List Updates
- Admin updates `ALGOFI_POOLS` only when:
  1. AlgoFi publishes a new official pool contract, **and**
  2. The new pool is observed to hold meaningful liquidity on-chain, **and**
  3. A testnet deployment has successfully routed through it.
- The list is not editable from the contract — it is a deployment-time template variable.

---

## 3. Incident Response & Emergency Procedures

1. **Compromised Quote Signer:** Call `set_quote_signer(new_signer)` to rotate immediately. Existing in-flight quotes remain valid until their group expires.
2. **Compromised Voucher Signer:** Call `set_voucher_signer(NO_VOUCHER_SIGNER)` to disable all discounts.
3. **Malicious / Compromised Pool:** Call `set_conversion_pool(safe_pool)` if treasury conversion is affected. For MWPT pools, no on-chain action exists — the pool creator is hardcoded; if a malicious pool is deployed by the MWPT factory address, the router redeploy is required.
4. **Pact Factory Migration:** If Pact team migrates to a new creator, treat as a routine deployment: recompile with updated `PACT_POOL_CREATORS`, deploy to testnet, run differential testing against the new pool, then deploy to mainnet.
5. **Contract Retirement:** Sweep all fees via `convert_and_distribute`, close all holdings via `close_holding`, and call `delete_application`.

---

## 4. Operational Monitoring & CLI Management Suite

The engine includes a full management suite under `engine/core/management/commands/`:

| Management Command | Operational Purpose |
|---|---|
| `python manage.py poll_router_monitor` | Starts the polling daemon monitoring on-chain application state, float changes, fee accruals, and alert delivery |
| `python manage.py router_monitor_status` | Reports cursor round, network synchronization, and open alert health summary |
| `python manage.py router_alerts` | Lists open and historical router alerts with severity filtering (`--status open`, `--json`) |
| `python manage.py resolve_router_alert <id>` | Marks an investigated alert as resolved with audit timestamp |
| `python manage.py retry_router_alerts` | Retries failed webhook alert deliveries |

### Monitored On-Chain Anomalies (`router/router/monitoring.py`):
- **Immediate Admin Invocations:** Calls to `set_admin`, `set_escrow`, `set_quote_signer`, or `set_conversion_pool`.
- **Float Drain & Unmatched Accruals:** Unpredicted decreases in router ALGO float or balance discrepancies.
- **Unauthorized Treasury Decreases:** Accrued fee reductions outside of legitimate `convert_and_distribute` calls.
- **Provider Outages & Streaks:** Tracking repeated provider execution failures (3 consecutive windows).
- **Residual Holding Leaks:** Unclosed asset holdings surviving routed atomic groups.
- **MWPT Selector Drift (new in v4):** Track whether any `_pact_leg` inner call returns a pool whose creator is the MWPT factory but whose selector is the legacy `PACT_SWAP` — this would indicate a stale deployment.

---

## 5. MWPT-Specific Operational Concerns

### 5.1 Curve math divergence

Off-chain `router/curves.py:pact_mwpt_out` uses IEEE-754 doubles for the asymmetric-weight path. The on-chain BigInteger computation can return a value 1 microunit different. **Finding M1** recommends rewriting `pact_mwpt_out` in pure integer arithmetic; until then:

- Quote output for MWPT pools with `weight_in ≠ weight_out` may differ from on-chain output by ±1 microunit.
- The drift is *always in the pool's favour* (the user never gets less than the contract delivers).
- Mitigation: the floor mechanism still protects the user; the on-chain assert is `actual ≥ floor`, so an off-chain quote of `1,000,001` and an on-chain delivery of `1,000,000` still passes.

### 5.2 Vault reference trust

The MWPT vault app ID is discovered off-chain and embedded in the leg's `foreign_apps` array. **Finding L2** recommends an on-chain check; until then:

- A compromise of the off-chain quoter could substitute a malicious vault app ID.
- The vault is referenced only via `box_read` calls; the deposit goes to the pool's own address, not the vault's address.
- Mitigation: pool creator check still authenticates the pool itself; the vault reference is a separate trust point that requires off-chain compromise to exploit.

### 5.3 Zero-output silent branch

`pact_mwpt_out` returns `0` (not raise) when `effective_in ≤ 0` (i.e., when `amount_in * fee_bps ≥ amount_in * BASIS_POINTS`). **Finding L1** notes this is correct but should be documented. In practice:

- The on-chain pool also returns zero in this case (the swap produces no output).
- Quoters should treat a `0` return as "swap would yield nothing, skip this pool" rather than "error".
- Mitigation: docs already explain this; adding a typed return value would improve diagnostics.

---

## 6. v4-Specific Recommendations

1. **Apply the three improvements in [IMPROVEMENTS.md](IMPROVEMENTS.md)** before the next deployment.
2. **Run the differential test** between `pact_mwpt_out` (off-chain) and a representative MWPT pool on testnet to confirm the on-chain ↔ off-chain alignment to ±0 microunit (or accept ±1 and document).
3. **Add `tests/test_pact_mwpt_against_chain.py`** to lock in the on-chain MWPT behaviour as the source of truth for off-chain quoters.
4. **Document the AlgoFi pool list widening policy** in a follow-up PR; this is `I2`.
5. **Schedule human-expert review** — the only item the AI cannot advance.

---

## 7. Reference Documents

- [REPORT.md](REPORT.md) — full technical audit report
- [DISCLAIMER.md](DISCLAIMER.md) — verdict vocabulary and audit limitations
- [IS-IT-SAFE.md](IS-IT-SAFE.md) — plain-English FAQ
- [IMPROVEMENTS.md](IMPROVEMENTS.md) — concrete contract improvements
- [attack-vectors/pact/mwpt.md](attack-vectors/pact/mwpt.md) — 27 MWPT-specific attack vectors
- [findings/](findings/) — detailed write-ups of M1, L1, L2, I1, I2 and regressions
- [contracts/cross-contract-interactions.md](contracts/cross-contract-interactions.md) — call graph
- [contracts/state-keys.md](contracts/state-keys.md) — global-state key inventory
- [tools/tealer-results.md](tools/tealer-results.md) — static-analysis results
- [tools/scanner-results.md](tools/scanner-results.md) — Trail of Bits scanner results
