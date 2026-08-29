# Tealer static analysis

Swept at revision `75087b8`, 4,681 TEAL lines. Raw output:
[tealer-sweep.txt](tealer-sweep.txt).

| detector | impact | result | reading |
|---|---|---|---|
| `unprotected-updatable` | HIGH | 9 paths | **false positive**, re-proven below |
| `unprotected-deletable` | HIGH | 9 paths | **true and deliberate** |
| `can-close-account` | HIGH | 0 | clean |
| `can-close-asset` | HIGH | 0 | clean |
| `group-size-check` | HIGH | not reportable | **vacuous** — see below |
| `constant-gtxn` | opt | 0 | clean |
| `self-access` | opt | 0 | clean |
| `sender-access` | opt | 0 | clean |
| `clear-is-updatable` | HIGH | 1 | noise — see below |
| `clear-missing-fee-check` | HIGH | 1 | noise |
| `clear-rekey-to` | HIGH | 1 | noise |
| `clear-group-size-check` | HIGH | 0 | clean |

## Re-proving the two HIGH results

Inherited verdicts are how an audit series goes wrong, so these were
re-established against this build rather than carried forward:

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
line 1955, inside `_assert_group_is_clean`, which is the check that *refuses* a
group attempting to rekey the caller. The contract sends no inner transaction
that rekeys anything.

## Why `group-size-check` reports nothing, and why that is not "clean"

Tealer's path walk does not terminate on this program within its hour timeout
and 8 GB limit. The sweep replaces the absent result with a static proof rather
than reporting a zero:

- 252 basic blocks
- **0** absolute group accesses
- **52** dynamic group accesses (`gtxns`, `gtxnsa`, `gtxnsas`)

Every group access is dynamic — indexed by `Txn.group_index + offset` — so the
detector's report predicate is false on every path. The zero is **vacuous, not
clean**, and the distinction matters: it means the detector never had an
opinion, rather than that it looked and approved.

What it would have checked is discharged by hand instead. Eight `GroupSize`
guard sites establish that each relative index is in `[0, GroupSize)`:

```
teal  548  router_app.py:975      teal 2015  router_app.py:819
teal 1588  router_app.py:1036     teal 2042  router_app.py:826
teal 1942  router_app.py:756      teal 2170  router_app.py:858
teal 2478  router_app.py:1012     teal 4190  router_app.py:1849
```

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
