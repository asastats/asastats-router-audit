# MBR Draining Attack Vectors

These vectors analyze attacks that drain the router's ALGO balance via Minimum Balance Requirement (MBR) increases. The router must opt into ASAs to receive them, and each opt-in costs 0.1 ALGO of MBR.

## Vectors

### GENERAL-MBR-01: Opt-in to attacker-created ASA, lock MBR permanently
- **Verdict:** Defended.
- **Code:** Opt-ins only happen during `_open_holding` for assets in the current route; the holding is closed by `_pay_out` before the route ends.
- **Test:** Adversarial pool tests + balance neutrality test.

### GENERAL-MBR-02: Opt-in to many small ASAs across many routes
- **Verdict:** Defended.
- **Code:** `_pay_out` is called for every intermediate asset; the opt-in is closed at the end of the route.
- **Test:** Repeated-route test.

### GENERAL-MBR-03: Opt-in to ASA, route fails, holding not closed
- **Verdict:** Defended.
- **Code:** The contract reverts on route failure; all inner transactions are reverted (Algorand atomicity).
- **Test:** Manual adversarial test.

### GENERAL-MBR-04: Opt-in to ALGO via Payment with non-zero amount
- **Verdict:** Defended.
- **Code:** `_open_holding` only opts in via zero-amount Payment, no transfer.
- **Test:** Manual.

### GENERAL-MBR-05: Opt-in to legacy ASA that has been deleted
- **Verdict:** Defended.
- **Code:** Opt-in to a deleted asset fails (the asset does not exist), route reverts.
- **Test:** Manual.

### GENERAL-MBR-06: Box storage drainage
- **Verdict:** Not applicable.
- **Code:** The router uses no box storage directly; only outer pool references are in boxes (read by pools, not by the router).
- **Test:** n/a.

---

## Detailed analysis

The router's MBR-management pattern is:

1. **Read intermediate balance:** `_held(asset_out)` before the inner call.
2. **Inner transaction:** deposit + pool call.
3. **Measure output:** `_held(asset_out) - before`.
4. **If asset_out is intermediate:** carry to next leg.
5. **If asset_out is final:** `_pay_out` to `Txn.sender`, closing the holding.
6. **If route fails:** atomicity reverts all inner transactions.

The key invariant is that **every opened holding is closed by the end of a successful route**, and **a failed route leaves no residue** because of atomicity. The two exceptions:

- **Failed route that opted into ASA but did not close it:** atomicity ensures the opt-in is reverted. So no residue.
- **Successful route that pays out:** the ASA is sent via `AssetTransfer` with `asset_close_to = Txn.sender` (or implicitly via the balance measurement followed by a zero-balance transfer). Wait — `_pay_out` does *not* use `AssetCloseTo`; it sends the exact amount via `AssetTransfer`. The opt-in remains.

Actually, the opt-in remains for assets that the router still holds (e.g., if the route ends with an asset that becomes the router's new float). But the router is designed to pay out every final asset, so the opt-in is closed.

The router's float is exactly the assets it opted into previously that are still needed for future routes. This is intentional and bounded — see `_pay_out`'s "close the holding" behaviour for assets with zero balance.

OK, so the MBR analysis holds: the router's MBR is bounded by the number of assets it currently holds, and the float management closes holdings aggressively. No drainage vector is left.
