#!/usr/bin/env python3
"""Every claim in evidence/README.md, as a command you can run.

The third verifier, and the first that checks the contract's behaviour rather
than its source. `verify.sh` reads `router_app.py` and `verify-sweep.sh` reads
the planner and the browser control; both answer "does the code say this?".
This one answers "did the chain do this?", against seven groups that executed
on mainnet on 2026-08-31 for a caller who is not the admin.

That distinction is the reason it exists. Five of the six audits in this series
reasoned entirely from source, and the two errors that mattered most - a
deployment described as unrestricted when it was restricted, and a restriction
recorded as removed when it was not - are both facts about a *running system*
that no amount of source reading would have settled.

Usage:
    python3 verify-groups.py                     # offline, 58 checks
    python3 verify-groups.py --strict            # exit 1 on the first failure

    ALGOD_URL=http://127.0.0.1:8085 ALGOD_TOKEN=... python3 verify-groups.py
        # adds the 4 checks that need a node, instead of reporting them SKIP

It reads only, submits nothing, and needs no key. The node, when given one, is
read for asset creators, application creators and whether an application still
exists - all public state.

The evidence is `evidence/groups/*.json`: the indexer's own response for every
transaction in each group, concatenated. Nothing in it was written by this
repository, and each transaction id can be pasted into any explorer.
"""

import base64
import hashlib
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
EVIDENCE = Path(os.environ.get("EVIDENCE", HERE.parent / "evidence"))
STRICT = "--strict" in sys.argv

# ---------------------------------------------------------------------------
# What the deployment said it was when these groups ran. Every one of these is
# a template value in router/build/releases/router-mainnet-3689591968.json,
# not a guess.
#
# **These pin the evidence and do not follow the deployment.** The transactions
# in evidence/ called 3689591968 and always will. That application has since
# been replaced by 3692588382 and destroyed - so ROUTER_APP is now a *retired*
# application, and any check that means "the live router" has to say so with
# LIVE_APP instead. Conflating the two is what made the `paused` check below
# fail on 2026-09-02: it read the evidence's application, found no global
# state because the application no longer exists, and reported that the live
# router lacks a key it has.
# ---------------------------------------------------------------------------
ROUTER_APP = 3689591968
#: the router this repository's reports describe as live, which is a different
#: question from which application the evidence called
LIVE_APP = 3692588382
RETIRED_APP = 3688554446
ROUTER_ADDRESS = "GV27MIISIGA7GV2EHG2TM5K423VRQKQXVBXLS7WNR2IAZ73AGTEEBPMUEU"
ADMIN = "ZRNRW3X4WMRJZLP2UZR5PECN4A23SW7QETVR4H53F6FFG3NHC6MVSLMQPM"
QUOTE_SIGNER = "STATS7ESG7NPA2MP2XVEHBQ2HKJXOCRCA6TS7H5YIN7IE2QCTTY6GXORJY"
CALLER = "VW55KZ3NF4GDOWI7IPWLGZDFWNXWKSRD5PETRLDABZVU5XPKRJJRK3CBSU"

TINYMAN_V2_APP_ID = 1002541853
STAMM_BUDGET_APP_ID = 3544641082
STAMM_OPUP_APP_ID = 3544641019
FEE_ASSET_ID = 393537671
PACT_POOL_CREATORS = [
    "E5QGPA7LWVAVUADJFSZ6TLKRT6LYINNNQGQFVCPNTBHJM7I2HRYGSJBEMM",
    "PACTFIIFTBWHD52WFMKTSCDZWFVWZK4ZDSWIZHMROZLYD5PZFA4TLCWP7I",
    "H2XDAFUDTEPTN24HNUAZI6RCKQ2KDIIO45U767FEHGSGSEGCWWOK4QEIXM",
]
STAMM_POOL_CREATORS = ["46FAE637CNJDBR72VDXWIPDWKF7TATTAPPKRQDYM5RIQ4A2PHBFAOY6KJQ"]
ALGOFI_POOLS = set()

# Contract constants, from contracts/router_app.py.
MAX_FEE_BPS = 100
MAX_GROUP_FEE = 1_000_000
MAX_STAMM_OPUPS = 8
BASIS_POINTS = 10_000
FEE_BPS = 5  # set_fee, mainnet, 2026-08-30

# Sweep constants, from the widget and router/sweep.py.
HOLDING_MINIMUM_BALANCE = 100_000
MAX_CLOSE_OUT_FEE = HOLDING_MINIMUM_BALANCE // 10
MAX_GROUP_SIZE = 16

# The note layout `Router._signed_floor` reads, from router/contract.py.
QUOTE_NOTE_HEADER = 64
QUOTE_ENTRY_LENGTH = 8
QUOTE_NOTE_LENGTH = QUOTE_NOTE_HEADER + QUOTE_ENTRY_LENGTH * MAX_GROUP_SIZE

GROUPS = [
    ("swap.json", "a four-way split swap, USDC to ASASTATS"),
    ("sweep-1-closeout.json", "sweep 1 - sixteen empty holdings closed"),
    ("sweep-2-closeout.json", "sweep 2 - sixteen empty holdings closed"),
    ("sweep-3-convert.json", "sweep 3 - four routes converting one asset"),
    ("sweep-4-convert.json", "sweep 4 - three routes, none touching ALGO"),
    ("sweep-5-forfeit.json", "sweep 5 - nine close-outs and six forfeits"),
    ("sweep-6-convert.json", "sweep 6 - a direct pool leg beside three routes"),
]

PASS = FAIL = SKIP = 0


def encode_address(key):
    checksum = hashlib.new("sha512_256", key).digest()[-4:]
    return base64.b32encode(key + checksum).decode().rstrip("=")


def check(label, want, got):
    global PASS, FAIL
    if want == got:
        print(f"  PASS  {label:<58} {got}")
        PASS += 1
    else:
        print(f"  FAIL  {label:<58} want={want} got={got}")
        FAIL += 1
        if STRICT:
            sys.exit(1)


def skip(label, why):
    global SKIP
    print(f"  SKIP  {label:<58} {why}")
    SKIP += 1


def section(title):
    print()
    print(title)
    print("-" * 73)


def load(path):
    """Read one file of concatenated indexer transaction responses."""
    text = path.read_text()
    decoder, index, out = json.JSONDecoder(), 0, []
    while index < len(text):
        while index < len(text) and text[index] in " \n\r\t":
            index += 1
        if index >= len(text):
            break
        obj, index = decoder.raw_decode(text, index)
        out.append(obj["transaction"])
    # `intra-round-offset` counts inner transactions too, so sorting by it and
    # dropping the gaps reproduces the group's own order exactly.
    return sorted(out, key=lambda t: t["intra-round-offset"])


def walk(txn):
    """Yield a transaction and every inner transaction beneath it."""
    yield txn
    for inner in txn.get("inner-txns", []):
        yield from walk(inner)


def inners(txn):
    """Yield only the inner transactions beneath one top-level transaction."""
    for inner in txn.get("inner-txns", []):
        yield from walk(inner)


def app_id(txn):
    return (txn.get("application-transaction") or {}).get("application-id")


def note_of(txn):
    return base64.b64decode(txn["note"]) if txn.get("note") else None


def read_floor(note):
    """Decode a quote note into what `Router._signed_floor` reads from it."""
    u = lambda a, b: int.from_bytes(note[a:b], "big")
    return {
        "app": u(0, 8),
        "caller": encode_address(note[8:40]),
        "asset_out": u(40, 48),
        "minimum_received": u(48, 56),
        "asserting": u(56, 64),
        "inputs": {
            i: int.from_bytes(
                note[QUOTE_NOTE_HEADER + i * 8 : QUOTE_NOTE_HEADER + i * 8 + 8], "big"
            )
            for i in range(MAX_GROUP_SIZE)
            if int.from_bytes(
                note[QUOTE_NOTE_HEADER + i * 8 : QUOTE_NOTE_HEADER + i * 8 + 8], "big"
            )
        },
    }


def paid_out(group, asset):
    """What the router's inner transactions paid the caller, in `asset`.

    Asset 0 is ALGO, which is not an ASA: the router pays it with a `pay`
    inner, so reading only `axfer` would return 0 for an ALGO-terminating
    route and report a floor breach that did not happen. Every group in this
    evidence settles in USDC, so this arm is latent - but the fee loop below
    already reads `pay` inners, and the asymmetry is the kind of thing this
    script exists to not have.
    """
    total = 0
    for txn in group:
        for inner in inners(txn):
            if asset == 0:
                if inner["tx-type"] != "pay":
                    continue
                payment = inner["payment-transaction"]
                if inner["sender"] == ROUTER_ADDRESS and payment["receiver"] == CALLER:
                    total += payment["amount"]
                continue
            if inner["tx-type"] != "axfer":
                continue
            transfer = inner["asset-transfer-transaction"]
            if (
                inner["sender"] == ROUTER_ADDRESS
                and transfer["receiver"] == CALLER
                and transfer["asset-id"] == asset
            ):
                total += transfer["amount"]
    return total


# ---------------------------------------------------------------------------
# The node, when there is one.
# ---------------------------------------------------------------------------
ALGOD_URL = os.environ.get("ALGOD_URL", "").rstrip("/")
ALGOD_TOKEN = os.environ.get("ALGOD_TOKEN", "")
_cache = {}


def node(path):
    """GET one algod path, or None if there is no node or it refuses."""
    if not ALGOD_URL:
        return None
    if path in _cache:
        return _cache[path]
    request = urllib.request.Request(
        f"{ALGOD_URL}{path}", headers={"X-Algo-API-Token": ALGOD_TOKEN}
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            _cache[path] = json.load(response)
    except urllib.error.HTTPError as error:
        _cache[path] = {"__status__": error.code}
    except Exception:
        _cache[path] = None
    return _cache[path]


def asset_creator(asset):
    got = node(f"/v2/assets/{asset}")
    return (got or {}).get("params", {}).get("creator")


def application_creator(application):
    got = node(f"/v2/applications/{application}")
    return (got or {}).get("params", {}).get("creator")


# ---------------------------------------------------------------------------

groups = {}
for name, _ in GROUPS:
    path = EVIDENCE / "groups" / name
    if not path.is_file():
        print(f"evidence not found: {path}")
        print("set EVIDENCE=/path/to/evidence and re-run")
        sys.exit(2)
    groups[name] = load(path)

account = json.loads((EVIDENCE / "account.json").read_text())

print(f"evidence: {EVIDENCE}")
print(f"groups:   {len(groups)}")
print(f"node:     {ALGOD_URL or 'none - the chain checks will report SKIP'}")
print()

# ===========================================================================
section("the deployment these groups ran against")

check(
    "the applications these groups call at top level",
    [TINYMAN_V2_APP_ID, ROUTER_APP],
    sorted({app_id(t) for g in groups.values() for t in g if app_id(t)}),
)
check(
    "so every router call names 3689591968, not the retired 3688554446",
    True,
    RETIRED_APP not in {app_id(t) for g in groups.values() for t in g if app_id(t)},
)
check(
    "the caller is not the admin, so RESTRICT_TO_ADMIN is off",
    True,
    CALLER != ADMIN
    and all(
        t["sender"] in (CALLER, QUOTE_SIGNER) for g in groups.values() for t in g
    ),
)
check(
    "the caller's account is rekeyed, which the group does not disturb",
    account["auth-addr"],
    next(t["auth-addr"] for t in groups["swap.json"] if t.get("auth-addr")),
)
if ALGOD_URL:
    retired = node(f"/v2/applications/{RETIRED_APP}")
    check(
        "the retired application really is gone",
        404,
        (retired or {}).get("__status__"),
    )
    live = node(f"/v2/applications/{LIVE_APP}")
    keys = {
        base64.b64decode(kv["key"]).decode("utf8", "replace")
        for kv in (live or {}).get("params", {}).get("global-state", [])
    }
    check("and the live one carries the `paused` key set_paused added", True, "paused" in keys)
    check(
        "the application the evidence called is retired too",
        404,
        (node(f"/v2/applications/{ROUTER_APP}") or {}).get("__status__"),
    )

    # Which of the contract's two signing keys are actually set. A reader of
    # the threat model would otherwise assume both are live; one is not, and
    # that changes what a stolen key is worth. Read rather than described.
    signers = {
        base64.b64decode(kv["key"]).decode("utf8", "replace"): base64.b64decode(
            kv["value"].get("bytes", "")
        )
        for kv in (live or {}).get("params", {}).get("global-state", [])
        if kv["value"].get("type") == 1
    }
    check(
        "the quote signer is set, because every route depends on it",
        True,
        signers.get("quote_signer", b"") not in (b"", bytes(32)),
    )
    # Set on 2026-09-03. It was zero for this contract's whole life before
    # that, and the check asserting so is what said this had changed - within a
    # day of the paragraph claiming it. Pinned in the direction the report now
    # states, so the next change is caught the same way.
    check(
        "the voucher signer is set too, since 2026-09-03",
        True,
        signers.get("voucher_signer", bytes(32)) not in (b"", bytes(32)),
    )
else:
    skip("the retired application really is gone", "no ALGOD_URL")
    skip("and the live one carries the `paused` key set_paused added", "no ALGOD_URL")
    skip("the application the evidence called is retired too", "no ALGOD_URL")
    skip("the quote signer is set, because every route depends on it", "no ALGOD_URL")
    skip("the voucher signer is set too, since 2026-09-03", "no ALGOD_URL")

# ===========================================================================
section("H1 - the floor is co-signed, and it bound")

routed = [n for n, g in groups.items() if any(app_id(t) == ROUTER_APP for t in g)]
check("groups carrying a router call", 4, len(routed))

for name in routed:
    group = groups[name]
    quotes = [
        t
        for t in group
        if t["sender"] == QUOTE_SIGNER
        and note_of(t)
        and len(note_of(t)) == QUOTE_NOTE_LENGTH
    ]
    check(f"{name}: exactly one co-signed floor", 1, len(quotes))
    if len(quotes) != 1:
        continue
    floor = read_floor(note_of(quotes[0]))
    check(f"{name}: the note names this application and this caller", True,
          floor["app"] == ROUTER_APP and floor["caller"] == CALLER)
    check(f"{name}: the quote signer pays no fee of its own", 0, quotes[0]["fee"])
    received = paid_out(group, floor["asset_out"])
    check(f"{name}: received >= the signed floor", True, received >= floor["minimum_received"])
    print(
        f"        floor {floor['minimum_received']:>14,}   "
        f"received {received:>14,}   "
        f"+{(received / floor['minimum_received'] - 1) * 100:.3f}%"
    )
    # M2, on chain: the note names a group index per route call, and the
    # funding transfer for that call must sit immediately before it.
    #
    # The count is checked first because `all()` over an empty table is True:
    # if the note's offsets ever drift, `inputs` comes back empty and the
    # claim below would pass having examined nothing.
    check(f"{name}: the note names at least one funded input", True,
          len(floor["inputs"]) >= 1)
    adjacent = all(
        # index 0 has nothing before it to be funded by; without this,
        # `group[index - 1]` is `group[-1]` and silently reads the last
        # transaction in the group.
        index >= 1
        and group[index]["tx-type"] == "appl"
        and app_id(group[index]) == ROUTER_APP
        and group[index - 1]["tx-type"] == "axfer"
        and group[index - 1]["asset-transfer-transaction"]["amount"] == amount
        and group[index - 1]["asset-transfer-transaction"]["receiver"] == ROUTER_ADDRESS
        for index, amount in floor["inputs"].items()
    )
    check(f"{name}: every named input is funded by the transaction before it", True, adjacent)
    # The asserting index must be the last router call: only it sees the whole
    # group's output, so naming any earlier one would let the rest be trimmed.
    calls = [i for i, t in enumerate(group) if app_id(t) == ROUTER_APP
             and len(t["application-transaction"].get("application-args") or []) >= 6]
    check(f"{name}: the asserting index is the last route call", calls[-1], floor["asserting"])

# ===========================================================================
section("the four properties REPORT section 2 rests on")

everything = [t for g in groups.values() for t in g]
all_inner = [i for t in everything for i in inners(t)]

check("inner transactions sent by the contract", 183, len(all_inner))
check("every one of them pays a zero fee", True, all(i["fee"] == 0 for i in all_inner))

# Inventory is transient: every holding the router opened in a group was closed
# in the same group. An opt-in shows up as a zero-amount self transfer; a
# close-out as an inner transfer carrying `close-to`.
transient = True
for name, group in groups.items():
    opened, closed = set(), set()
    for txn in group:
        for inner in inners(txn):
            if inner["tx-type"] != "axfer" or inner["sender"] != ROUTER_ADDRESS:
                continue
            transfer = inner["asset-transfer-transaction"]
            if transfer["receiver"] == ROUTER_ADDRESS and transfer["amount"] == 0:
                opened.add(transfer["asset-id"])
            if transfer.get("close-to"):
                closed.add(transfer["asset-id"])
    if opened - closed:
        transient = False
        print(f"        {name}: left open {sorted(opened - closed)}")
check("every holding the router opened, it closed in the same group", True, transient)

# ===========================================================================
section("group hygiene - _assert_group_is_clean, on chain")

every = [txn for top in everything for txn in walk(top)]


def rekeys(txn):
    return bool(txn.get("rekey-to"))


def closes_algo(txn):
    return bool((txn.get("payment-transaction") or {}).get("close-remainder-to"))


# Neither `rekey-to` nor `close-remainder-to` occurs anywhere in this evidence,
# so both claims below are true of a corpus that never exercises them: they
# would read the same if the predicates could not detect a rekey at all. The
# two controls make the detectors demonstrate themselves on a transaction built
# to trip them, so a passing claim means "looked, and found none".
check("the rekey detector fires on a transaction that rekeys", True,
      rekeys({"rekey-to": ADMIN}) and not rekeys({}))
check("the ALGO-close detector fires on a transaction that closes", True,
      closes_algo({"payment-transaction": {"close-remainder-to": ADMIN}})
      and not closes_algo({"payment-transaction": {}})
      and not closes_algo({}))
check("transactions examined for both", 183 + len(everything), len(every))
check(
    "no transaction in any group rekeys an account",
    True,
    all(not rekeys(txn) for txn in every),
)
check(
    "no transaction in any group closes an ALGO balance",
    True,
    all(not closes_algo(txn) for txn in every),
)
# `asset_close_to` is the interesting one: the guard refuses it on every
# transaction of a routed group, so the only closes in this evidence must be
# the router's own inner transfers, or top-level transfers in a sweep group
# that carries no router call at all.
stray = []
for name, group in groups.items():
    has_router = any(app_id(t) == ROUTER_APP for t in group)
    for top in group:
        for txn in walk(top):
            if txn["tx-type"] != "axfer":
                continue
            if not txn["asset-transfer-transaction"].get("close-to"):
                continue
            inner = txn is not top
            if has_router and not inner:
                stray.append((name, txn["id"]))
check("a close-out never rides in the same group as a route", [], stray)

# ===========================================================================
section("M4 - every pool the contract called is one it authenticates")

called = sorted(
    {
        app_id(i)
        for t in everything
        for i in inners(t)
        if i["tx-type"] == "appl" and app_id(i)
    }
)
check("distinct pool applications called", 9, len(called))
if ALGOD_URL:
    unauthenticated = []
    for application in called:
        if application in (TINYMAN_V2_APP_ID, STAMM_BUDGET_APP_ID, STAMM_OPUP_APP_ID):
            continue  # pinned by template application id
        if application in ALGOFI_POOLS:
            continue
        creator = application_creator(application)
        if creator not in PACT_POOL_CREATORS + STAMM_POOL_CREATORS:
            unauthenticated.append((application, creator))
    check("each is pinned by app id or by its creator on chain", [], unauthenticated)
else:
    skip("each is pinned by app id or by its creator on chain", "no ALGOD_URL")

# ===========================================================================
section("M5 - the STAMM opcode budget is bounded")

budget_calls = [
    i
    for t in everything
    for i in t.get("inner-txns", [])
    if app_id(i) == STAMM_BUDGET_APP_ID
]
check("STAMM budget calls in this evidence", 2, len(budget_calls))
check(
    f"none issues more than MAX_STAMM_OPUPS ({MAX_STAMM_OPUPS})",
    True,
    all(len(c.get("inner-txns", [])) <= MAX_STAMM_OPUPS for c in budget_calls),
)
check(
    "and every one of those is an opup call, not something else",
    True,
    all(
        app_id(o) == STAMM_OPUP_APP_ID
        for c in budget_calls
        for o in c.get("inner-txns", [])
    ),
)

# ===========================================================================
section("S3 - the fee, now that the contract half is deployed")

worst = max(sum(t["fee"] for t in g) for g in groups.values())
check(f"the dearest group's total fee is under MAX_GROUP_FEE ({MAX_GROUP_FEE:,})",
      True, worst <= MAX_GROUP_FEE)
print(f"        dearest group {worst:,} microALGO, {worst / MAX_GROUP_FEE * 100:.1f}% of the ceiling")

close_outs = [
    t
    for g in groups.values()
    for t in g
    if t["tx-type"] == "axfer"
    and t["sender"] == CALLER
    and t["asset-transfer-transaction"].get("close-to")
]
check(f"every close-out's fee is at or under MAX_CLOSE_OUT_FEE ({MAX_CLOSE_OUT_FEE:,})",
      True, all(t["fee"] <= MAX_CLOSE_OUT_FEE for t in close_outs))
check("no group exceeds the sixteen-transaction limit", True,
      all(len(g) <= MAX_GROUP_SIZE for g in groups.values()))

# ===========================================================================
section("the fee schedule, recomputed from the state deltas")

# `_skim` is only ever called on ALGO, so a route with no ALGO leg accrues
# nothing. Both cases occur here, and both are checked.
accrued, mismatched, algoless, rates = 0, [], 0, []
for name, _ in GROUPS:
    for txn in groups[name]:
        if app_id(txn) != ROUTER_APP:
            continue
        deltas = {
            base64.b64decode(d["key"]).decode("utf8", "replace"): d["value"].get("uint", 0)
            for d in (txn.get("global-state-delta") or [])
        }
        algo_legs = [
            i
            for i in inners(txn)
            if i["tx-type"] == "pay" and i["sender"] == ROUTER_ADDRESS
        ]
        if "accrued" not in deltas:
            if algo_legs:
                mismatched.append((name, txn["id"], "ALGO leg but no fee"))
            elif any(
                i["tx-type"] == "axfer" and i["sender"] == ROUTER_ADDRESS
                and i["asset-transfer-transaction"]["amount"]
                for i in inners(txn)
            ):
                algoless += 1
            continue
        taken = deltas["accrued"] - accrued
        accrued = deltas["accrued"]
        if not algo_legs:
            mismatched.append((name, txn["id"], "fee taken with no ALGO leg"))
            continue
        # The skim happens between the pool paying the contract and the
        # contract paying the next leg, so the gross is the inner payment the
        # contract *received* and the net is the one it sent.
        received = max(
            i["payment-transaction"]["amount"]
            for i in inners(txn)
            if i["tx-type"] == "pay" and i["payment-transaction"]["receiver"] == ROUTER_ADDRESS
        )
        want = received * FEE_BPS // BASIS_POINTS
        if want != taken:
            mismatched.append((name, txn["id"], f"want {want} took {taken}"))
        rates.append(taken * BASIS_POINTS / received)

check(f"every fee taken is exactly floor(ALGO leg x {FEE_BPS} / {BASIS_POINTS})", [], mismatched)
check("routes with no ALGO leg accrued nothing, as _skim's docstring says",
      True, algoless >= 1)
print(f"        {algoless} route call(s) never touched ALGO and paid no platform fee")
print(f"        accrued across the whole session: {accrued:,} microALGO")
network = sum(sum(t["fee"] for t in g) for g in groups.values())
print(f"        network fees over the same session: {network:,} microALGO "
      f"({network / accrued:.0f}x the platform's cut)")
# Measured from the deltas, not asserted between two constants. This read
# `FEE_BPS <= MAX_FEE_BPS` - 5 <= 100, both declared at the top of this file -
# which is a statement about the source of this script, not about what the
# deployment charged, and could not fail.
check("route calls that took a fee, so there is a rate to check", True, len(rates) >= 1)
check(
    f"the rate actually charged never exceeded MAX_FEE_BPS ({MAX_FEE_BPS})",
    True,
    bool(rates) and max(rates) <= MAX_FEE_BPS,
)
print(f"        dearest rate observed: {max(rates):.4f} bps over {len(rates)} fee(s)")

# ===========================================================================
section("S2 - every forfeit went to the asset's creator")

forfeits = [
    t
    for t in groups["sweep-5-forfeit.json"]
    if t["tx-type"] == "axfer"
    and t["asset-transfer-transaction"].get("close-to") not in (None, CALLER)
]
check("forfeits in the evidence", 6, len(forfeits))
check("each closes a non-empty holding, which is what a forfeit is", True,
      all(t["asset-transfer-transaction"]["close-amount"] > 0 for t in forfeits))
if ALGOD_URL:
    wrong = []
    for txn in forfeits:
        transfer = txn["asset-transfer-transaction"]
        creator = asset_creator(transfer["asset-id"])
        if creator != transfer["close-to"]:
            wrong.append((transfer["asset-id"], transfer["close-to"], creator))
    check("the chain agrees the destination is the creator", [], wrong)
else:
    skip("the chain agrees the destination is the creator", "no ALGOD_URL")

# ===========================================================================
section("the sweep reconciles against the account it swept")

closed = {
    t["asset-transfer-transaction"]["asset-id"]
    for name, g in groups.items()
    if name.startswith("sweep")
    for t in g
    if t["tx-type"] == "axfer"
    and t["sender"] == CALLER
    and t["asset-transfer-transaction"].get("close-to")
}
held = {a["asset-id"] for a in account["assets"]}
check("distinct holdings closed", 47, len(closed))
check("none of them is still opted in", set(), closed & held)
check("the account holds what is left", len(account["assets"]), account["total-assets-opted-in"])
empty = sorted(a["asset-id"] for a in account["assets"] if a["amount"] == 0)
print(f"        {len(empty)} empty holdings the sweep left alone: {empty}")
recovered = len(closed) * HOLDING_MINIMUM_BALANCE
print(f"        minimum balance released: {recovered:,} microALGO "
      f"against {network:,} in fees")

# ===========================================================================
print()
print("-" * 73)
print(f"  {PASS} passed, {FAIL} failed, {SKIP} skipped")
print()
sys.exit(1 if FAIL else 0)
