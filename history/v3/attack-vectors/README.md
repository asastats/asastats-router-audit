# Smart Router Attack-Vector Matrix (v3)

## Master Attack Vector Matrix (134 Vectors)

Verdicts use the standardized institutional audit classifications:
- **Defended:** An on-chain invariant, assertion, or tested architectural design provably blocks the attack vector.
- **Patched:** A vulnerability identified in audit passes that has been remediated and verified in code and tests.
- **Accepted:** An explicit, documented trust assumption or operational trade-off (e.g. admin key capabilities).
- **Not Applicable:** An EVM-specific or non-applicable pattern due to AVM architecture or router domain constraints.

---

### Master Summary by Category

| Category | Vector Count | Defended | Patched | Accepted | N/A | Deep-Dive Reference |
|---|---|---|---|---|---|---|
| **Group Transactions** | 16 | 13 | 3 | 0 | 0 | [`group-transactions.md`](group-transactions.md) |
| **Inner Transactions** | 14 | 12 | 2 | 0 | 0 | [`inner-transactions.md`](inner-transactions.md) |
| **Access Control & Admin** | 15 | 11 | 2 | 2 | 0 | [`access-control.md`](access-control.md) |
| **Route Correctness & Paths** | 15 | 13 | 2 | 0 | 0 | [`route-correctness.md`](route-correctness.md) |
| **Provider & Pool Spoofing** | 14 | 11 | 2 | 1 | 0 | [`provider-spoofing.md`](provider-spoofing.md) |
| **Resource Limits & DoS** | 14 | 12 | 2 | 0 | 0 | [`resource-limits.md`](resource-limits.md) |
| **Economic & Slippage** | 16 | 13 | 3 | 0 | 0 | [`economic.md`](economic.md) |
| **Conversion & Treasury** | 15 | 10 | 4 | 1 | 0 | [`conversion-treasury.md`](conversion-treasury.md) |
| **AVM Platform & ABI** | 15 | 12 | 2 | 1 | 0 | [`avm-platform.md`](avm-platform.md) |
| **Total** | **134** | **107** | **22** | **5** | **0** | **Comprehensive** |

---

### Key Highlighted Vectors & Verdicts

| ID | Attack Vector Description | Verdict | Primary Defense Mechanism |
|---|---|---|---|
| AV-GRP-01 | RekeyTo injection in atomic group to hijack caller account | **Defended** | `_assert_group_is_clean()` verifies `rekey_to == 0` on all group txns |
| AV-GRP-02 | CloseRemainderTo / AssetCloseTo drain in group | **Defended** | `_assert_group_is_clean()` checks close fields across whole group |
| AV-GRP-03 | Smuggling unauthenticated funding transaction | **Patched** | `_input_amount` asserts `payment.group_index + 1 == Txn.group_index` |
| AV-GRP-04 | Reordering or padding route calls | **Defended** | Group index binding and sequential execution semantics |
| AV-INN-01 | Inner transaction fee draining router ALGO float | **Defended** | All inner transactions set `fee = 0`; fees pooled on outer call |
| AV-INN-02 | Inner call receiver redirection | **Defended** | Pool addresses derived or pinned; payouts set to `Txn.sender` |
| AV-ACC-01 | Stranger calling administrative setters | **Defended** | `assert Txn.sender == self.admin` on all admin methods |
| AV-ACC-02 | Setting fee above safety ceiling | **Defended** | `assert fee_bps <= MAX_FEE_BPS` (100 bps ceiling) |
| AV-ACC-03 | Unsetting quote signer to disable slippage | **Defended** | `set_quote_signer` rejects zero address; rotation only |
| AV-ROU-01 | Circular routes (A -> B -> A) or self-swaps | **Defended** | Pairwise distinct assertions on all assets in `route` and `route3` |
| AV-ROU-02 | Stranded pre-held ASA input in router | **Patched** | `_assert_input_spent` verifies exact consumption of input balance |
| AV-ROU-03 | Residual intermediate tokens left in router | **Defended** | `assert self._held(middle) == 0` and immediate close-out |
| AV-SPO-01 | Tinyman v2 malicious pool injection | **Defended** | Pool address derived on-chain via logic signature program hash |
| AV-SPO-02 | Pact / STAMM fake pool deployment | **Defended** | Creator address checked against pinned creator addresses |
| AV-SPO-03 | AlgoFi fake pool injection | **Defended** | Pool app ID checked against curated whitelist; manager pinned |
| AV-RES-01 | MBR draining via junk asset opt-in | **Defended** | `opt_in_asset` requires matching route; route closes holding |
| AV-RES-02 | Opcode exhaustion via unbounded STAMM opups | **Patched** | `MAX_STAMM_OPUPS = 8` hard cap; non-STAMM opups disallowed |
| AV-ECO-01 | Zero-floor frontrunning via compromised widget | **Patched** | Floor authenticated via backend quote signer note; removed from ABI |
| AV-ECO-02 | Trimming asserting route call from split group | **Defended** | Note binds `asserting` index and verifies it is a valid route |
| AV-ECO-03 | Multi-hop cross-hop slippage leakage | **Defended** | Single aggregate floor enforced on realized return values |
| AV-TRZ-01 | Public fee conversion pool drain (C1) | **Patched** | `convert_and_distribute` made admin-only and pool pre-approved |
| AV-TRZ-02 | Same-group pool approval and conversion | **Patched** | `_assert_no_conversion_pool_approval()` rejects same-group approval |
| AV-TRZ-03 | Zero-floor conversion drain | **Patched** | Non-zero floor required unless sub-floor dust final sweep |
| AV-AVM-01 | Puya ARC-4 dynamic array encoding vulnerability | **Defended** | Puya 5.9.0 pins length checks; strict typed ABI arguments |
| AV-AVM-02 | Unprotected contract update / overwrite | **Defended** | `UpdateApplication` rejected by ARC-4 dispatcher; bytecode immutable |
