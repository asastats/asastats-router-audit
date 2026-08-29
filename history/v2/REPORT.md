# Smart Router Security Audit Report v2

**Auditor:** AI-assisted review, informed by the STAMM audit and analyses 1-3
**Date:** 2026-08-13
**Contract:** `router/contracts/router_app.py`
**Network context:** Algorand mainnet; v2 brief describes application `3671595889`
**Question:** may `RESTRICT_TO_ADMIN` be lifted?

## Executive Summary

The router is materially safer than the v1 subject. The most important v1
surfaces are addressed: the floor is co-signed, Tinyman v2 pools are derived,
Pact/STAMM/AlgoFi calls are bounded, fee conversion is admin-only and uses an
approved pool, route cycles are rejected, and inner transaction fees are zero.

This review found no confirmed path for an arbitrary unrestricted caller to
redirect another caller's input or bypass the authenticated output floor,
assuming the configured provider boundaries and quote signer are trusted.

The deployment question still has a negative answer today. The engine now
signs the quote transaction after group assembly and the wallet bridge preserves
it while signing only user indexes. Pera/Defly runtime verification and a real
testnet submission remain outstanding. This is still a release gate, not a
direct theft issue.

Three contract-level accounting weaknesses were also fixed in the worktree:

- the zero-floor final-sweep exception is now restricted to sub-floor dust;
- funding transaction adjacency is checked on chain; and
- a first leg must consume the full ASA input amount, even for a pre-held asset.

The source was compiled after these changes with Puya 5.9.0. The full v2 brief
reports 662 passing tests and 2 skips; this worktree run independently passed
64 focused contract tests and 521 offline tests.

## 1. Architecture and trust boundaries

The contract receives a payment or ASA transfer, executes two or three inner
swap legs, measures each output from its own balance, and pays the final output
to `Txn.sender`. The route path does not accept a recipient or a raw Tinyman
pool address. It does accept provider-specific leg fields and external app
identifiers, subject to provider checks.

The contract's value boundaries are:

| Value | Exposure | Relevant controls |
|---|---|---|
| Caller input and intermediate assets | Highest | sender/receiver checks, balance deltas, atomicity, floor |
| Application float | Operational | route-bound opt-ins, zero inner fees, close checks |
| Accrued ALGO fees | Platform treasury | admin-only conversion, approved pool, batch bounds |

The quote signer is trusted for the floor, but not for administration. The
admin is trusted for deployment and treasury configuration, but a stolen admin
key is explicitly outside the treasury guarantee: it can redirect the escrow
through `set_escrow`.

## 2. Findings summary

| ID | Severity | Status | Title |
|---|---|---|---|
| H1 | High availability | Patched in worktree | Backend signing implemented; mobile-wallet verification pending |
| M1 | Medium | Patched | Zero-floor final sweep was broader than dust |
| M2 | Medium | Patched | Funding transaction was not adjacent to the route call |
| M3 | Medium | Patched | Pre-held ASA input was not conserved after a leg |
| M4 | Medium | Accepted conditionally | Creator pinning does not authenticate external code |
| M5 | Low | Patched | STAMM `opups` permits no request above the measured bound |
| M6 | Low | Patched | Pool approval and conversion require separate groups |
| I1 | Informational | Patched | Quote note was not tied to an authorisation call type |

V1 findings C1, H1, M1-M5, L1 and L4 are implemented in the reviewed source;
L2, L3 and L5 remain documented operational/design considerations.

## 3. Confirmed findings and changes

### H1 — Release builder does not provide the quote-signer signature

**Location:** `router/router/contract.py:1125-1179`,
`router/router/build.py:145-260`, `engine/core/router.py:595-604`.

`quote_transaction()` creates a transaction whose sender is `quote_signer`.
`assemble_with_quote()` appends it, but the production group endpoint previously
serialized all transactions unsigned for the wallet. A normal wallet cannot
sign a transaction whose sender is the separate quote-signer account. The
on-chain contract reads the last transaction and rejects a group whose sender
is not the configured quote signer.

The engine now signs the quote transaction after group assembly and returns it
as `signed_transactions`, while the user transactions remain unsigned. The
wallet bridge signs only user indexes and merges the backend signature. The
two-normal-signature Testnet submission passes; mobile-wallet runtime tests
remain required.

**Impact:** incorrect wallet integration will fail routed orders closed. This is
not a user-fund theft path, but it remains a release blocker until the mixed
signature flow is tested through Pera/Defly.

**Fix applied:** backend signing now occurs after group assembly and group
assignment. The API returns the quote-signer-signed transaction separately from
the unsigned user transactions, the wallet bridge preserves it, and
`test_router_testnet.py` submits the complete group with two normal signatures.
Mobile-wallet tests remain; they must not use `allow_empty_signatures`.

### M1 — Zero-floor final sweep was broader than dust

**Location:** `convert_and_distribute`.

The original condition allowed `minimum_out == 0` whenever `batch == accrued`.
That was intended for a dust balance whose conversion can round to zero, but it
also allowed a normal-sized full treasury conversion to accept zero output.
The transaction could therefore spend a complete accrued batch through the
approved pool without a meaningful output floor.

**Fix applied:** zero is accepted only when `batch == accrued` and
`batch < MIN_CONVERSION_BATCH`. A full sweep at or above the economic floor
must state a non-zero minimum.

### M2 — Funding transaction was not adjacent to the route call

**Location:** `_input_amount`.

The ABI transaction argument was checked for sender, receiver and asset, but
the contract accepted a reference to any transaction in the group. The builder
assumed the funding transaction immediately preceded the route call, but that
was not an on-chain invariant.

**Fix applied:** `_input_amount` now asserts
`payment.group_index + 1 == Txn.group_index` before reading the payment or asset
transfer. This also makes the route shape explicit for reviewers and fuzzers.

### M3 — Pre-held ASA input was not conserved after a leg

**Location:** `_swap_leg`, `route`, `route3`.

When the router was already opted into an input ASA, the builder omitted the
temporary opt-in and the route did not close the holding. The existing cleanup
therefore could not prove that a provider consumed the complete input transfer.
An incompatible or malicious external application could leave input units in
the router while returning enough output to satisfy the floor.

**Fix applied:** the route records the input ASA balance after the funding
transaction and asserts after the first leg that the balance decreased by
exactly `amount_in`. The check is skipped for ALGO, whose balance is also the
float and fee accounting balance. Phase 1 now exercises this with a test-only
pre-held-input harness and an approved-creator malicious pool that returns one
input unit to the router; the group rejects atomically.

## 4. Residual findings

### M4 — Creator pinning does not authenticate external code

Pact and STAMM pool apps are authenticated by `AppParamsGet.app_creator`, and
AlgoFi is authenticated by an explicit list. This is a meaningful boundary
against arbitrary public pool applications, but it is not a cryptographic
proof that the current approval program, update authority, state layout or
economic behavior is the expected one.

This becomes exploitable only if a pinned provider creator or an approved pool's
upgrade authority is compromised or deliberately deploys incompatible code.
The balance-delta and floor controls limit the result, but they do not make a
malicious approved provider honest.

**Disposition:** accepted conditionally for this deployment, with monitoring
and provider-specific code/factory review required. A provider factory or
immutable program hash is stronger where it fits the provider's upgrade model.

### M5 — Unbounded STAMM `opups`

`Leg.opups` is caller-controlled and is forwarded to the pinned STAMM budget
application. Before Phase 2 there was no explicit upper bound. Pathological
values could cause resource exhaustion, dynamic budget failure, or wasted group
capacity. Atomic failure and zero inner fees prevent this from draining the
router float, so the impact is availability/self-DoS rather than theft.

**Fix applied:** `MAX_STAMM_OPUPS = 8` is enforced in the contract and builder,
based on a routed floor of 7 plus one safety unit. Hypothesis tests cover the
full uint64 boundary and LocalNet tests cover the accepted/rejected contract
boundary. `tests/test_stamm_opups.py` passes against the strict mainnet
measurement suite. Any future increase requires remeasurement.

### M6 — Pool approval and conversion can share an admin group

`set_conversion_pool` stores state and `convert_and_distribute` reads it. Both
are admin-only, but the contract previously did not prevent an admin from
approving a pool and spending the accrued balance through that newly approved
pool in one atomic group. This weakened the stated M4 separation between
reviewing a destination and spending treasury funds.

**Fix applied:** `_assert_no_conversion_pool_approval` scans the outer group and
`convert_and_distribute` rejects any group containing `set_conversion_pool`. The
LocalNet regression verifies both rejection and rollback of the attempted
approval. This protects against administrative construction mistakes, not a
stolen admin key.

### I1 — Quote authorisation transaction type

Before this review, `_signed_floor` authenticated the sender and note fields but
did not require the final transaction to be an application call to this router.
The quote signer key is intended to sign only quote transactions, so this was a
trust-boundary assumption rather than a demonstrated public exploit.

**Fix applied:** the contract now requires the final transaction to target the
current application, carry one argument, and use the `pool_budget()` selector.

## 5. Properties that passed review

- `_input_amount` binds the funding sender to the route caller and the receiver
  to the router.
- `_pay_out` has no caller-controlled recipient; route output goes to
  `Txn.sender`.
- Tinyman v2 pool addresses are derived from the pinned validator and assets.
- Pact and STAMM pool app creators and AlgoFi app IDs are bounded at the
  contract boundary.
- `_swap_leg` measures actual output from the router's balance delta.
- Inner transaction fees and dangerous close/rekey fields are zero/absent.
- `_assert_group_is_clean` scans every outer transaction and rejects rekey and
  close operations.
- The quote note binds application, caller, output asset, per-index input
  amount, and asserting route index.
- The quote authorisation expires through its own transaction validity window.
- Route and route3 reject repeated assets and route3 rejects crossing itself.
- Route-bound opt-ins and same-group closes protect the application float.
- Deletion is admin-only and blocked while assets or accrued fees remain.

## 6. Recommendation on `RESTRICT_TO_ADMIN`

Do not lift it in the current release. First:

1. complete Pera/Defly mixed-signature tests through the production API;
2. deploy the patched bytecode with template values independently verified;
3. execute the route3 and treasury regression cases on LocalNet; the pre-held
   input adversarial case and opup boundary are now covered;
4. exercise all supported providers and conversion on the target network;
5. obtain human Algorand review; and
6. add monitoring for admin methods, accrual anomalies, float changes and
   provider leg counts.

After those gates, unrestricted deployment is reasonable only with the
conditional provider trust and quote-signer assumptions recorded above.

The target-network exercise matrix and monitoring implementation plan are in
`POST-DEPLOYMENT-OPERATIONS-PLAN.md`; the deployment verification procedure is
in `DEPLOYMENT-VERIFICATION.md`.
