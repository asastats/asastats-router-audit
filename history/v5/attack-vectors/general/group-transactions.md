# Attack Vectors: Transaction Group Structure & Hygiene (v5)

## 1. Attack Vector Overview
Algorand atomic groups group 2 to 16 transactions into a single execution unit. Attackers often attempt to smuggle malicious operations (such as account rekeying or balance close-outs) alongside a legitimate swap approval.

---

## 2. Specific Vectors & Evaluations

### V-GRP-01: Smuggled Rekey Attack on Caller Account
- **Attack:** A malicious widget creates a transaction group where the user signs an asset transfer to the router plus a hidden transaction with `rekey_to` set to the attacker's address.
- **Evaluation:** `_assert_group_is_clean()` iterates through all transactions in `urange(Global.group_size)` and asserts `gtxn.Transaction(index).rekey_to == Global.zero_address`. Any non-zero rekey aborts the entire group.
- **Verdict:** **DEFENDED.** Pinned by `TestGroupHygiene` across 7 localnet test cases.

### V-GRP-02: Smuggled CloseRemainderTo / AssetCloseTo Drain
- **Attack:** An attacker appends a transaction with `close_remainder_to` or `asset_close_to` targeting the caller's wallet or the router account.
- **Evaluation:** `_assert_group_is_clean()` verifies that `close_remainder_to` and `asset_close_to` are strictly zero for every outer transaction.
- **Verdict:** **DEFENDED.**

### V-GRP-03: Transaction Group Padding & Reordering
- **Attack:** An attacker inserts decoy transactions between the funding payment and the route call to bypass accounting.
- **Evaluation:** `_input_amount()` explicitly verifies `assert payment.group_index + 1 == Txn.group_index`, enforcing strict payment-to-route adjacency.
- **Verdict:** **DEFENDED.**

### V-GRP-04: Truncated Quote Split Exploitation
- **Attack:** An attacker drops one route call from a multi-route split, attempting to satisfy the quote floor with only partial execution.
- **Evaluation:** The quote note binds per-position input amounts at each exact group index. If any route call is dropped, the note index mismatch triggers an immediate assertion failure.
- **Verdict:** **DEFENDED.**
