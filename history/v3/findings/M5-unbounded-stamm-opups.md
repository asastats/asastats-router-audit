# [MEDIUM] M5: Unbounded STAMM Opcode Requests & Non-STAMM OpUps

## Location
`contracts/router_app.py:_swap_leg`

## Description
STAMM swaps require additional opcode budget, requested via `leg.opups` to an inner budget application. If unconstrained, a caller could pass large opup counts, depleting ALGO fees, or pass non-zero opups on non-STAMM legs.

## Remediation
1. Non-STAMM legs assert `leg.opups.native == 0`.
2. STAMM legs enforce `leg.opups.native <= MAX_STAMM_OPUPS` (`MAX_STAMM_OPUPS = 8`).
3. Dead code in `_swap_leg` that previously retained an unreachable budget call for non-STAMM legs was removed in v3.

## Status
**Patched and Verified.**
