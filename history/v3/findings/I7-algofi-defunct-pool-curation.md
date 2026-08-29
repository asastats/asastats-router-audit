# [INFORMATIONAL] I7: Defunct AlgoFi Protocol Curated Liquidity Whitelist

## Description
Because AlgoFi pools were permissionlessly deployed and the protocol is sunset, `_assert_listed` verifies pool IDs against a static compile-time whitelist (`ALGOFI_POOLS`) containing only liquid pools holding $\ge 100$ ALGO. This prevents calling unverified legacy contracts while preserving routing through liquid legacy pairs.

## Status
**Documented and Verified.**
