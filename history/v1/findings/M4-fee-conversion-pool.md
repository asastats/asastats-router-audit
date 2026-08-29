# M4 — Fee conversion pool is not pinned or approved

**Severity:** Medium
**Location:** `router/contracts/router_app.py`, `convert_and_distribute`
**Status:** **Patched** — the pool is approved ahead of time and the argument is gone

## Description

`convert_and_distribute` accepted a `Leg` argument naming the pool used to swap
accrued ALGO into ASASTATS. There was no restriction on which pool that could
be.

This is the same root cause as C1. The admin-only patch for C1 closed the
attack; it did not close the finding, because it left the *admin* naming the
pool inside the same transaction that spends the money.

## Impact

Accrued fees converted through a low-liquidity, delisted or mistyped pool,
resulting in bad execution or loss.

## Fix as implemented

The argument was **removed**, not cross-checked — the same shape as H1's
removal of `minimum_received` from `route`. A parameter that must equal state
is a parameter that can be got wrong; an ABI with no parameter cannot express
the mistake.

- `set_conversion_pool(leg)` — admin-only, stores the encoded struct in global
  state. All seven fields, because a pool is not one identifier: Pact and STAMM
  are named by `app`, Tinyman by the pair its address is derived from, and STAMM
  further by `tier` and `hub`.
- `convert_and_distribute(batch, minimum_out)` — reads the approved leg and
  refuses while none is set.

Empty is the unset sentinel rather than a zeroed `Leg`, and the distinction is
load-bearing: an all-zero struct names provider 0, Tinyman v2, whose pool
address is derived from the assets being traded rather than read off the leg —
so a zeroed struct would have silently meant *the Tinyman ALGO/ASASTATS pool*
and the unset state would have been unreadable.

`scripts/set_conversion_pool.py` is the operator's side, and README's Deploying
section carries it as the fifth step.

## What this does not do, stated because the original finding implied otherwise

**It is not a defence against a stolen admin key.** That key can call
`set_escrow` and point the conversion's output at itself, then convert
perfectly legitimately. The accrued balance is reachable by the admin whatever
is pinned here, and `MAX_CONVERSION_BATCH` bounds one call rather than
repetition. This guards *mistakes*, which is the failure an admin-only method
will actually meet.

## Fails closed, with a cost worth knowing

A deployment that never runs `set_conversion_pool` cannot convert, and because
`delete_application` refuses while `accrued` is non-zero, **the first fee it
skims makes it unretirable until a pool is approved.** The float is recoverable
— run the step late — but `scripts/retire.py` now reports this as a blocker
rather than letting the operator discover it from a rejected transaction.

## Verified by

- `tests/test_router_contract.py::TestTheApprovedConversionPool` — the guards,
  by message: admin-only, fails closed, stores all seven fields, replaces on
  re-approval, and the ABI carries no pool argument at all.
- `tests/test_contract_localnet.py::TestTheApprovedConversionPool` — on a
  ledger: a fee accrued, a pool approved, the sweep executed, the escrow paid,
  and the borrowed opt-in given back.
- `tests/test_contract_testnet.py::test_fees_accrue_and_convert` — against a
  real Pact pool.
