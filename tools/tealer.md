# Tealer static analysis

Swept 2026-09-02 at revision `b3d733a`, **4,892 TEAL lines**. Raw output:
[tealer-sweep.txt](tealer-sweep.txt).

## The analysed program is the deployed program, for the first time

Worth putting above the table, because every previous sweep in this series
carried a caveat here and this one does not.

`scripts/tealer.sh` compiles with the mainnet template values and then
deliberately overrides one — `RESTRICT_TO_ADMIN = 0` — because the unrestricted
build is the superset: at `1`, `route` and `route3` refuse every caller but the
admin and most of the program is unreachable. Analysing the superset was the
right call and it meant **the swept program was never the running one**.

Since 2026-08-30 the deployment *is* the unrestricted build, so the override
changes nothing and the two coincide:

```
swept    build/tealer/Router.approval.teal   sha256 953988d9cdae686f…379f1684
manifest router-mainnet-3692588382.json      approval_teal_sha256 953988d9…1684
                                                                        match
```

`scripts/verify_deployment.py` against that manifest exits 0 — it recompiles
the source in a fresh puyapy subprocess and matches TEAL, bytecode, schema,
template values and the deployed application's own metadata. So the checkout,
the swept program and mainnet `3689591968` are the same artefact, and
`verify.sh` re-checks that hash on every run.

## Results

| detector | impact | result | reading |
|---|---|---|---|
| `unprotected-updatable` | HIGH | 9 paths | **false positive**, re-proven below |
| `unprotected-deletable` | HIGH | 9 paths | **true and deliberate** |
| `can-close-account` | HIGH | 0 | vacuous — see below |
| `can-close-asset` | HIGH | 0 | vacuous — see below |
| `group-size-check` | HIGH | not reportable | **vacuous** — see below |
| `is-updatable` | HIGH | covered report | false positive |
| `is-deletable` | HIGH | covered report | true and deliberate |
| `constant-gtxn` | opt | 0 | clean |
| `self-access` | opt | 0 | clean |
| `sender-access` | opt | 0 | clean |
| `clear-is-updatable` | HIGH | 1 | noise — see below |
| `clear-missing-fee-check` | HIGH | 1 | noise |
| `clear-rekey-to` | HIGH | 1 | noise |
| `clear-group-size-check` | HIGH | 0 | clean |

### Nothing moved, and that is the whole finding

The previous sweep ran at `75087b8` — the program deployed as `3688554446`,
4,681 lines. Since then the contract gained `set_paused`, the group fee bound
from [`S3`](../findings/S3-unbounded-fee.md), and group-hygiene guards on the
two new setters, and lost an input cap. 87 lines of TEAL, and every one of them
on the path a routed group takes.

Diffed detector for detector against that run:

| | |
|---|---|
| same verdict, same count, byte-identical log | 9 of 14 |
| same verdict, same count, **renumbered only** | 5 |

The five that changed changed by exactly what you would expect from inserting
blocks — `0 -> 1 -> 3 -> 4 -> 24 -> 25 -> 26` became
`0 -> 1 -> 3 -> 4 -> 26 -> 27 -> 28`, basic blocks 252 → 254, dynamic group
accesses 52 → 53 (the fee bound's own `gtxns Fee` read), and the eight
`GroupSize` guard sites moved down the file. **No detector changed its verdict
and none changed its count.**

That is the useful result. A new assertion inside `_assert_group_is_clean`,
which every routed group runs, added one dynamic group access and two basic
blocks and introduced no new reachable path of any kind that Tealer can see.

## Re-proving the two HIGH results

Inherited verdicts are how an audit series goes wrong, so these were
re-established against **this** build rather than carried forward:

```
grep -c UpdateApplication  Router.approval.teal   ->  0
grep -c DeleteApplication  Router.approval.teal   ->  3
grep -c "txn OnCompletion" Router.approval.teal   ->  2
grep -c RekeyTo            Router.approval.teal   ->  1
```

**`unprotected-updatable` is a false positive by construction.** The
`UpdateApplication` opcode does not appear anywhere in the program, so every
path Tealer reports as leading to an unprotected update leads to something that
cannot happen. The ARC-4 dispatcher has no update route.

**`unprotected-deletable` is real and intended.** The three `DeleteApplication`
hits are `delete_application`, an admin-gated bare method that retires the
application to release its float. It asserts `Txn.sender == self.admin`,
requires the accrued fee balance to be zero, and requires no asset holdings to
remain open. Deletable by its admin on purpose.

**The single `RekeyTo` is a read, not a set.** It is `gtxns RekeyTo` at TEAL
line **2029** (it was 1955 before the pause and the fee bound), inside
`_assert_group_is_clean` — the check that *refuses* a group attempting to rekey
the caller. The contract sends no inner transaction that rekeys anything, and
the seven live groups in [evidence/](../evidence/) carry no `rekey-to` on any
transaction at any nesting depth.

## Every zero here is vacuous, and that is not a quibble

`can-close-account` and `can-close-asset` are **stateless** detectors: their
predicate requires the evaluated transaction to be a `pay` or an `axfer`. An
approval program only ever evaluates an `appl`, so the predicate is false on
every path. A zero from them is the detector never having an opinion, not the
detector looking and approving.

The same is true of `rekey-to` and `missing-fee-check`, which are not run
against the approval program at all — see the memory note in
`scripts/tealer.sh`, where one of them reached 56.7 GB resident on a 64 GB
machine before it was killed. Both are stateless too, so nothing is lost.

## Why `group-size-check` reports nothing

Tealer's path walk does not terminate on this program within its hour timeout
and 8 GB limit. The sweep replaces the absent result with a static proof rather
than reporting a zero:

- 254 basic blocks
- **0** absolute group accesses
- **53** dynamic group accesses (`gtxns`, `gtxnsa`, `gtxnsas`)

Every group access is dynamic — indexed by `Txn.group_index + offset` — so the
detector's report predicate is false on every path. The zero is **vacuous, not
clean**.

What it would have checked is discharged by hand instead. Eight `GroupSize`
guard sites establish that each relative index is in `[0, GroupSize)`:

```
teal  591  router_app.py:1055     teal 2102  router_app.py:899
teal 1657  router_app.py:1116     teal 2129  router_app.py:906
teal 2011  router_app.py:833      teal 2257  router_app.py:938
teal 2565  router_app.py:1092     teal 4277  router_app.py:1929
```

`is-updatable` and `is-deletable` share that path walk and MemoryError under
the same limit, so both get covered reports too. Their per-block dataflow shows
the predicate genuinely fires — 248 of 254 blocks — so neither is vacuous; the
verdicts are the two above, reached from the program rather than the path set.

## The three `clear-*` results

The clear-state program is seven lines:

```
#pragma version 11
#pragma typetrack false

// algopy.arc4.ARC4Contract.clear_state_program() -> uint64:
main:
    pushint 1
    return
```

It approves unconditionally, which is the standard ARC-4 clear program and what
each of those three detectors reports on. There is no state to leak and nothing
to guard: clearing local state is a no-op for an application that stores none.

## What Tealer does not cover

It reasons about control flow and opcode usage. It has nothing to say about
whether the *right* accounts are checked, whether an economic invariant holds,
or whether the co-signed floor is a sensible number. Those are in
[REPORT.md](../REPORT.md), and the ones out of scope are listed there in §5.

**Not one detector returned a result that is evidence this contract is sound.**
Four fired: three false positives and one property that was chosen. The rest
returned zero, and every one of those zeros is an artefact of the detector not
applying. A clean Tealer sweep is worth exactly what this section says it is,
which is why the sweep is here and not in the verdict.
