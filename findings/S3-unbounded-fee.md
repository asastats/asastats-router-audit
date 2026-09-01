# S3 — Nothing bounds the fee on a transaction the sweep asks a user to sign

- **Severity:** Medium (entire spendable ALGO balance; requires a hostile or
  misconfigured engine, but has a non-adversarial failure mode too)
- **Component:** off-chain — `dustsweep.js` `closeOutProblems`; also
  `contracts/router_app.py` `_assert_group_is_clean` on the conversion path
- **Origin:** this audit
- **Status:** **Fixed and deployed** — close-outs by `0be86c7` (widget) and
  `2aad22b` (planner); every routed group by the contract's own guard, live on
  mainnet `3689591968` since 2026-08-30. What a contract cannot reach is in §7.

---

## 1. The gap, derived

Parsing `closeOutProblems` for the fields it reads, and building an `axfer`
carrying everything one can carry, gives coverage rather than an impression
(`verification/verify-sweep.sh`, case 2):

```
inspected by closeOutProblems (7): aamt aclose arcv rekey snd type xaid
carried by an honest close-out (10): aclose arcv fee fv gen gh lv snd type xaid
possible on an axfer (15): aamt aclose arcv asnd fee fv gen gh lv lx note rekey snd type xaid

fields an axfer can carry that the whitelist never looks at: asnd fee fv gen gh lv lx note
```

`fee` is on every honest close-out and is inspected by nothing. The planner
assumes `CLOSE_OUT_FEE = 1_000` when it tells the user what they will recover,
but that constant is used only for arithmetic in the summary. The fee actually
signed comes from `algod.suggested_params()` at build time:

```python
built = close_out_group(algod.suggested_params(), address, action["holdings"])
```

Nothing downstream re-derives it, and the wallet bridge does not correct it.
`signAndSend` decodes each transaction, clears and reassigns `group`, and
leaves every other field — fee included — exactly as received.

## 2. What the chain would accept

Simulated against mainnet on a real account, unsigned with
`allow-empty-signatures`; nothing was submitted
(`verification/verify-sweep.sh`, case 3):

```
balance    : 31.688265 ALGO
min-balance:  3.419500 ALGO
spendable  : 28.268765 ALGO

--- the fee the planner assumes (0.001 ALGO) --- ACCEPTED
--- one hundred times that   (0.100 ALGO) ------ ACCEPTED
--- fee = entire spendable balance ------------- ACCEPTED
--- 3 close-outs splitting the spendable balance as fees --- ACCEPTED
```

**The only bound is the account's spendable balance.** A group of close-outs
whose fees total 28.27 ALGO is valid mainnet consensus, and a sweep group may
carry sixteen.

The 0.1 ALGO line is worth its own note, because it needs no hostility to hurt:
a close-out recovers exactly 0.1 ALGO of minimum balance, so **a fee of 0.1
ALGO makes a sweep net exactly zero** while the interface promises otherwise.

## 3. The user is never shown a fee

`summary()` computes `"fees": closes * CLOSE_OUT_FEE + conversions *
CONVERSION_FEE` and ships it to the browser. `summaryFigures` renders three
figures — *You recover*, *Signatures*, *Holdings* — and `recoverable` is
**gross**:

```python
"recoverable": (closes + conversions) * HOLDING_MINIMUM_BALANCE,
```

So the fee is computed, transmitted, and then dropped. There is no number
anywhere in the widget that would move if every fee in the group were a
thousand times larger. The only place a fee appears at all is the wallet's own
prompt, for a group of up to sixteen transactions, with nothing to compare it
against.

## 4. The conversion path has the same gap

`signAction` inspects only the close-out path, delegating conversions to the
contract on the grounds that it "carries a router call the contract itself
checks". That delegation holds for what the contract checks — and
`_assert_group_is_clean` walks every transaction in the group testing exactly
three things:

```python
assert transaction.rekey_to == Global.zero_address, "this group rekeys an account"
assert transaction.close_remainder_to == Global.zero_address, "this group closes an account"
assert transaction.asset_close_to == Global.zero_address, "this group closes a holding"
```

Fees are not among them. So neither sweep path bounds the fee, and on the
conversion path nothing inspects the group in the browser at all.

## 5. Recommended fix

1. **A rule in `closeOutProblems`.** It is the natural home: the whitelist is
   already the place that refuses transaction shapes, and a bound is one more
   line. Refuse any transaction whose `fee` exceeds a small multiple of the
   network minimum, and refuse a group whose fees exceed what it recovers —
   the second is the one that cannot be wrong, since a sweep that costs more
   than it returns has no purpose.

2. **Show the fee.** `summary.fees` already reaches the browser. Either render
   it beside *You recover*, or net it off — but not silently: `recovers` in
   `next_action` is already net of fees while `summary.recoverable` is gross,
   and the two should agree.

3. **Consider a fee bound in `_assert_group_is_clean`.** It already walks the
   group, so a fourth assertion costs almost nothing and would cover the
   conversion path and every other router group. Weigh against its opcode
   budget, which the docstrings show is already tight.

## 6. As delivered

**Close-outs.** `closeOutProblems` refuses any transaction whose fee exceeds
`MAX_CLOSE_OUT_FEE`, and the widget shows *Network fees* beside *You recover*,
with `summary.recoverable` netted so it agrees with `next_action`'s `recovers`.

The cap is written as `HOLDING_MINIMUM_BALANCE / 10` rather than as a multiple
of the 1,000 microALGO protocol minimum. Same number; different property. The
first draft followed recommendation 1 literally and added a whole-group rule —
"the fees exceed what this group recovers" — and that rule could never fire,
because `n` transactions capped at a tenth of the minimum balance can never
out-cost the `n` minimum balances they release. Expressing the cap as a
fraction of what a close-out returns makes the group rule unnecessary instead
of merely redundant, and a test asserts the relationship so that raising the
constant past the point where it holds fails loudly.

**Every routed group**, by recommendation 3: a fourth assertion in
`_assert_group_is_clean`, which now totals the fee across the group and refuses
a total above `MAX_GROUP_FEE`.

Totalled rather than checked per transaction, for two reasons. The total is
what a signer actually loses. And it is the bound that survives the builder
redistributing fees, which it already does — `router.build` sends the quote
authorisation with a zero fee and pools its minimum onto the route call that
carries the floor, so a per-transaction rule would have to be loose enough for
the dearest single call and would then permit sixteen of them.

### Sizing it

The ceiling is arithmetic, not judgement, because this contract is immutable
once deployed and a bound that refuses a legitimate route breaks every swap
through it. `router.contract.route_fee` returns `MINIMUM_TRANSACTION_FEE *
slots`; maximised over every one-, two- and three-leg combination of the four
providers, at `MAX_STAMM_OPUPS`, holding nothing:

```
worst legitimate route_fee: 44000 microALGO (0.044 ALGO)
  from legs: ('stamm', 'stamm', 'stamm')
```

A route call needs a funding transaction beside it, so at most seven fit in a
sixteen-transaction group: about 324,000 with the other transactions counted,
and 704,000 even on the absurd assumption that all sixteen carry a maximal
route fee. `MAX_GROUP_FEE` is 1,000,000.

That is deliberately loose, and the trade is stated rather than hidden: it
turns "as much as the signer has" — 28.27 ALGO on the account this audit
measured, and unbounded in general, since it scales with the victim's balance —
into a fixed ceiling that does not grow with what it protects. A tighter bound
is available to anyone who wants to do the arithmetic; `verify-sweep.sh`
recomputes the worst legitimate route on every run and fails if the ceiling
stops clearing it.

### The opcode budget, which was the reason to hesitate

`_assert_group_is_clean` already walks the group, so the addition is one
`+=` per transaction and one comparison at the end — cheaper than the
per-transaction alternative. Compiled: 4,681 -> 4,699 lines of TEAL — this
commit's own cost; the deployed program is 4,768 lines once `set_paused` and
the two setter guards are counted too.

`TestSplitWidthIsBoundedByTheGroupNotTheBudget` is the test whose docstring
warned that "another group scan on the route path would eat into it, and the
symptom would be a wide split failing on budget, which looks nothing like the
change that caused it" — the first `_signed_floor` was refused at 1,877 that
way. It executes five-way and four-way splits against LocalNet, and both still
pass. 111 LocalNet tests, 967 in the router suite.

## 7. What is deployed, and what cannot be

**The contract half is live since 2026-08-30.** Mainnet `3689591968` and
testnet `770729651` were compiled with `MAX_GROUP_FEE = 1_000_000`; the
manifest records it and `verify.sh` reads the manifest. `3688554446` and
`770123816`, which lacked it, are retired and destroyed. The paragraph that
stood here — *fixed in the repository and open in production* — is no longer
true of the conversion path.

Observed on four routed mainnet groups: the dearest paid 71,000 microALGO,
**7.1% of the ceiling**. The bound is loose by design and the traffic is
nowhere near it.

**The close-out path cannot be closed by the contract, and this is structural.**
A close-out group carries no application call, so `_assert_group_is_clean`
never runs over it. Simulated against mainnet after the deployment, on a
different account from the one in §2:

```
balance    : 39.255847 ALGO
min-balance: 23.573000 ALGO
spendable  : 15.682847 ALGO

--- fee = entire spendable balance ------------- ACCEPTED
```

Unchanged, and unchangeable from inside the contract. **The widget's
`MAX_CLOSE_OUT_FEE` is the only bound on that path**, which is why it is the
half that had to be right. Live, all 47 close-outs in
[evidence/](../evidence/) paid the 1,000 microALGO minimum against a cap of
10,000.

That simulation is also where this repository's own script was found to be
wrong. The account above is rekeyed, and the first version of the check did not
set `sgnr`, so simulate refused the group for **authorisation** and the check
recorded `refused` — indistinguishable from the fee bound working. See
[evidence/README.md §10](../evidence/README.md).
