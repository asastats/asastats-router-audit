# Attack-Vector Matrix

Verdicts use:

- **Defended:** an on-chain invariant or tested construction blocks the vector.
- **Patched:** the v2 worktree change closes it; deployment evidence is still
  required.
- **Accepted:** a stated trust or availability boundary remains.
- **Open:** additional engineering or review is required.
- **Not applicable:** the AVM or router design makes the vector inapplicable.

| Category | Vector | Verdict | Evidence |
|---|---|---|---|
| Access control | stranger calls admin methods | Defended | sender assertions and tests |
| Access control | unrestricted stranger routes | Defended conditionally | sender/input/payout checks; real unrestricted execution must be signed |
| Group hygiene | rekey or ALGO close | Defended | `_assert_group_is_clean` |
| Group hygiene | ASA close | Defended | `_assert_group_is_clean` |
| Quote binding | caller supplies zero floor | Defended | floor removed from route ABI |
| Quote binding | wrong caller/app/output/amount | Defended | `_signed_floor` comparisons |
| Quote binding | trimmed asserting route | Defended | named route index must remain |
| Quote binding | arbitrary signer transaction | Patched | final `pool_budget` call/type checks |
| Quote lifetime | stale authorisation | Defended conditionally | signer transaction validity window |
| Input accounting | funding transaction reuse | Patched | adjacency assertion |
| Input accounting | provider leaves ASA input | Patched | post-first-leg balance assertion |
| Output accounting | provider lies in log | Defended | own holding delta |
| Output accounting | residual intermediate | Defended | close and zero-balance assertions |
| Path validation | repeated asset/cycle | Defended | route and route3 assertions |
| Temporary holdings | junk ASA opt-in | Defended | opt-in must serve route and close |
| External apps | arbitrary Tinyman pool account | Defended | derived address |
| External apps | arbitrary Pact/STAMM app | Defended conditionally | creator pinning |
| External apps | arbitrary AlgoFi app | Defended conditionally | curated app list and manager pin |
| External apps | allowed creator deploys bad code | Accepted | provider trust boundary |
| Resources | missing foreign app/asset/box | Defended by builder | strict simulation evidence |
| Resources | group reference overflow | Defended by builder | reference counting and route limits |
| Opcode | pathological STAMM opups | Patched | contract and builder cap at 8; boundary fuzzed |
| Opcode | wide split scan exhaustion | Defended by measurements | v2 brief and split tests |
| Treasury | public fee conversion drain | Defended | admin-only and approved pool |
| Treasury | zero-floor normal conversion | Patched | dust-only final sweep |
| Treasury | same-group pool approval | Patched | conversion rejects setter in same group |
| Admin | stolen admin key | Accepted | expressly outside treasury guarantee |
| Atomicity | failed later leg after earlier move | Defended | Algorand atomic group plus zero-residual checks |
| Deployment | source/artifact mismatch | Open operational gate | hash and template verification required |
| Release | quote signer not supplied | Patched conditionally | engine signs; wallet runtime verification pending |
| Formal assurance | symbolic multi-hop proof | Open | KAVM not performed |
