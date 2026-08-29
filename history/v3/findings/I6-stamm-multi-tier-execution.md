# [INFORMATIONAL] I6: STAMM Multi-Tier Single-Call Execution Optimization

## Description
STAMM AMM pools support multi-tier deposit splits within a single application call. The router contract currently models each STAMM hop as a single tier (`STAMM_ONE_TIER_HEADER`). While splitting across multiple tiers in a single call could improve execution efficiency, it would alter the `Leg` struct and change the ABI method selector.

## Status
**Documented as Future Enhancement.**
