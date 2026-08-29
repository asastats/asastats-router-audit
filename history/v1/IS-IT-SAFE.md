# Is the Smart Router Safe?

*A plain-English overview for non-auditors.*

## Short answer

**For a restricted deployment where only the admin can call `route`:** yes, the routing path is conservatively written and the mainnet deployment is intentionally restricted until this audit completes.

**For an unrestricted deployment:** not yet, but every issue the audit raised is now fixed or explicitly accepted. The fee-drain issue is patched; the floor a trade must clear is no longer chosen by the widget but signed by our backend, and the contract will not run a route without one; and the contract no longer calls whichever pool application a caller names.

What is left is not a flaw in the contract. This audit was done with AI assistance and has not been read by a human with Algorand experience. The changes have been tested on a local network and by simulation, but **no deployment on the real network carries the most recent ones yet**. Those two things, not a known weakness, are the reason the restriction stays on.

## What is at stake

Three pools of value, in decreasing order of importance:

1. **Each caller's trade, mid-route.** The contract holds the caller's entire input, then the intermediate, then the output. A routing-path flaw could steal one trade per group, repeatedly, from whoever is trading. This is the big one.
2. **The platform's accrued fees.** `convert_and_distribute` swaps accrued ALGO into ASASTATS. When this was permissionless with a caller-supplied pool, an attacker could route the ALGO to a malicious pool and take it. It is now admin-only, and the pool has to be approved in advance rather than named at the call.

   Worth being blunt about the limit: **nothing here protects the accrued fees from our own admin key.** That key can redirect where converted fees are paid and then convert honestly. The guards stop mistakes and strangers, not us. This is the platform's own money, so that is an acceptable place for the line — it would not be if this were a caller's trade.
3. **The application's float.** A small ALGO balance used to lend minimum balances. Draining it is an operational annoyance, not a user loss.

## What is already defended

- The contract refuses any group that rekeys or closes an account (`_assert_group_is_clean`).
- Tinyman v2 pool addresses are derived inside the contract, not supplied by the caller (the T5 fix).
- The contract measures what a leg actually paid by its own balance delta, not by anything a pool reports.
- Inner transactions carry zero fees, so fees cannot silently subtract from an ALGO-denominated leg.
- The platform fee is capped at 100 bps, so a stolen admin key cannot set a 100% fee.
- Opt-ins are tied to a route in the same group, so the float cannot be locked one junk asset at a time.

## What still needs fixing

1. ~~**`convert_and_distribute` must be admin-only.**~~ Patched in the source.
2. ~~**`minimum_received` is chosen by the widget.**~~ **Fixed.** The widget cannot choose it any more — the argument is gone from the contract entirely. The floor now travels in a transaction signed by our backend, so the network proves who set it before the contract reads it. A frontend that has been tampered with has nowhere to put a zero.
3. ~~**No quote deadline.**~~ **Fixed, and it needed no new setting.** Every routed group must now carry that backend-signed transaction, and Algorand already expires transactions after a window their sender chooses. The group cannot settle once it expires, so the quote's shelf life is enforced by the network.
4. ~~**Route paths are not sanitised.**~~ Patched: on-chain duplicate-asset checks.
5. ~~**The pool that accrued fees are sold through is whatever the caller names.**~~ **Fixed.** It is chosen in advance, in a transaction that spends nothing and can be checked afterwards, and the conversion carries no pool at all. What that prevents is converting the treasury's ALGO through a pool nobody reviewed — a mistyped identifier, or one that has since run dry.
6. ~~**A conversion could ask for nothing in return.**~~ **Fixed.** Every conversion has to say what it expects to receive.
7. ~~**Retiring an application could fail for an unexplained reason.**~~ **Fixed.** An Algorand account cannot be closed while it holds any asset, and the contract now says so plainly instead of letting the network reject the whole operation with nothing naming the cause.
8. ~~**The contract calls whichever pool application the caller names.**~~ **Fixed.** A leg may now only name a pool its own provider deployed. Pact and STAMM publish all their pools from one account each — we checked every one of them, 3,218 and 311 — so the contract asks the ledger who created the pool and refuses anything else. That covers every pool they will ever add, which a hand-kept list would not.

   AlgoFi is the exception, and is handled by an explicit list of pools, because those were deployed by many different people and there is nobody to trust. The list is the 23 AlgoFi pools that still hold meaningful money, out of 470 the router knows about — the rest are dust, and a trade through one of them is now refused rather than attempted. That is only safe because AlgoFi shut down: neither the pools nor the money in them is going to change.

What remains, honestly stated: the floor is now only as trustworthy as the one server that signs it. That is a real improvement — trust moved from every user's browser, which is easy to tamper with, to one machine we run and can watch — but it is not the same as trustless.

## When will it be safe to remove the admin restriction?

After:

- **this audit is reviewed by an Algorand-experienced human auditor** — not done, and it is the one item nothing in this repository can advance. Every audit here so far has been AI-produced, and a second AI audit does not change that.
- ~~the backend-signed floor is tested against real pools rather than only against LocalNet and simulation~~ — **done**. It executes for real on testnet, and on 2026-08-12 the admin submitted a real mainnet route: 0.20 USDC to HOG, confirmed in round 64005042, floor honoured and the 10 bps fee exact to the unit.
- ~~a deadline parameter is added~~ — no longer needed; the signed transaction's own expiry does this,
- ~~pool app IDs on the routing path are authenticated~~ — done,
- ~~formal or semi-formal multi-hop invariants are written down~~ — **done**, `docs/invariants.md`: 25 properties, each naming the assert that enforces it and the test that fails without it. Two remain unpinned and are listed there.
- a bug bounty and continuous monitoring program is in place — **neither exists.** The monitoring half is the cheaper and the more useful of the two; `audit/router-audit-v2/BRIEF.md` names the signals worth watching.

Removing the restriction before that is a deliberate risk.

Both of the things that had never been exercised outside LocalNet are now
done: the fee conversion runs end to end through a real Pact pool on testnet,
and one real mainnet route has been submitted and confirmed. What remains
unexercised on mainnet is the *conversion* — 2,522 microALGO now sits accrued,
below the batch floor, so clearing it would exercise the final-sweep path.
