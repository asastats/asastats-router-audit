# S17 — The `data-router-app` override existed and did nothing

- **Severity:** Low (it fails closed, but it disables the escape hatch for a
  redeployment — and the router has now been redeployed three times)
- **Component:** off-chain — `dustsweep.js`, the interface state
- **Origin:** review of the dust sweep widget, 2026-09-02
- **Status:** **Fixed** — `4abb5a5` (widget)

---

## 1. What the override is for

`routedGroupProblems` requires a conversion group to call the router, and takes
the application id to require. `ROUTER_APP_ID` is a hardcoded fallback; the
page supplies `data-router-app` and that is meant to win. The constant's own
comment says why:

> The contract has been redeployed once already […] so this number has a
> lifetime. When it changes, a conversion refuses until this is updated, which
> is the safe direction but a real outage; the `data-router-app` override
> exists so a deployment can move first.

## 2. The defect

The override never reached the check. `start` built a state and assigned it:

```js
var current = state();
current.routerApp = root.dataset.routerApp;
```

and the open handler replaced that object before the modal was ever shown:

```js
current = state();               // seven keys, none of them routerApp
current.address = button.dataset.address;
```

So `sign` passed `undefined`, `Number(undefined) || ROUTER_APP_ID` fell back to
the constant, and **every conversion any reader has signed was checked against
the hardcoded id.**

## 3. What was lost

Nothing was weakened — the fallback is the same number the page renders. What
was lost is the ability to move. On the day the router is redeployed the
built-in id goes stale and every conversion is refused with *"the group calls
no router method that would check it"* until the widget is edited and shipped.
That is precisely the outage the attribute exists to prevent, and it happened
on 2026-09-02: the engine was restarted on `3692588382` while the widget still
required `3689591968`.

## 4. Where it was hiding

Entirely inside the block marked
`/* istanbul ignore next -- DOM wiring; the unit-tested core is above */`. That
is a fair description of most of that region. It was not a fair description of
a security-relevant value being assembled there.

## 5. The fix

`routerApp` is a parameter of `state`, so a call site that forgets it passes
`undefined` visibly rather than dropping a key from an object literal. Four
tests, one of which names a different application and requires a real mainnet
group to be refused for it — that one fails if the override goes inert again.
