# S5 — A malformed evaluation took the whole sweep down rather than degrading

- **Severity:** Informational (availability only — it moves no value)
- **Component:** off-chain — `router/sweep.py` both evaluation readers,
  `dustsweep.js` both group checks
- **Origin:** the property tests added after `S2`–`S4`, on their first run
- **Status:** **Fixed** — `cc9a4ff` (router), `d1365dc` (widget)

---

## 1. Why this is Informational and not Low

It gives nothing away. Every other finding in this series ends with a holding
reaching an address it should not; this one ends with a 500 and a sweep that
cannot run. It is recorded because it was found, because the fix is in the same
files as the others, and because *how* it was found is the point — not because
it is dangerous.

## 2. The defect

Four functions read a payload that arrives from somewhere else, and each
assumed its shape.

```python
for item in (evaluation or {}).get("asaitems") or ():   # priced_by_evaluation
    asset = (item.get("asset") or {}).get("id")          # values_by_evaluation
```

```js
(described || []).forEach(function (one) { ... });        // closeOutProblems
                                                          // forfeitTargetProblems
```

Each is correct for the type it expects and raises for everything else. A
payload that is not a mapping fails on `.get`; an `asaitems` that is not
iterable fails on the `for`; an `asset` that is not a mapping fails one level
deeper; and `(described || []).forEach` throws on any truthy non-array — a
string, a number, a bare object.

```
priced_by_evaluation(True)             -> AttributeError: 'bool' has no attribute 'get'
values_by_evaluation({'asaitems': 5})  -> TypeError: 'int' object is not iterable
closeOutProblems(group, address, " ")  -> TypeError: (described || []).forEach is not a function
```

`engine/core/sweep.py` calls the Python pair with no guard around them:

```python
priced = priced_by_evaluation(evaluation) if evaluated else set()
evaluated_values = values_by_evaluation(evaluation) if evaluated else {}
```

`evaluated` says only that the cache answered, not that the answer was
readable. So one malformed entry — a stale format, a partial write, anything
that still decodes as msgpack — was a 500 for the whole sweep.

**Which is the opposite of what this codebase does everywhere else.**
`_asset_facts` returns no creator for an asset it cannot read, on the stated
grounds that "one unreadable asset in three hundred should cost that asset, not
the sweep". `evaluation_for` carries an `except Exception  # degrade, never
refuse`. The two evaluation readers were written without either.

In the browser the asymmetry is sharper still: `closeOutProblems` already
guarded the *group* with `Array.isArray` and did not guard the *description*.

## 3. Why the example tests could not have found it

They were thorough about the wrong axis:

```python
@pytest.mark.parametrize(
    "payload",
    [None, {}, {"asaitems": None}, {"asaitems": [None]}, {"asaitems": [{}]}],
)
```

Five ways for a **dict** to be empty, and no way for the payload to be
something else. The JS suite covers `undefined` and `[]` — two ways for an
**array** to be missing. Every case anyone thought to write stayed inside the
type the author had in mind, which is what examples do.

A property test does not have that failure mode, because nobody chooses the
inputs:

```python
@given(payload=payloads)          # st.recursive over dicts, lists, scalars
def test_neither_reader_raises_on_anything(self, payload):
    assert isinstance(priced_by_evaluation(payload), set)
    assert isinstance(values_by_evaluation(payload), dict)
```

## 4. The fix

One place per language where shape tolerance lives, so the readers cannot
diverge again: `_evaluation_items` yields `(asset id, line)` pairs and drops
anything unreadable; `planLines` returns the plan lines that are objects.

An unreadable description now yields no expected close targets, so every
transaction fails the "was not listed" rule and the group is refused.
Degrading to a refusal is the safe direction, and matches the file it is in.
