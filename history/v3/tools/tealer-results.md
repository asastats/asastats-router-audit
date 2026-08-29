# Tealer Static Analysis Report (v3)

## 1. Summary of Execution

- **Tool:** Tealer v0.1.2 (`crytic/tealer`)
- **Target:** `Router.approval.teal` (4,641 lines TEAL v11, compiled via Puya 5.9.0)
- **Execution Script:** `router/scripts/tealer.sh` & `router/scripts/tealer_run.py`

---

## 2. Detector Results & Triage

| Detector | Impact | Raw Results | Auditor Triage & Verdict |
|---|---|---|---|
| `unprotected-updatable` | HIGH | 9 paths | **False Positive:** Router contains no `UpdateApplication` branch. Bytecode is permanently immutable. |
| `unprotected-deletable` | HIGH | 9 paths | **Intentional Feature:** `delete_application` is protected by `Txn.sender == self.admin`, `accrued == 0`, and `total_assets == 0`. |
| `can-close-account` | HIGH | 0 results | **Clean:** No unvalidated account close operations in approval program. |
| `can-close-asset` | HIGH | 0 results | **Clean:** No unvalidated asset close operations in approval program. |
| `constant-gtxn` | OPTIMIZATION | 0 results | **Clean:** No redundant constant group accesses. |
| `self-access` | OPTIMIZATION | 0 results | **Clean:** No inefficient self-access patterns. |
| `sender-access` | OPTIMIZATION | 0 results | **Clean:** No redundant sender access opcodes. |
| `group-size-check` | HIGH | Covered (0 absolute) | **Clean / Verified:** All 52 group accesses use dynamic relative indexing with verified range bounds. |
| `is-updatable` | INFO | Covered (0 updates) | **Clean:** Program contains 0 update paths. |
| `is-deletable` | INFO | Covered (Admin gated) | **By Design:** Deletion is strictly gated to the admin. |

---

## 3. Clear State Program Analysis

- `Router.clear.teal`: 3 instructions (`#pragma version 11; pushint 1; return`).
- All clear program detectors (`clear-is-updatable`, `clear-missing-fee-check`, `clear-rekey-to`, `clear-group-size-check`) confirm standard approval behavior.
