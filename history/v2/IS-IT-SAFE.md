# Is the Smart Router Safe?

## Short answer

**Keep `RESTRICT_TO_ADMIN` enabled for now.** The on-chain controls are strong:
the router derives Tinyman v2 pool addresses, authenticates other pool apps by
provider boundary, measures actual balance deltas, rejects group close/rekey
fields, and requires a quote-signer authorisation for every route.

No direct unrestricted-caller theft of a caller's trade was confirmed under the
following assumptions:

- the quote signer signs only quote authorisations;
- the configured Pact and STAMM creators are trusted and remain compatible;
- the deployed bytecode matches the reviewed source and template values; and
- the off-chain builder and release service provide the required signatures.

Those assumptions are material. The engine now signs the quote transaction and
the wallet bridge preserves it while signing only user indexes. The two-key
Testnet submission now passes; mobile-wallet runtime verification is still
required before unrestricted use.

## What was fixed in this review

- A zero `minimum_out` is accepted only when sweeping all accrued dust below
  `MIN_CONVERSION_BATCH`; a normal-sized final conversion must state a floor.
- A route's funding transaction must be immediately before its application
  call, preventing reuse of an unrelated group transaction.
- ASA input balances are checked after the first leg, including when the
  router was already opted into the input asset.
- The quote authorisation is required to be a `pool_budget()` call to this
  router, not merely any transaction from the quote-signer account.

## What remains

1. Verify the mixed-signature flow through Pera and Defly on testnet, including
   cancellation, delayed signing and expiry.
2. A human Algorand security review is required. Every audit in this chain,
   including this one, used AI assistance.
3. Phase 1 adversarial-pool coverage, Phase 2 bounded opcode fuzzing and Phase 4
   same-group conversion-approval protection are implemented.
4. Decide whether creator pinning is sufficient for each provider, or whether
   factory state, immutable program hashes, or continuous monitoring is needed.

The route path handles user funds and deserves the strictest standard. The
treasury path handles platform fees and has a different trust boundary; its
admin-only controls prevent strangers and mistakes, not a stolen admin key.
