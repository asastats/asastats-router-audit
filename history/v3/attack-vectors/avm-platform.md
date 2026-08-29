# Attack Vectors: Algorand / AVM Platform Specific (Trail of Bits Checklist)

## Overview
Evaluation against the 11 vulnerability patterns in Trail of Bits' "Not So Smart Contracts" (Algorand Edition) and modern AVM platform security standards.

---

### Trail of Bits 11 Vulnerability Patterns

| Pattern ID | Vulnerability Name | Severity | Status in Router v3 | Verification Evidence |
|---|---|---|---|---|
| **TOB-01** | Rekeying Vulnerability | CRITICAL | **Defended** | `_assert_group_is_clean()` enforces `rekey_to == 0` on all txns in group |
| **TOB-02** | Missing Txn Verification (GroupSize/Index) | CRITICAL | **Defended** | Relative index binding in `_input_amount()` and dynamic range scanning |
| **TOB-03** | Group Transaction Manipulation | HIGH | **Defended** | Strict adjacency: `payment.group_index + 1 == Txn.group_index` |
| **TOB-04** | Asset Clawback / Freeze Risk | HIGH | **Defended** | Transitory custody; zero holding between routes; atomic revert on freeze |
| **TOB-05** | App State Manipulation | MEDIUM | **Defended** | Strict sender access control on all state setters; bounded values |
| **TOB-06** | Asset Opt-In Missing | HIGH | **Defended** | Dynamic opt-in check in `_open_holding()` before any inner transfer |
| **TOB-07** | Minimum Balance Violation (MBR) | MEDIUM | **Defended** | Net zero balance delta; opt-ins closed in same route transaction |
| **TOB-08** | Close Remainder To / Asset Close To | CRITICAL | **Defended** | `_assert_group_is_clean()` checks both close fields across entire group |
| **TOB-09** | Application Clear State Bypass | MEDIUM | **Defended** | Clear state program contains only `pushint 1; return`; holds no user funds |
| **TOB-10** | Atomic Transaction Ordering Assumption | HIGH | **Defended** | Relative indexing and strict adjacency assertions on funding transactions |
| **TOB-11** | Logic Signature Reuse / Replay | HIGH | **Defended** | Tinyman v2 pool logic signatures are stateless and derived deterministically |

---

### Additional AVM Platform Checks

#### AV-AVM-01: ARC-4 ABI Encoding Length & Offset Vulnerabilities
- **Status:** **Defended**
- **Analysis:** Compiled with Puya 5.9.0, which enforces strict ARC-4 dynamic array length prefix and offset validation by default.

#### AV-AVM-02: Unprotected Contract Updates
- **Status:** **Defended**
- **Analysis:** The `Router` contract implements no `UpdateApplication` method. Tealer analysis confirms bytecode is permanently immutable.

#### AV-AVM-03: OnComplete Action Fallthrough
- **Status:** **Defended**
- **Analysis:** ARC-4 method dispatcher explicitly handles `NoOp` for ABI methods and `DeleteApplication` for `delete_application`. All other `OnCompletion` actions revert.
