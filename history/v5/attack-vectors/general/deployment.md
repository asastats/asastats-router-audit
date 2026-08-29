# Attack Vectors: Deployment, Upgradability & Retirement (v5)

## 1. Attack Vector Overview
Smart contract deployment, template substitution, clear-state execution, and contract retirement lifecycle must not leave funds trapped or open attack vectors.

---

## 2. Specific Vectors & Evaluations

### V-DEP-01: Unauthorized Logic Replacement / Updatability
- **Attack:** An attacker calls `UpdateApplication` to overwrite contract logic.
- **Evaluation:** The contract contains no update route in its ARC-4 dispatcher. The compiled TEAL contains 0 instances of `UpdateApplication`. Tealer findings are formally proven false positives (`docs/tealer-triage.md`).
- **Verdict:** **DEFENDED.**

### V-DEP-02: Premature Application Deletion & Fund Stranding
- **Attack:** Admin or attacker calls `delete_application` while user funds or accrued fees remain in the contract.
- **Evaluation:** `delete_application` enforces:
  1. `assert Txn.sender == self.admin`
  2. `assert self.accrued == 0` (all fees must be converted/withdrawn)
  3. All asset holdings must be closed (`total_assets == 0`).
  Any non-zero balance blocks deletion.
- **Verdict:** **DEFENDED.**

### V-DEP-03: Clear-State Program Exploitation
- **Attack:** A caller invokes `ClearState` to manipulate contract state or drain assets.
- **Evaluation:** The clear-state program is minimal (`pushint 1; return`). The contract uses no local state, so `ClearState` executes cleanly without state side-effects or fund access.
- **Verdict:** **DEFENDED.**
