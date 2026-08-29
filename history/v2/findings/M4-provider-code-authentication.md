# M4 — Creator pinning is not code authentication

**Severity:** Medium conditional trust risk
**Status:** Accepted conditionally

`AppParamsGet.app_creator` proves who created a Pact or STAMM application, not
which approval program currently runs or whether its state layout remains
compatible. AlgoFi's fixed list has the same upgrade-authority limitation.

This is not a public caller bypass under the current pins. It becomes relevant
if a pinned creator, factory or update authority is compromised or changes
behavior. Add factory/registry checks, immutable program hashes where
practical, or monitoring for approval and update-authority changes.
