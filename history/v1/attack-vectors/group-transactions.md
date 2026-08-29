# Group Transactions

| # | Vector | Verdict | Notes |
|---|--------|---------|-------|
| 1 | Attacker attaches rekey to caller's txns | Defended | `_assert_group_is_clean` rejects any rekey |
| 2 | Attacker attaches close-out to caller's ALGO | Defended | `_assert_group_is_clean` rejects any close |
| 3 | Attacker attaches asset close-out | Defended | `_assert_group_is_clean` rejects any asset close |
| 4 | Padding group with unrelated malicious txns | Accepted | The contract scans the whole group; unrelated txns are not trusted |
| 5 | Fee pooling covers attacker's outer txns | Defended | Only the route call carries a pooled fee; other txns pay their own fee |
| 6 | Duplicate opt-in transactions collide | Defended | `_route_note` distinguishes each route's opt-in |
| 7 | Tinyman v1 leg not at group start | Defended | `Leg.must_lead` enforced by `router.build.assemble` |
| 8 | Group size exceeds 16 | Defended | `router.build.assemble` raises `GroupTooLarge` |
| 9 | Reordering route calls to break `_group_paid` | Defended | Earlier calls log output; later call sums them |
