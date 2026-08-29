# L1 — `delete_application` does not check for held ASAs

**Severity:** Low
**Location:** `router/contracts/router_app.py`, `delete_application`
**Status:** **Patched**

## Description

`delete_application` sends a `Payment` with `close_remainder_to=self.admin` to
recover the float. An Algorand account cannot be closed while it is opted into
any asset, so the close-out was rejected by the protocol and took the whole
group with it.

The method checked `accrued == 0` and nothing else.

**Its own docstring already claimed the check** — "Refused while any asset is
held" — which is the part worth recording. The finding was not a missing
safeguard nobody had thought of; it was a documented guarantee the code did not
provide, which is the harder kind to notice.

## Impact

- Deletion failed at chain level with nothing in the error naming an asset.
- An unexpected donation or a stranded holding had to be closed by the admin
  first, and the operator had no way to learn that from the failure.

## Fix as implemented

```python
assert Global.current_application_address.total_assets == 0, (
    "an asset is still held; close it first"
)
```

`total_assets` rather than a balance scan, for two reasons. It is the condition
the protocol actually enforces — an opt-in holding *zero* blocks the close just
as firmly as a funded one — and it is one opcode against a scan the contract
could not size in advance.

`close_holding` is the way out, one asset at a time, and it already refuses
while a holding is non-empty.

## The same gap existed one level up

`scripts/retire.py::blockers` pre-checks the delete conditions so an operator
learns about them before submitting. It filtered holdings on `amount > 0`, so
it would have reported *no blockers* while the delete failed anyway. It now
reports every opt-in, and says which of the two cases each one is.

## Verified by

`tests/test_router_contract.py::TestDeletion::test_a_held_asset_blocks_deletion`,
which sets `total_assets` directly — something the emulated context allows and
a chain does not.
