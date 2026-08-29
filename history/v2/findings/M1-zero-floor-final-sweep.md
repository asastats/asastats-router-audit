# M1 — Zero-floor final sweep was not limited to dust

**Severity:** Medium
**Status:** Patched in the worktree

The prior condition accepted `minimum_out == 0` whenever `batch == accrued`.
That was intended to make a below-floor dust balance retireable, but it also
allowed a full normal-sized balance to be converted without any output floor.

The contract now requires a non-zero floor unless the full balance is below
`MIN_CONVERSION_BATCH`. The existing dust final-sweep behavior remains
available, while normal treasury conversions cannot silently donate a batch.
