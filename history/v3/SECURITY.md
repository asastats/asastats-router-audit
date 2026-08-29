# Smart Router Security Policy & Threat Model (v3)

## 1. Security Architecture & Threat Model

The ASA Stats Smart Router is designed under a strict multi-party threat model:

```
+-------------------------------------------------------------------------------+
|                             THREAT MODEL MATRIX                               |
+----------------------+--------------------+-----------------------------------+
| Actor / Component    | Trust Level        | Threat Boundary / Defenses        |
+----------------------+--------------------+-----------------------------------+
| End User / Caller    | Untrusted          | Cannot rekey, steal float, or    |
|                      |                    | drain other users' swaps          |
+----------------------+--------------------+-----------------------------------+
| Frontend / Widget    | Untrusted          | Cannot set zero floor (floor is   |
|                      |                    | backend-signed by quote signer)   |
+----------------------+--------------------+-----------------------------------+
| External AMM Pools   | Untrusted          | Authenticated via creator pins /  |
|                      |                    | logic sig derivation; deltas only |
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

---

## 2. Key Management & Operational Runbook

### Admin Key Operations
- Hold offline in hardware / multisig custody.
- Actions: `set_admin`, `set_escrow`, `set_fee`, `set_voucher_signer`, `set_quote_signer`, `set_conversion_pool`, `delete_application`, `close_holding`.

### Quote Signer Key Operations
- Resides on quote generation server.
- Must co-sign the last transaction of every routed swap group with a note binding application ID, caller, output asset, and per-position input amounts.
- If compromised: Admin immediately rotates the key using `set_quote_signer(new_key)`.

### Voucher Signer Key Operations
- Resides on web backend.
- Signs 80-byte fee discount vouchers.
- If compromised: Admin immediately revokes by setting `set_voucher_signer(NO_VOUCHER_SIGNER)`.

---

## 3. Incident Response & Emergency Procedures

1. **Compromised Quote Signer:** Call `set_quote_signer(new_signer)` to rotate immediately.
2. **Compromised Voucher Signer:** Call `set_voucher_signer(NO_VOUCHER_SIGNER)` to disable all discounts.
3. **Malicious / Compromised Pool:** Call `set_conversion_pool(safe_pool)` if treasury conversion is affected; off-chain quote engine automatically prunes malicious pools from search graph.
4. **Contract Retirement:** Sweep all fees via `convert_and_distribute`, close all holdings via `close_holding`, and call `delete_application`.

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

### Monitored On-Chain Anomalies (`router/monitoring.py`):
- **Immediate Admin Invocations:** Calls to `set_admin`, `set_escrow`, `set_quote_signer`, or `set_conversion_pool`.
- **Float Drain & Unmatched Accruals:** Unpredicted decreases in router ALGO float or balance discrepancies.
- **Unauthorized Treasury Decreases:** Accrued fee reductions outside of legitimate `convert_and_distribute` calls.
- **Provider Outages & Streaks:** Tracking repeated provider execution failures (3 consecutive windows).
- **Residual Holding Leaks:** Unclosed asset holdings surviving routed atomic groups.
