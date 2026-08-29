# H1 — Widget-controlled `minimum_received` allows bad-floor attacks

**Severity:** High  
**Location:** `router/contracts/router_app.py`, `route` / `route3`  
**Status:** **Patched** — implemented as a co-signed transaction, not as the signature check recommended below

> **Implemented differently from the recommendation in this file, deliberately.**
> `minimum_received` was *removed* from `route`/`route3` rather than kept and
> cross-checked, and the floor now travels in the note of a transaction sent by
> a `quote_signer` account — so the AVM authenticates the sender and nothing is
> verified on chain. The recommended `ed25519verify_bare` shape costs 1,900
> opcode units against the 700 an application call is given, so it needed two
> `pool_budget` calls; measured against a full benchmark run, those three slots
> cost a mean 2.4 basis points of realised output and up to 0.82% on the widest
> splits. See REPORT.md §H1 and `docs/signed-floor.md`. Verified on LocalNet by
> `TestTheAuthorisedFloor`.

## Description

The router enforces `self._group_paid(asset_out, received) >= minimum_received`. The value of `minimum_received` is supplied by the caller and is intended to be the output the widget showed the user, less slippage.

The contract has no way to know what the user was actually shown. A compromised frontend can pass `minimum_received = 0` and the contract will execute the trade at whatever price the genuine pools offer.

This is the residual risk left after the T5 fix (derived Tinyman pool addresses). It is smaller than the original T5 attack because the pool addresses are fixed, but it is not zero.

## Attack scenario

1. Attacker compromises the widget or a dependency (e.g., a CDN script).
2. User clicks "Swap 10 ALGO → USDC".
3. The compromised widget builds a group with `minimum_received = 0`.
4. The contract executes through genuine pools at the genuine — but potentially very bad — price.
5. The user receives far less USDC than expected.

The loss is bounded by the depth of genuine pools, not by an attacker's own pool, but it can still be material for thin-pool trades.

## Impact

Loss of value for users on thin or volatile pairs when the frontend is compromised.

## Why existing mitigations are insufficient

- `_assert_group_is_clean` only prevents rekey/close attacks, not a bad floor.
- Refusing `minimum_received == 0` is trivially bypassed with `1`.
- Bounding the floor against spot price requires an on-chain oracle and hard-codes a slippage ceiling.

## Recommended fix

Implement a backend-signed floor, analogous to the voucher mechanism:

1. Add a `quote_signer` global state and `set_quote_signer` admin method.
2. Add a `verify_quote(byte[])` method that checks an ed25519 signature over:
   - `DISCOUNT_DOMAIN`-style domain separator
   - `Global.current_application_id`
   - `Txn.sender`
   - `asset_in`, `asset_out`, `amount_in`
   - `minimum_received`
   - `expiry_round`
3. In `route` / `route3`, require a `verify_quote` call from the same sender in the group and assert that the `minimum_received` passed to the route matches the signed value.

This keeps the user in control of authorising the trade while ensuring the floor is the one the backend computed.

## References

- `router/README.md` section *"The floor is the widget's number, and what could be done about it"*
- `router/SECURITY.md` accepted risk #1
