# Smart Contract Improvements and Code Optimizations (v3)

## 1. Implemented Improvements in v3

### 1.1 Dead Code Removal in `_swap_leg` (Finding I1)
- **Problem:** In `_swap_leg()`, an older code block checked `if provider != PROVIDER_STAMM and leg.opups.native:` to invoke an inner budget application call. However, the line immediately preceding it asserted `assert leg.opups.native == 0` for non-STAMM providers, rendering the subsequent block permanently unreachable.
- **Remediation:** Removed the dead code block and associated commentary from `contracts/router_app.py`.
- **Impact:**
  - Reduced compiled TEAL approval bytecode from 4,707 lines to 4,641 lines (saving 66 TEAL instructions and 3 basic blocks).
  - Cleaned up control flow and eliminated confusion regarding opcode budget distribution.
  - 100% of unit, contract, and offline tests pass cleanly.

---

## 2. Summary of Key Historic Improvements (v1 & v2)

1. **Permissionless Fee Conversion Hardening (C1):** Made `convert_and_distribute` admin-only and moved pool selection to a pre-approved global state variable (`self.conversion_pool`).
2. **Backend Co-Signed Quote Floor (H1):** Replaced user-supplied `minimum_received` parameter with a backend-signed transaction note, eliminating the residual frontend compromise risk (T5).
3. **Funding Payment Adjacency (M2):** Enforced `payment.group_index + 1 == Txn.group_index` in `_input_amount()`.
4. **Pre-Held ASA Input Conservation (M3):** Added `_assert_input_spent` to verify 100% input token consumption.
5. **Path Sanitization (M1):** Enforced pairwise distinctness for all assets in `route` and `route3`.
6. **Same-Group Approval Separation (M6):** Added `_assert_no_conversion_pool_approval()` to disallow bundling pool approval with conversion.
7. **Sub-Floor Dust Sweep Exemption (M1 v2 / L4):** Restricted the zero-floor exemption strictly to remainder dust sweeps where `batch < MIN_CONVERSION_BATCH`.

---

## 3. Operational Infrastructure & Future Enhancements

### 3.1 Production Monitoring & Management Stack (Implemented)
The engine provides a complete operational monitoring suite under `engine/core/management/commands/`:
- `poll_router_monitor`: Polling daemon tracking on-chain contract state, float balance changes, fee accruals, and webhook alerts.
- `router_monitor_status`: Real-time health, cursor, and error status reporting.
- `router_alerts` & `resolve_router_alert`: Operator alert triage and resolution.
- `retry_router_alerts`: Resilient retry delivery for failed webhook dispatches.

### 3.2 Future Enhancements
1. **STAMM Multi-Tier Single-Leg Calling (I6):** Upgrade `Leg` and `_stamm_leg` in a future major release to support packed multi-tier splits in a single call, improving routing efficiency for stratified liquidity.
2. **Dynamic Quorum Multisig for Admin Operations:** Migrate single-account administrative functions to a hardware-enforced multisig or timelocked governor proxy.
