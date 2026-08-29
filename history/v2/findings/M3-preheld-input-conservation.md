# M3 — Pre-held ASA input was not conserved

**Severity:** Medium
**Status:** Patched in the worktree

When the application was already opted into an input ASA, the route omitted
the temporary opt-in and therefore did not close the holding. The old cleanup
could not distinguish a provider that consumed the full transfer from one that
left input units in the application while returning enough output to pass the
floor.

The route now snapshots the ASA holding after funding and asserts that the
first leg reduces it by exactly the input amount. The Phase 1 LocalNet suite
deploys a test-only Router harness with a persistent input opt-in and confirms
that a malicious approved-creator pool leaving one input unit behind is
rejected atomically.
