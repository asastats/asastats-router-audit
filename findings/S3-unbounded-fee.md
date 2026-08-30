# S3 — Nothing bounds the fee on a transaction the sweep asks a user to sign

- **Severity:** Medium (entire spendable ALGO balance; requires a hostile or
  misconfigured engine, but has a non-adversarial failure mode too)
- **Component:** off-chain — `dustsweep.js` `closeOutProblems`; also
  `contracts/router_app.py` `_assert_group_is_clean` on the conversion path
- **Origin:** this audit
- **Status:** **Partly fixed** — close-out path closed by `0be86c7` (widget)
  and `2aad22b` (planner). **The conversion path remains unbounded**; see §6.

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

## 6. As delivered, and what is still open

**Closed for close-outs.** `closeOutProblems` now refuses any transaction
whose fee exceeds `MAX_CLOSE_OUT_FEE`, and the widget shows *Network fees*
beside *You recover*, with `summary.recoverable` netted so it agrees with
`next_action`'s `recovers`.

The cap is written as `HOLDING_MINIMUM_BALANCE / 10` rather than as a multiple
of the 1,000 microALGO protocol minimum. Same number; different property. The
first draft followed recommendation 1 literally and added a whole-group rule —
"the fees exceed what this group recovers" — and that rule could never fire,
because `n` transactions capped at a tenth of the minimum balance can never
out-cost the `n` minimum balances they release. Expressing the cap as a
fraction of what a close-out returns makes the group rule unnecessary instead
of merely redundant, and a test asserts the relationship so that raising the
constant past the point where it holds fails loudly.

**Still open for conversions.** Recommendation 3 was not taken, and
`signAction` still inspects only the close-out path. A conversion group is
built by the engine, carries a router application call, and is signed by the
user — and neither the widget nor `_assert_group_is_clean` bounds its fees. The
same drain is therefore reachable through a conversion.

It is left open rather than closed badly because the two candidate fixes both
need judgement this finding cannot supply on its own:

- **A fourth assertion in `_assert_group_is_clean`** would cover the conversion
  path and every other router group at once, but it costs opcode budget in a
  subroutine whose own docstring records a five-way split being refused at
  1,877 — and it needs a contract deployment.
- **Inspecting the conversion group in the browser** duplicates for a group
  whose structure the widget deliberately does not model, since the contract
  is what validates it.

A conversion is also one holding rather than sixteen, and the router call
gives the contract a hook a close-out group does not have, so the shape is
better than the close-out case was. That is a reason to sequence it, not a
reason to leave it.
