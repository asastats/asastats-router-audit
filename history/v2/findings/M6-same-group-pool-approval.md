# M6 — Conversion pool approval is not temporally separated

**Severity:** Low treasury operations
**Status:** Patched in the worktree

`set_conversion_pool` and `convert_and_distribute` are both admin-only, but a
single group could previously call the setter and then convert using the new
state. The pool was described as approved ahead of spending, but the contract
did not enforce that separation.

`convert_and_distribute` now scans the entire outer group and rejects any
`set_conversion_pool` call. A LocalNet test confirms that the attempted pool
approval and conversion both roll back. This protects against admin mistakes,
not a stolen admin key.
