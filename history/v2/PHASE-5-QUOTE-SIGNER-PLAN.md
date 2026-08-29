# Phase 5: Quote-Signer Co-Signing in the Engine

**Implementation status:** backend signing and the partial-group wallet bridge
are implemented in the worktree. Testnet deployment verification and the
two-normal-signature production-engine submission are complete. Mobile-wallet
runtime verification and unrestricted release remain outstanding.

The two-normal-signature Testnet submission is now implemented and passing via
`engine/core/tests/test_router_testnet.py` against application `769208655`.
The test is explicitly opt-in because it spends Testnet funds.

This document defines the prerequisites, architecture and acceptance criteria
for integrating the router's quote signer with the engine and mobile-wallet
flow.

## 1. Decision: Signing Order

The recommended flow is:

1. The engine builds and groups the complete transaction set.
2. The backend signs only the transaction sent by `quote_signer`.
3. Pera, Defly or another wallet signs only the user's transactions.
4. The signatures are merged into one ordered atomic group.
5. The complete group is submitted once.

The quote-signer transaction must **not** be submitted separately. It is only a
signature-bearing member of the final group.

Algorand supports this model natively. All participants define the ordered
transaction group, each sender signs only its own transactions, and the full
group is submitted as one atomic unit.

Reference: [Algorand Atomic Transaction Groups](https://developer.algorand.org/docs/get-details/atomic_transfers/)

### Alternative order

Wallet-first signing is technically possible:

```text
engine builds group
wallet signs user transactions
client sends the partial group to the backend
backend validates and signs the quote transaction
client submits the complete group
```

It is less desirable because it adds a round trip after wallet approval and
makes the backend part of the latency-critical path. Backend-first partial
signing is the recommended architecture.

## 2. What Happens While the User Signs

Signing is off-chain. No transaction has been submitted and no ledger state
changes while the user is looking at a wallet prompt.

The following can happen during signing:

- The current round advances.
- Pool reserves change.
- The user's balance changes.
- The transaction validity window expires.

The safety consequences are:

- If the validity window expires, the group is rejected and nothing executes.
- If pool state changes and output falls below the signed floor, the router
  rejects the group atomically.
- If the user's input balance changes, the funding transaction fails and the
  route does not partially execute.
- If any transaction is modified after grouping, the group ID/signatures no
  longer match and submission fails.

If a group expires or submission fails because state moved, the client must
obtain a fresh quote and rebuild the entire group. It must not reuse an old
partially signed group.

## 3. Current Code Gap

### Engine

`engine/core/router.py` now returns unsigned user transactions plus a
backend-signed quote transaction. `engine/core/quote_signer.py` loads the
network-specific mnemonic, verifies its derived address against on-chain state,
and signs only the final authorization.

### Widget

`widgets/inhouse/swapcore/static/swap/swap.js` and
`frontend/wallet/src/swapBridge.ts` now support a mixed-signature group. The
remaining gap is runtime validation through Pera/Defly and testnet submission.

### Group validity

`assemble_with_quote()` already:

- Builds the complete route group.
- Calculates route-call indexes.
- Creates the signed-floor note.
- Appends the quote authorization last.
- Reassigns the group ID.

`quote_transaction()` uses the same suggested parameters as the rest of the
group and sets the quote transaction fee to zero.

The transaction construction is therefore compatible with multi-party
signing. The missing pieces are signer integration, wallet handling and an
explicit validity-window policy.

## 4. Wallet Compatibility Prerequisite

Pera Connect documents per-transaction signer declarations:

```javascript
interface SignerTransaction {
  txn: Transaction;
  signers?: string[];
}
```

Pera documents that an empty `signers` array causes the wallet to skip signing
that transaction.

Reference: [Pera Connect Signing Transactions](https://docs.perawallet.app/references/pera-connect/#signing-transactions)

The expected Pera mapping is:

user transaction: signers = [userAddress]
quote transaction: signers = []
```

This must be verified experimentally. Defly and every other supported mobile
wallet need their own compatibility test. Do not assume Pera's behavior is
portable.

The wallet compatibility spike must answer:

- Can the wallet receive a group containing a pre-signed transaction?
- Can it skip a transaction whose signer is not the connected user?
- Does it return placeholders for skipped transactions or omit them?
- Does it preserve the original group ID?
- Does it return transactions in exactly the original group order?
- Can the resulting mixed-signature group be submitted successfully?

If a wallet cannot preserve pre-signed transactions, the adapter must report
that the router is unavailable for that wallet. It must not silently drop the
quote signature.

## 5. Signer-Key Prerequisites

The configured signer files are:

```text
~/.config/asastats/router-signer-testnet.mnemonic
~/.config/asastats/router-signer-mainnet.mnemonic
```

Both files currently have mode `600`.

The signing service must:

1. Load the network-specific mnemonic server-side only.
2. Derive the public address at startup.
3. Read the configured on-chain `quote_signer`.
4. Refuse to start or sign if the derived address does not match the on-chain
   signer.
5. Never return, log or expose the mnemonic or private key.
6. Keep testnet and mainnet signer configuration separate.
7. Refuse to fall back from a missing signer key to a caller-controlled floor.

The quote signer does not need to pay the quote transaction fee because its fee
is zero and the group pools fees onto the user's route transaction. It must
still be a valid configured account.

## 6. Validity-Window Policy

The current code delegates validity parameters to `algod.suggested_params()`.
That is technically valid, but the wallet flow needs an explicit policy.

Define:

```text
QUOTE_VALIDITY_ROUNDS
```

All transactions in a group should use the same `first_valid` and `last_valid`
window. The quote-signer transaction must use the same window.

Recommended starting policy:

- Build the group only after the user presses Swap.
- Use a short validity window, initially around 100-120 rounds.
- At approximately 2.8 seconds per round, this gives roughly 4.5-5.5 minutes.
- Return the final expiration round in the API response.
- Rebuild the entire group if signing or submission exceeds the window.

Finalize the value after measuring actual Pera and Defly signing latency.

## 7. Signing-Service Interface

Define a narrow internal signing function similar to:

```text
sign_quote_authorization(
    network,
    router_app_id,
    expected_quote_signer,
    grouped_transactions
) -> signed_quote_transaction
```

It must validate:

- The final transaction is the quote authorization.
- Its sender equals the configured quote signer.
- Its application ID equals the router application ID.
- Its selector is `pool_budget()`.
- Its note has the expected fixed length.
- The group ID is assigned.
- The validity window is within policy.
- The note binds the expected caller, output asset, floor and route indexes.

The signer signs only the final quote transaction. It must never sign all
transactions with the quote key.

## 8. API Contract

The current API returns only unsigned transactions. The Phase 5 API should
make partial signing explicit, for example:

```json
{
  "transactions": [
    {
      "index": 0,
      "signed": false,
      "msgpack": "..."
    },
    {
      "index": 6,
      "signed": true,
      "sender": "QUOTE_SIGNER_ADDRESS",
      "msgpack": "..."
    }
  ],
  "quote_signer_index": 6,
  "first_valid": 123456,
  "last_valid": 123576,
  "quote": {}
}
```

The exact schema should be selected after the wallet compatibility spike.

The response must make it impossible for the browser to replace the
backend-signed quote transaction without causing final group verification to
fail.

## 9. Implementation Plan

### Step 1: Add signer configuration

Create a server-side signer module that:

- Selects the testnet or mainnet mnemonic path.
- Loads the mnemonic only in the backend signing process.
- Derives and verifies the signer address.
- Exposes no private key outside the signing function.

Use testnet first. Do not change mainnet deployment metadata yet.

### Step 2: Sign after `assemble_with_quote`

Modify the engine flow after `group_for_quote()` returns:

1. Identify the final quote authorization.
2. Validate the transaction and group.
3. Sign it with the network-specific quote signer.
4. Return the mixed-signature group metadata.

### Step 3: Add wallet adapters

Update the ASA Stats wallet bridge to:

- Mark user transactions for wallet signing.
- Mark the quote transaction as skipped.
- Preserve the backend-signed quote transaction.
- Merge wallet signatures by group index.
- Verify every transaction has the expected sender/signature before submission.

### Step 4: Add engine tests

Add tests under `engine/core/tests/test_router.py` for:

- Correct quote-signer transaction index.
- Correct quote-signer sender.
- Exactly one quote authorization.
- Quote authorization remains last.
- Backend signature validates with the public key.
- User transactions remain unsigned for the wallet.
- Group ID remains unchanged after signatures are merged.
- A restricted deployment still raises `RouterUnavailable`.
- A missing or mismatched signer key fails closed.
- An expired group is rejected and requires rebuilding.
- A modified group cannot receive a valid quote signature.

The main test must use real Algorand transaction serialization and signature
verification rather than mocks.

### Step 5: Add LocalNet end-to-end signing

Use two keys:

- The LocalNet route caller.
- The LocalNet quote signer.

Build the group through the engine path, sign only the quote transaction with
the quote signer, sign user transactions with the caller, merge the signatures
and submit the group.

This test must use normal signature validation. It must not use
`allow_empty_signatures`.

### Step 6: Test mobile wallets on testnet

With a fresh verified testnet deployment:

1. Build a real routed group.
2. Backend-sign the quote transaction.
3. Send the mixed-signature group to Pera.
4. Sign through the mobile wallet.
5. Merge and submit.
6. Repeat with Defly.
7. Test cancellation, delayed approval and expired validity windows.
8. Verify successful output and final router balances.

### Step 7: Mainnet release gate

Do not change `MAINNET.restricted=True` until:

- Engine co-signing works through the full production API.
- Pera and Defly preserve the mixed group.
- Testnet execution succeeds with real wallet signatures.
- A fresh contract deployment contains verified bytecode.
- A restricted mainnet canary passes.
- A new unrestricted deployment is created and tested by a non-admin account.

## 10. Recommended Decision

Use backend-first partial signing:

```text
build and group once
backend signs quote transaction
wallet signs user transactions
merge
submit once
```

This is standard Algorand atomic-group behavior and does not require waiting
for a block between signatures.

The main engineering risks are:

- Wallet support for skipped/pre-signed group members.
- Transaction validity-window expiry.
- Correct merging by group index.
- Preventing transaction mutation after backend signing.
- Removing the engine and wallet assumption that every transaction is
  user-signed.

## 11. References

- [Algorand Atomic Transaction Groups](https://developer.algorand.org/docs/get-details/atomic_transfers/)
- [Algorand Transaction Types and Validity Windows](https://developer.algorand.org/docs/get-details/transactions/)
- [Pera Connect Signing Transactions](https://docs.perawallet.app/references/pera-connect/#signing-transactions)
