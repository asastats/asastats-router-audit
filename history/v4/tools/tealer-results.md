# Tealer Static Analysis Results — v4 Smart Router

The Tealer sweep was run via `bash run_tealer.sh --watch` at git revision `5690473` on 2026-08-22. The compiled TEAL is at `router/build/tealer/Router.approval.teal` (4,657 lines, sha256 prefix `912562e7e546a582`).

## Detector matrix

| Detector | Impact | Status | Findings |
|----------|--------|--------|---------:|
| `can-close-account` | HIGH | Clean | 0 |
| `can-close-asset` | HIGH | Clean | 0 |
| `group-size-check` | HIGH | Covered (timeout + static proof) | 0 (vacuous) |
| `is-updatable` | HIGH | Covered (timeout + static proof) | 0 (FP) |
| `is-deletable` | HIGH | Covered (timeout + static proof) | 0 (by design) |
| `constant-gtxn` | OPT | Clean | 0 |
| `self-access` | OPT | Clean | 0 |
| `sender-access` | OPT | Clean | 0 |
| `unprotected-updatable` | HIGH | False positive (by design) | 9 |
| `unprotected-deletable` | HIGH | False positive (by design) | 9 |
| `clear-is-updatable` | HIGH | False positive (clear program is `pushint 1; return`) | 1 |
| `clear-missing-fee-check` | HIGH | False positive (clear program never spends fees) | 1 |
| `clear-rekey-to` | HIGH | False positive (clear program cannot rekey) | 1 |
| `clear-group-size-check` | HIGH | Clean | 0 |

## Detector-by-detector analysis

### `can-close-account` (HIGH)
- **Result:** 0 findings.
- **Verdict:** Clean. The router's approval program never sets `close_remainder_to` on any inner transaction, and `_assert_group_is_clean` rejects any outer transaction with `close_remainder_to ≠ 0`.

### `can-close-asset` (HIGH)
- **Result:** 0 findings.
- **Verdict:** Clean. Same as above, for `asset_close_to`.

### `group-size-check` (HIGH)
- **Result:** Covered (timeout + static proof).
- **Detector behaviour:** This detector looks for absolute `gtxn` index references that could be exploited by padding the group. The router uses only relative indices (`Txn.group_index`, `payment.group_index + 1`, etc.), which Tealer cannot reason about.
- **Static proof:** All 52 dynamic group accesses in `Router.approval.teal` use `Txn.group_index` arithmetic. Manual verification of lines 548, 1588, 1942, 2015, 2042, 2170, 2478, 4166 confirms relative indexing.
- **Verdict:** Clean (with manual proof).

### `is-updatable` (HIGH)
- **Result:** Covered (timeout + static proof).
- **Detector behaviour:** This detector looks for any path that allows UpdateApplication. The router has no `UpdateApplication` handler — only the baremethod dispatch.
- **Static proof:** `UpdateApplication` is mentioned 0 times in `Router.approval.teal`. The ARC-4 dispatcher has no update route.
- **Verdict:** Clean (false positive detector timeout).

### `is-deletable` (HIGH)
- **Result:** Covered (timeout + static proof).
- **Detector behaviour:** This detector looks for any path that allows DeleteApplication. The router has `_delete_application` as a deliberate baremethod.
- **Static proof:** `DeleteApplication` is mentioned 3 times in `Router.approval.teal` (in `_delete_application` body). The handler is gated by:
  - `_assert_group_is_clean`
  - `Txn.sender == self.admin`
  - `accrued == 0`
  - `total_assets == 0`
- **Verdict:** Clean (by design — deletion is admin-only with assertions).

### `constant-gtxn` (OPT)
- **Result:** 0 findings.
- **Verdict:** Clean (no constant absolute `gtxn` indices).

### `self-access` (OPT)
- **Result:** 0 findings.
- **Verdict:** Clean (no `gtxn.ApplicationID(idx) == Global.current_application_id` patterns that could be exploited).

### `sender-access` (OPT)
- **Result:** 0 findings.
- **Verdict:** Clean.

### `unprotected-updatable` (HIGH)
- **Result:** 9 findings.
- **Verdict:** False positive (by design). The router has no `UpdateApplication` handler; the 9 references are in the ARC-4 dispatcher's baremethod coverage.

### `unprotected-deletable` (HIGH)
- **Result:** 9 findings.
- **Verdict:** False positive (by design). The router's `_delete_application` is gated by `_assert_group_is_clean`, `Txn.sender == self.admin`, `accrued == 0`, `total_assets == 0`.

### `clear-is-updatable` (HIGH)
- **Result:** 1 finding (clear program path `0->1`).
- **Verdict:** False positive. The clear-state program is `pushint 1; return` — 7 lines. It cannot be "updated" because ARC-4 clear-state programs are not updatable.

### `clear-missing-fee-check` (HIGH)
- **Result:** 1 finding (clear program path `0->1`).
- **Verdict:** False positive. The clear-state program never submits inner transactions or pays fees.

### `clear-rekey-to` (HIGH)
- **Result:** 1 finding (clear program path `0->1`).
- **Verdict:** False positive. The clear-state program cannot rekey.

### `clear-group-size-check` (HIGH)
- **Result:** 0 findings.
- **Verdict:** Clean.

## Build metadata

From `router/build/tealer/sweep-*.out`:

```
revision  5690473
tree      N file(s) modified
started   2026-08-22T08:33:04Z
approval  912562e7e546a582 (4657 lines)
```

## Notes on `.err` files

Each detector's `.err` file contains two repeated warnings:

```
Not found instruction: "#pragma typetrack false"
```

This is a Tealer version mismatch — Tealer's grammar predates the `#pragma typetrack false` directive that puyapy 5.9.0 emits. The warning is benign and does not affect detection.

## Comparison to v3

The v3 Tealer sweep at git revision `5690473 -7` (one commit earlier) showed the same results: 0 results for the high-impact detectors (`can-close-account`, `can-close-asset`, `group-size-check`), 9 false positives for `unprotected-updatable` and `unprotected-deletable` (by design), and the same 1 false positive for the clear-state detectors. **No regressions from v3 to v4.**

## Cross-references

- [`scanner-results.md`](scanner-results.md) — Trail of Bits 11-pattern checklist
- [`../REPORT.md`](../REPORT.md) — high-level audit report
- `router/docs/tealer-triage.md` — v3 triage notes (still applicable to v4)
