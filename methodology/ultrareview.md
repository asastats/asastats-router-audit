# Putting `/code-review ultra` to work on this audit

`/code-review ultra` (the deprecated alias is `/ultrareview`) launches a deep
multi-agent review in the cloud. It is user-triggered and billed, so this is a
plan for spending it well rather than a list of things to try.

**The obstacle first, because it decides everything else.** `/code-review`
reviews a **diff** — the current branch, a PR, or a path target. This audit's
subject is 2,391 lines of contract that were written months ago and a planner
that has been stable for weeks. There is no diff. Point it at the router
checkout on `main` and it has nothing to read.

So the plan is in two halves: **what is already a diff** (run these first, they
need no setup and they are where the risk actually is), and **how to
manufacture a diff** for the parts that are not.

---

## Start here — one run, and what to ask it

If you do exactly one of these, do this one. The branch is already built:

```sh
cd frontend/website/widgets
git diff --stat dust-sweep...review/S2-forfeit-and-fee   # 2 files, +357 -7
git worktree add ../../../review-S2 review/S2-forfeit-and-fee
cd ../../../review-S2
claude
/code-review ultra dust-sweep      # NAME THE BASE. see below
```

**Naming the base is not optional here.** With no argument the command compares
against the repository's default branch, and `dust-sweep` is unmerged — so the
merge-base falls back to `c3f9eef` and the "review" becomes the whole feature
branch:

```
base main         22 files, 8,732 lines   REFUSED: over the 8,000-line limit
                  largest: inhouse/dustsweep/package-lock.json (5,022 lines)
base dust-sweep    2 files,   364 lines   the fix
```

That refusal is the cheap outcome. The expensive one is a base that is wrong
but *under* the limit, which buys a shallow read of eight thousand lines
instead of a deep one of three hundred, and looks like a review either way.

**So the rule for every target below: work out the base first, pass it
explicitly, and confirm the file list before approving.** `git diff --stat
<base>...<branch>` is the same check in one command, and it is the only thing
standing between you and paying for the wrong diff.

`0be86c7` is the browser control that decides **where a user's tokens go**. It
is 148 lines of production JavaScript and 216 of tests, off-chain — so anything
found is fixable without a redeploy — and it contains the two fail-closed
branches, which are the hardest thing in the estate to test and the easiest to
get backwards. A control that refuses when it should refuse and also refuses
when it should not is indistinguishable from a working one in every test that
exists.

Say what you want looked at, in the prompt, rather than letting it pick:

> This is the fix for two audit findings. `S2`: the forfeit destination used to
> be compared against `holdings[].creator` from the same HTTP response as the
> bytes being checked, so an engine that set both consistently could send a
> user's tokens anywhere; it now resolves the creator from the chain. `S3`: the
> fee on a close-out was inspected by nothing. Concentrate on the paths where
> the chain lookup fails or is unavailable — I want to know whether every one
> of them refuses, and whether any of them can be made to accept.

**Then stop and read what comes back before running a second one.** The point
of the first run is as much to calibrate what this reviewer is worth on this
codebase as it is to find something.

## Part 1 — what is already a diff, in priority order

### 1. The fixes this audit produced

The single highest-value target, and the reason is written down in
[SWEEP-REPORT §4](../SWEEP-REPORT.md):

> Every fix above was certified by example tests its own author wrote, in the
> same commits — the exact pattern `S1` came from, repeated four times in good
> faith.

Property tests were added to compensate, and found `S5` immediately. But a
property test still only checks what its author thought to state. **These seven
commits have never been read by anything that did not write them.** A
multi-agent review of exactly those diffs is the second opinion that was
missing, on the artefacts where its absence is documented.

| finding | repository | commit |
|---|---|---|
| `S1` | `router` | `1c128f2` Refuse to forfeit a holding the evaluation priced |
| `S1` | `engine` | `e13841f` Carry the evaluation's own prices into the sweep's forfeit veto |
| `S2` `S3` | `widgets` | `0be86c7` Confirm a forfeit against the chain, and bound the fee |
| `S2` | `frontend` | `199b9a0` Expose `assetCreator` on the swap bridge |
| `S4` | `router` | `2aad22b` Refuse a forfeit the two price sources disagree about |
| `S4` | `engine` | `9320ae2` Carry the evaluation's own value onto each holding |
| `S5` | `router` `widgets` | `cc9a4ff` / `d1365dc` Property tests, and the defect they found |

Each is a separate repository, so each is a separate run.

**Branching *at* the fix does not work, and this was wrong in the first draft
of this document.** Every one of those commits is already an ancestor of its
branch tip, so `git checkout -b review/S1 1c128f2` lands you *behind* HEAD:
the merge-base with the working branch is the fix itself, and the review sees
an empty diff. Checked, not assumed — `git merge-base --is-ancestor` says
ancestor for all seven.

What works is branching at the fix's **parent** and cherry-picking the fix onto
it. That makes a commit that is not reachable from the working branch, so the
merge-base is the parent and the three-dot diff is exactly the fix:

```sh
cd frontend/website/widgets
git worktree add -b review/S2 ../../../review-S2 0be86c7^   # branch at the parent
git -C ../../../review-S2 cherry-pick -x 0be86c7            # replay the fix on top
git diff --stat dust-sweep...review/S2                      # confirm before spending
cd ../../../review-S2 && claude
/code-review ultra dust-sweep                               # name the base
```

Two checks worth running every time, because each has already caught a mistake
that would otherwise have been paid for:

- **`git diff --stat <base>...<branch>`.** If it does not show the fix's own
  file list and line counts, the review will not either.
- **The base argument.** With none, the command uses the repository's default
  branch, which on an unmerged feature branch is not what you want. See the
  numbers under "Start here".

A worktree keeps the working branch checked out where it is, which matters when
the review is going to take a while.

Reviewing a branch built this way gives the reviewer the fix as the diff and the
whole repository around it as context, which is the shape it is built for.

**Ask specifically about the fail-closed branches.** `S2`'s chain comparison
and its "cannot read the asset" path are the two places where getting the
polarity backwards turns a control into a hole, and both are hard to test
because the failure is an absent refusal.

### 2. The deployment machinery

`scripts/deploy.py`, `scripts/verify_deployment.py` and the README's step
order. This is ordinary code doing an irreversible thing, and it has a
measured failure rate:

- `3688554446` was a redeploy that **should never have happened** — byte for
  byte the program it replaced. One command would have said so.
- The conversion pool was **set wrong first** on that deployment, because the
  README's example names Tinyman and mainnet uses Pact.
- Steps 4 and 5 of the README fail outright if run in the order the README
  gives them, and this had already been written down once before being walked
  into again.

Three procedure defects, all in code and prose that a reviewer can read, none
of which any of the six audits looked at because "deployment operations" is
out of scope in all of them. It is the highest ratio of real-cost to
attention in the estate.

```sh
cd router && git checkout -b review/deploy a6d7843~1
git checkout a6b9df6 -- scripts/ README.md docs/production-rollout.md
git commit -am "review target: the deployment procedure as it now stands"
/code-review ultra
```

### 3. This repository's own verifiers

`verify.sh`, `verify-sweep.sh` and `verify-groups.py` carry the entire weight
of the claim that this audit is different from the five before it. If a check
is wrong, the finding it certifies is worth nothing, and it will still print
`PASS`.

One already was. `verify-sweep.sh` simulated a close-out with an absurd fee
against a **rekeyed** account, was refused for authorisation rather than for
the fee, and reported `refused` — which is exactly what a working bound looks
like. It took running the script against a second account to notice. See
[evidence/README.md §10](../evidence/README.md).

That is a code-review finding, of a completely ordinary kind, in the file whose
correctness everything else depends on. There is no reason to think it is the
only one.

```sh
cd asastats-router-audit && git checkout -b review/verifiers && /code-review ultra
```

The whole repository is a small diff from its first commit, so this one can be
run against the branch as it stands.

### 4. Every future change to the contract

Standing rule rather than a one-off: **no commit touching
`contracts/router_app.py` gets deployed without an ultrareview of its diff.**
`3cb664e` (the pause and the input cap) and `848a3a3` (removing the input cap
again) are the model — a feature added and withdrawn within days because the
unit it was denominated in could not express what it was bounding. A reviewer
reading that diff cold would have asked what `50_000_000_000` means for USDC.

---

## Part 2 — manufacturing a diff for code that has one

For the contract and the sweep planner, the review target has to be built. Two
techniques, and the second is much better than the first.

### The naive form: an orphan branch

```sh
git checkout --orphan review/contract
git rm -r --cached . >/dev/null && git add contracts/router_app.py
git commit -m "review target: the contract as deployed"
```

Every line reads as an addition, so the whole file is reviewed. **The problem
is that nothing else is there** — no `router/contract.py` to show how a group
is assembled, no tests, no deployment manifest. A reviewer asking "is
`_signed_floor` reading the layout the builder writes?" cannot answer it, and
the interesting questions about this contract are all of that shape.

### The better form: empty the file, then restore it

```sh
git checkout -b review/contract
: > contracts/router_app.py && git commit -am "base: contract removed"
git checkout HEAD~1 -- contracts/router_app.py
git commit -am "review target: the contract as deployed at 3689591968"
/code-review ultra
```

The diff is the whole contract; the working tree is the whole repository. The
reviewer sees every line as new *and* has `router/contract.py`,
`router/deployments.py`, the manifest and 999 tests available to check it
against. Same coverage, none of the blindness.

Do it in slices rather than all at once. The contract is 2,391 lines and a
review that has to hold all of it will be shallower per line than four that do
not:

| slice | what it is | the question to put with it |
|---|---|---|
| the route path | `route`, `route3`, `_leg`, the per-provider legs | does every leg measure its own delta, and is the measurement what the next leg spends? |
| the guards | `_assert_group_is_clean`, `_assert_input_spent`, `_routed_in_group`, `_signed_floor` | which of these can be satisfied by a group the caller controls? |
| the treasury | `_skim`, `convert_and_distribute`, `set_*` | can any admin path move value without the admin's signature? |
| the sweep planner | `router/sweep.py`, `router/selection.py`, `engine/core/sweep.py` | which holdings can reach `FORFEIT`, and what is the largest value that can? |

The fourth slice is the one to run first if only one is run. It is the only
code in the product that gives a user's assets away, and it is off-chain, so a
finding there is fixable without a redeploy.

---

## What to do with what comes back

Three rules, all of which exist because of specific failures in this series.

**1. A finding is not closed until it is a command.** The reviewer's output is
prose, and prose is exactly what this repository was built to stop trusting.
Every accepted finding becomes a check in `verify.sh`, `verify-sweep.sh` or
`verify-groups.py`, asserting the *fixed* behaviour, before its file is written.
A finding whose check nobody can write was probably not understood.

**2. Do not use `--fix` on the contract.** `3689591968` is immutable and live.
A patch applied to `router_app.py` is a redeploy, a new application id, and
every integration in the estate moved onto it — which has already cost one
unnecessary deployment. `--fix` is fine on the verifiers, the widget and the
planner; on the contract, take the finding and decide separately.

**3. Distrust a finding that says something is fine.** This is the sixth AI
audit and the multi-agent reviewer is a seventh AI. The documented failure of
the series is not error in general, it is error **in one direction** — twice
recommending removal of the one control between an unaudited contract and the
public, both times from a false premise. A review that concludes the deployment
is safe has told you nothing you did not already have six of. A review that
names one thing and shows how to check it is worth all of them.

## Where it will and will not help

**Will:** the fix commits, the deployment scripts, the verifiers, the browser
control, the planner — ordinary code with ordinary bugs, which is what a code
reviewer is good at and what none of the six audits has read as code.

**Will not:** anything about the *running system*. Whether `RESTRICT_TO_ADMIN`
is set on mainnet, whether a pool is still on the whitelist, whether the fee
being charged is the fee that was configured — no reviewer of any depth can
answer those from a diff, and they are where two of the five prior audits went
wrong. Those are `verify-groups.py`'s job, and they stay there.
