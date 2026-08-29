# Audit Coverage

## Statistics (as of this snapshot)

| Metric | Count |
|--------|-------|
| Lines of router application analysed | ~1,900 |
| Public ARC-4 methods | 11 |
| Internal subroutines | ~25 |
| Global-state keys | 4 (`admin`, `platform_escrow`, `fee_bps`, `accrued`, `voucher_signer`) |
| Template variables | 7 (`TINYMAN_V2_APP_ID`, `STAMM_BUDGET_APP_ID`, `STAMM_OPUP_APP_ID`, `STAMM_OPUP_COUNT`, `FEE_ASSET_ID`, `MIN_CONVERSION_BATCH`, `RESTRICT_TO_ADMIN`) |
| Attack-vector categories | 10 |
| Findings drafted | 17 (C1, H1, M1–M6, L1–L5, I1–I6) |

## Coverage Areas

### Phase 1: Architecture & Threat Model

| Focus | Result |
|-------|--------|
| Trust boundaries | Documented in `IS-IT-SAFE.md` |
| Value at risk | Routing path > treasury path > float |
| Updatability | Admin-only; `RESTRICT_TO_ADMIN` compile-time flag |
| Residual T5 | Identified as the highest-value open item |

### Phase 2: Public Method Review

| Method | Risk Focus |
|--------|-----------|
| `route` / `route3` | Routing-path correctness, slippage, fee skim, reference limits |
| `opt_in_asset` | Float draining, handshake with route |
| `verify_discount` / `pool_budget` | Signature cost, group atomicity, replay |
| `set_admin` / `set_escrow` / `set_fee` / `set_voucher_signer` | Admin access controls, zero-address checks |
| `convert_and_distribute` | **Critical**: caller-supplied pool can drain accrued fees |
| `close_holding` / `delete_application` | Admin-only, holdings/accrued checks |

### Phase 3: Cross-Pool / Aggregator-Specific Vectors

| Vector | Status |
|--------|--------|
| Arbitrary pool app ID (Pact/STAMM/AlgoFi) | Open (bounded by group floor) |
| Malicious pool returns zero / wrong amount | Defended by balance-delta + `minimum_received` |
| Multi-hop slippage drift | Defended by global floor only |
| Route cycles / duplicate assets | **Patched** |
| Opcode budget exhaustion on wide routes | Mitigated by `pool_budget` and measured opups |
| MBR draining via opt-ins | Defended by route handshake |
| Fee-on-transfer / clawback assets | Documented, not explicitly handled |

### Phase 4: Off-Chain Builder Review

| Component | Coverage |
|-----------|----------|
| `router.contract.route_references` | Resource-array accounting reviewed |
| `router.contract.route_fee` | Fee-pooling logic reviewed |
| `router.legs.legs_for_quote` | Voucher deduplication, STAMM tier merging reviewed |
| `router.build.assemble` | Tinyman v1 leading, group-size limit reviewed |
| `router.quote.realised_outputs` | Telescoping shared-pool pricing reviewed |

## Known Gaps

- No formal KAVM specifications yet.
- No adversarial-pool fuzz harness yet.
- No differential test against Folks / Deflex yet.
- No on-chain signed-floor implementation yet (requires ABI change).
- No deadline parameter yet (requires ABI change).
