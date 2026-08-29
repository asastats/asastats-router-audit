# Target-Network Exercise and Monitoring Plan

This plan resolves the remaining Recommendation 6 items:

- Exercise all supported providers and conversion on the target network.
- Monitor admin methods, accrual anomalies, float changes and provider leg
  counts.

## 1. Prerequisites

Before target-network execution:

- The deployment has passed `DEPLOYMENT-VERIFICATION.md`.
- The quote signer address matches the configured signer key.
- The engine returns a backend-signed quote authorization.
- The wallet bridge preserves pre-signed transactions.
- The test account is funded and has the required input/output holdings.
- The router application has enough ALGO for temporary minimum-balance loans.
- The approved conversion pool has sufficient liquidity and the escrow is
  opted into the fee asset.
- Strict simulation has `allow_unnamed_resources=False`.

Use a dedicated canary account and small amounts. Do not use ordinary user
funds for the first provider matrix.

## 1A. Offline Preparation From `data/amm`

The checked-in AMM data is enough to prepare most of the matrix before a target
network deployment. It is topology and pool-identity data, not a substitute for
live reserves or on-chain application state.

The current graph inventory contains approximately:

| Metric | Current data |
|---|---:|
| Pair keys | 25,002 |
| Assets | 10,987 |
| Tinyman v2 pool edges | 17,100 |
| Pact pool edges | 3,883 |
| STAMM collapsed pool edges | 68 |
| AlgoFi pool edges | 471 |

Tinyman v1 is also present in the files, but it is intentionally excluded from
the router application matrix because it cannot be used as an inner leg.

Prepare these offline artifacts now:

The generator is:

```bash
python scripts/prepare_target_matrix.py --network mainnet
```

It writes `provider-matrix.json`, `provider-matrix.csv`,
`conversion-candidates.json` and `monitoring-baseline.json` under
`router/build/target-network/`. Each artifact records the liquidity source,
generation time and input SHA-256 values. Regenerate immediately before target
network use; never treat an old artifact as current liquidity.

1. **Provider matrix.** Build a JSON/CSV matrix of direct pairs, two-hop
   intermediates and route3 paths from `PairGraph.from_entries(data/amm)`.
2. **Resource plan.** For each candidate, calculate expected foreign assets,
   applications, boxes, group slots and provider combinations using
   `route_references`, `estimated_references`, `route_fee` and
   `route_fee_units`.
3. **Deployment filter.** Mark each candidate as `supported`, `unsupported` or
   `requires target-network confirmation` based on the current provider pins,
   AlgoFi curated list, STAMM availability and eight-reference ceiling.
4. **Conversion candidates.** The current data identifies two Pact ALGO/
   ASASTATS pool applications: `1129173571` and `2757667443`. The latter is the
   current mainnet choice. The adjacent CSV token identifiers are `1129173576`
   and `2757667448`; those are not the pool application IDs passed to the
   router. Verify creator, state, reserves and output liquidity on chain before
   using either.
5. **Baseline metrics.** Record expected direct-pool counts, route candidate
   counts, provider distribution and route3 availability so monitoring can
   distinguish a data refresh from a provider outage.
6. **Test vectors.** Select small, medium and large input amounts for each
   candidate, plus an ALGO-intermediate route for fee accrual and a route3 case.

The offline artifacts should be generated from the data directory but must not
be treated as execution approval. The following still require algod/indexer:

- Current reserves and fees.
- Pool creator and update-authority verification.
- Pool existence and liquidity.
- STAMM box/resource availability.
- Quote output and signed-floor validity.
- Conversion output and escrow delivery.
- Actual provider inner-transaction behavior.

Recommended offline matrix priority:

- `ALGO/USDC`: broad direct/provider control case; 710 candidate intermediates
  exist in the topology.
- `ALGO/ASASTATS`: fee-asset and conversion-related case; 67 intermediates.
- `USDC/ASASTATS`: indirect-only and route-selection case; 60 intermediates.
- `USDC/HOG`: mixed provider and STAMM case; 170 intermediates.
- `ALGO/HOG`: STAMM and route3 resource case; 208 intermediates.

Do not run all topology combinations against the network. Rank them offline,
select a bounded representative matrix, then read fresh state only for the
selected candidates.

## 2. Provider Exercise Matrix

For each provider combination that the graph and resource ceiling support:

| Case | Required evidence |
|---|---|
| Tinyman v2 -> Tinyman v2 | Strict simulation and successful canary route |
| Tinyman v2 -> Pact | Strict simulation and successful canary route |
| Pact -> Tinyman v2 | Strict simulation and successful canary route |
| Pact -> Pact | Strict simulation and successful canary route |
| STAMM -> Tinyman v2 | Mainnet strict simulation; canary if selected by the graph |
| Tinyman v2 -> STAMM | Mainnet strict simulation; canary if selected by the graph |
| STAMM -> Pact | Mainnet strict simulation; canary if selected by the graph |
| Pact -> STAMM | Mainnet strict simulation; canary if selected by the graph |
| AlgoFi combinations | Only for currently approved curated pools; otherwise record N/A |
| Route3 supported shapes | Strict simulation for every shape within eight references |

The matrix is capability-based. If a provider has no live pool for a pair, mark
the case `N/A` with the reason and the pool/app IDs inspected. Do not turn a
missing venue into a passing test by substituting an unrelated pool.

For every executed case:

1. Obtain a fresh quote.
2. Build the group through the engine API.
3. Verify the backend quote signature.
4. Sign user transactions with the canary wallet.
5. Submit one atomic group.
6. Record transaction ID and confirmation round.
7. Verify returned output is at least the signed floor.
8. Verify the router has no unexpected asset holdings.
9. Verify the router ALGO balance changes only by the configured skim.
10. Verify the engine and contract provider leg counts agree.

For simulation-only cases, assert the same properties from the simulation
result and record that no state was committed.

## 3. Conversion Exercise

Conversion must be tested separately from routing.

### Accrual

1. Set the fee rate in an approved canary deployment.
2. Execute a route with an ALGO intermediate.
3. Read `accrued` before and after the route.
4. Confirm the increase matches the configured fee calculation.
5. Restore the intended fee rate in a finally/cleanup path.

### Normal conversion

1. Approve the conversion pool in its own group.
2. Read back the complete stored `Leg`.
3. Quote the conversion output.
4. Submit `convert_and_distribute` in a separate group with a non-zero floor.
5. Confirm output reaches only `platform_escrow`.
6. Confirm `accrued` decreases by exactly `batch`.
7. Confirm a temporary fee-asset holding is closed.

### Final sweep

1. Leave an accrued balance below `MIN_CONVERSION_BATCH`.
2. Submit a full final sweep with the permitted zero floor.
3. Confirm `accrued == 0`.
4. Confirm the application remains deletable once all holdings are empty.

### Negative cases

- Same-group pool approval plus conversion must reject.
- Zero floor on a normal-sized conversion must reject.
- A batch above `MAX_CONVERSION_BATCH` must reject.
- A batch above `accrued` must reject.
- A non-admin conversion must reject.
- A conversion through an unapproved or invalid provider leg must reject.

## 4. Monitoring Architecture

Use an indexer/algod polling worker with durable metric storage. The monitoring
worker must read application state and transaction groups independently of the
engine's quote cache.

Recommended collection interval:

- State and admin methods: every block or at most one minute.
- Provider leg counts and route outcomes: every five minutes.
- Benchmark/venue synchronization: every fifteen minutes.
- Daily release/artifact and deployment metadata check.

## 5. Admin-Method Alerts

Monitor application calls for these selectors:

- `set_admin`
- `set_escrow`
- `set_fee`
- `set_voucher_signer`
- `set_quote_signer`
- `set_conversion_pool`
- `close_holding`
- `convert_and_distribute`
- `delete_application`

Alert on every call, not only failed calls. These methods are intentionally rare
and therefore high-signal. The alert should include:

- Application ID and network.
- Transaction ID and confirmation round.
- Sender.
- Method selector and decoded arguments where safe.
- Previous and new relevant state values.
- Link to the explorer transaction.

`set_admin`, `set_escrow`, `set_quote_signer` and `set_conversion_pool` should
page an operator immediately. `set_fee` should page if the value changes
outside an approved maintenance window.

## 6. Accrual Anomaly Alerts

Record every `accrued` state transition and correlate it with the same-round
application group.

Alert when:

- `accrued` changes without a successful route or conversion group.
- `accrued` decreases by a value other than a submitted conversion batch.
- A route-induced increase exceeds the configured fee rate applied to the
  observed ALGO leg.
- `accrued` exceeds the operational batch ceiling or remains above the normal
  keeper interval for too long.
- A conversion succeeds but output does not reach the configured escrow.

Keep both the raw state-delta event and the correlated transaction ID so an
operator can distinguish an indexing delay from an actual anomaly.

## 7. Float and Holding Alerts

Track the router application account's:

- Total ALGO balance.
- Minimum balance.
- Spendable ALGO.
- Asset holding set and balances.

Alert when:

- Spendable ALGO drops without a matching temporary opt-in cycle or expected
  conversion.
- The balance falls below the minimum required for one supported route.
- An asset holding remains after a successful route or conversion.
- An asset holding appears without a route/conversion group that explains it.
- The router account is rekeyed or has unexpected close fields in any observed
  transaction.

The normal post-route state is no unexpected asset holdings and an ALGO balance
consistent with the configured skim/treasury state.

## 8. Provider Leg-Count Alerts

Count successful routed inner calls by provider and compare them with the
engine's available/selected venue data.

Track at least:

- Tinyman v2 successful legs.
- Pact successful legs.
- STAMM successful legs.
- AlgoFi successful legs where still approved.
- Route2 and route3 totals.
- Rejection counts by provider and error class.

Alert when:

- A provider's successful leg count falls to zero for three consecutive
  observation windows while the engine still advertises that provider.
- A provider's rejection rate exceeds a defined threshold, such as 20% over
  20 attempts.
- A provider's leg count drops sharply without a corresponding liquidity or
  graph change.
- STAMM or Pact routes begin failing with resource, creator or box-reference
  errors.
- The engine advertises a provider that the deployment's pinned template values
  can no longer authenticate.

The zero-leg alert is especially important for stale creator pins, provider
migrations and silently skipped venue-reader failures.

## 9. Operations and Escalation

Store monitoring events in a durable time-series or relational table with
retention long enough to compare daily and weekly baselines.

Recommended escalation:

1. Pause new unrestricted routing if the router float, accrual or provider
   authentication alert is unexplained.
2. Keep existing restricted/admin-only canary access available for diagnosis.
3. Do not rotate `quote_signer` or provider templates during an incident without
   recording the old and new values.
4. Preserve transaction IDs, manifests, state snapshots and logs.
5. Resume only after a fresh strict simulation and operator sign-off.

## 10. Acceptance Criteria

Recommendation 4 is complete when:

- Every supported provider matrix case is marked successful or explicitly N/A.
- Tinyman v2, Pact, STAMM and approved AlgoFi paths have target-network
  evidence where available.
- Normal conversion and final sweep have target-network transaction IDs.
- All negative conversion and signer cases reject atomically.

Recommendation 6 is complete when:

- Admin-method alerts are live and tested with a canary event.
- Accrual anomaly alerts correlate state changes to transaction groups.
- Float/holding alerts detect a synthetic or real test anomaly.
- Provider leg-count alerts detect a simulated zero-leg provider.
- On-call ownership and escalation are documented.
