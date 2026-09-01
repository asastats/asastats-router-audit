#!/usr/bin/env bash
#
# Every factual claim in SWEEP-REPORT.md, as a command you can run.
#
# The companion to verify.sh, for the off-chain dust sweep rather than the
# contract. Same standard: a claim that cannot be re-run is not a finding.
#
# **These now assert the fixed behaviour.** The first revision of this script
# asserted the defects, and every check passed - which was the finding. `S2`,
# `S3` and `S4` are closed, so each check below is the regression test for one
# of them, and a failure here means a fix has been undone.
#
# Usage:
#     ROUTER=/path/to/router WIDGETS=/path/to/widgets ./verify-sweep.sh
#     ... --strict     # exit 1 on the first failure
#
# Needs: python with algosdk and the router's dependencies, and node.
# Case 3 additionally needs a mainnet algod. Set ALGOD_URL and SWEEP_ADDRESS to
# run it; without them it is reported as SKIP rather than passed over, because
# a check that quietly does not run is how the previous audits went wrong.
#
# It reads only. It submits nothing. The chain cases use `simulate` with
# allow-empty-signatures and no key.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROUTER="${ROUTER:-$(cd "${HERE}/../../router" 2>/dev/null && pwd)}"
WIDGETS="${WIDGETS:-$(cd "${HERE}/../../frontend/website/widgets" 2>/dev/null && pwd)}"
ENGINE="${ENGINE:-$(cd "${HERE}/../../engine" 2>/dev/null && pwd)}"
BUNDLE="${BUNDLE:-${HERE}/../../frontend/website/static/js/bundle.js}"
SWAPBRIDGE="${SWAPBRIDGE:-${HERE}/../../frontend/wallet/src/swapBridge.ts}"
PYTHON="${PYTHON:-python3}"
STRICT=""
[ "${1:-}" = "--strict" ] && STRICT="yes"

PASS=0; FAIL=0; SKIP=0

SWEEP="${ROUTER}/router/sweep.py"
WIDGET="${WIDGETS}/inhouse/dustsweep/static/dustsweep/dustsweep.js"
CONTRACT="${ROUTER}/contracts/router_app.py"

for required in "${SWEEP}" "${WIDGET}"; do
    if [ ! -f "${required}" ]; then
        echo "not found: ${required}"
        echo "set ROUTER=/path/to/router and WIDGETS=/path/to/widgets"
        exit 2
    fi
done

check () {
    local label="$1" want="$2" got="$3"
    if [ "${want}" = "${got}" ]; then
        printf '  PASS  %-56s %s\n' "${label}" "${got}"
        PASS=$((PASS + 1))
    else
        printf '  FAIL  %-56s want=%s got=%s\n' "${label}" "${want}" "${got}"
        FAIL=$((FAIL + 1))
        [ -n "${STRICT}" ] && exit 1
    fi
}

skip () {
    printf '  SKIP  %-56s %s\n' "$1" "$2"
    SKIP=$((SKIP + 1))
}

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cat > "${WORK}/build.py" <<'PY'
import json, random, sys
from algosdk import encoding
from algosdk.transaction import AssetTransferTxn, SuggestedParams, assign_group_id

random.seed(20260830)
addr = lambda: encoding.encode_address(
    bytes(random.getrandbits(8) for _ in range(32)))
OWNER, CREATOR, ATTACKER = addr(), addr(), addr()
ASSET = 31566704

def sp(fee, flat):
    return SuggestedParams(fee=fee, first=1000, last=2000, flat_fee=flat,
        min_fee=1000, gen="mainnet-v1.0",
        gh="wGHE2Pwdvd7S12BL5FaOP20EGYesN73ktiC1qzkkit8=")

def group(target, fee=0, flat=False):
    return [encoding.msgpack_encode(t) for t in assign_group_id([
        AssetTransferTxn(sender=OWNER, sp=sp(fee, flat), receiver=OWNER,
                         amt=0, index=ASSET, close_assets_to=target)])]

def described(creator):
    return [{"asset": ASSET, "unit": "USDC", "amount": 1000000,
             "creator": creator, "disposition": "forfeit"}]

json.dump({"owner": OWNER, "creator": CREATOR, "attacker": ATTACKER, "cases": {
    "honest":   {"txns": group(CREATOR),  "described": described(CREATOR)},
    "tampered": {"txns": group(ATTACKER), "described": described(ATTACKER)},
    "fat_fee":  {"txns": group(CREATOR, 5_000_000, True),
                 "described": described(CREATOR)},
    "inconsistent": {"txns": group(ATTACKER), "described": described(CREATOR)},
}}, sys.stdout)
PY

cat > "${WORK}/check.js" <<JS
global.atob = (b) => Buffer.from(b, "base64").toString("binary");
const sweep = require("${WIDGET}");
const data = require("${WORK}/groups.json");
const verdict = (p) => (p.length ? "refused" : "accepted");

(async () => {
  for (const name of ["honest", "tampered", "fat_fee", "inconsistent"]) {
    const one = data.cases[name];
    console.log(
      "whitelist." + name + "=" +
      verdict(sweep.closeOutProblems(one.txns, data.owner, one.described))
    );
  }

  // The independent half: the creator comes from the chain, not the plan.
  const chainSays = (creator) => ({ assetCreator: async () => creator });
  const t = data.cases.tampered;
  console.log("chain.agrees=" + verdict(
    await sweep.forfeitTargetProblems(
      data.cases.honest.txns, data.cases.honest.described, chainSays(data.creator))));
  console.log("chain.disagrees=" + verdict(
    await sweep.forfeitTargetProblems(t.txns, t.described, chainSays(data.creator))));
  console.log("chain.silent=" + verdict(
    await sweep.forfeitTargetProblems(t.txns, t.described, {})));
  console.log("chain.unreadable=" + verdict(
    await sweep.forfeitTargetProblems(t.txns, t.described, chainSays(null))));
})();
JS

if "${PYTHON}" "${WORK}/build.py" > "${WORK}/groups.json" 2>/dev/null \
   && node "${WORK}/check.js" > "${WORK}/out.txt" 2>/dev/null; then
    HAVE_JS="yes"
else
    HAVE_JS=""
fi

said () { sed -n "s/^$1=//p" "${WORK}/out.txt" 2>/dev/null; }

echo
echo "S2 — is the forfeit destination bound to something outside the response?"
echo "-------------------------------------------------------------------------"

if [ -n "${HAVE_JS}" ]; then
    check "an honest forfeit is accepted" "accepted" "$(said whitelist.honest)"
    # Unchanged and expected: the whitelist compares the bytes against the
    # plan, and a consistent plan agrees with itself. This is *why* the second
    # check below exists, not a defect in this one.
    check "the whitelist alone still cannot see a consistent lie" \
        "accepted" "$(said whitelist.tampered)"
    check "bytes and description disagreeing is refused" \
        "refused" "$(said whitelist.inconsistent)"
    check "the chain agreeing accepts the forfeit" "accepted" "$(said chain.agrees)"
    check "the chain disagreeing refuses it" "refused" "$(said chain.disagrees)"
    check "a bridge that cannot answer refuses (fails closed)" \
        "refused" "$(said chain.silent)"
    check "an unreadable asset refuses (fails closed)" \
        "refused" "$(said chain.unreadable)"
else
    skip "whitelist and chain cases" "needs python+algosdk and node"
fi

check "signAction runs the chain check too" "1" \
    "$(grep -c 'problems = await forfeitTargetProblems(' "${WIDGET}")"
check "the shipped wallet bundle exposes assetCreator" "1" \
    "$(grep -c 'assetCreator' "${BUNDLE}" 2>/dev/null || echo 0)"

echo
echo "S3 — is the fee bounded?"
echo "-------------------------------------------------------------------------"

check "closeOutProblems reads txn.fee" "2" \
    "$(sed -n '/function closeOutProblems/,/^}/p' "${WIDGET}" | grep -c 'txn\.fee')"
if [ -n "${HAVE_JS}" ]; then
    check "a close-out with a 5 ALGO fee is refused" \
        "refused" "$(said whitelist.fat_fee)"
fi
check "the cap is a fraction of what a close-out returns" "1" \
    "$(grep -c 'var MAX_CLOSE_OUT_FEE = HOLDING_MINIMUM_BALANCE / 10;' "${WIDGET}")"
check "summaryFigures renders the fee" "1" \
    "$(sed -n '/function summaryFigures/,/^}/p' "${WIDGET}" | grep -c 'Network fees')"
check "summary.recoverable is net of fees" "1" \
    "$(grep -c '"recoverable": (closes + conversions) \* HOLDING_MINIMUM_BALANCE - fees,' "${SWEEP}")"
check "the contract's hygiene guard still checks its three fields" "3" \
    "$(sed -n '/def _assert_group_is_clean/,/def _signed_floor/p' "${CONTRACT}" | grep -c 'Global.zero_address$')"
check "the hygiene guard now totals the group's fee" "1" \
    "$(sed -n '/def _assert_group_is_clean/,/def _signed_floor/p' "${CONTRACT}" | grep -c 'paid += transaction.fee')"
check "...and refuses a group that overpays" "1" \
    "$(sed -n '/def _assert_group_is_clean/,/def _signed_floor/p' "${CONTRACT}" | grep -c 'assert paid <= MAX_GROUP_FEE')"

# The ceiling has to clear what a legitimate route can legitimately need, or
# the contract becomes the thing that breaks every swap through it.
cat > "${WORK}/ceiling.py" <<'CEILING'
import sys
from collections import namedtuple
from itertools import product

sys.path.insert(0, sys.argv[1])
sys.path.insert(0, sys.argv[1] + "/contracts")
from router.contract import route_fee, Deployment, MAX_STAMM_OPUPS
from router_app import MAX_GROUP_FEE

Leg = namedtuple("Leg", ["provider", "opups", "handle"], defaults=(None,))
Q = namedtuple("_Route", ["handle"])
dear = Deployment(router_app_id=None, tinyman_validator=1, stamm_budget=2,
                  stamm_opup=3, stamm_opup_count=MAX_STAMM_OPUPS)
worst = max(
    route_fee(Q(tuple(Leg(p, 0) for p in combo)), 1,
              tuple(range(1, n)) if n > 1 else 0, 2,
              deployment=dear, held=frozenset())
    for n in (1, 2, 3)
    for combo in product(["tinyman2", "pact", "algofi", "stamm"], repeat=n)
)
# Seven route calls is the most a sixteen-transaction group can hold, each
# needing a funding transaction beside it.
print("clears" if MAX_GROUP_FEE > worst * 7 else "too tight")
CEILING

check "the ceiling clears the dearest route route_fee can return" "clears" \
    "$("${PYTHON}" "${WORK}/ceiling.py" "${ROUTER}" 2>/dev/null || echo unknown)"

echo
echo "S3 — what the chain would accept, unchanged by any fix (needs a node)"
echo "-------------------------------------------------------------------------"

export ALGOD_TOKEN="${ALGOD_TOKEN:-}"
if [ -n "${ALGOD_URL:-}" ] && [ -n "${SWEEP_ADDRESS:-}" ]; then
    cat > "${WORK}/sim.py" <<'PY'
import os
from algosdk import transaction
from algosdk.transaction import AssetTransferTxn, SuggestedParams, assign_group_id
from algosdk.v2client import algod, models

client = algod.AlgodClient(os.environ["ALGOD_TOKEN"], os.environ["ALGOD_URL"],
    headers={"X-Algo-API-Token": os.environ["ALGOD_TOKEN"]})
address = os.environ["SWEEP_ADDRESS"]
info = client.account_info(address)
spendable = info["amount"] - info["min-balance"]
empty = [a["asset-id"] for a in info["assets"] if a["amount"] == 0]
sp = client.suggested_params()
# A rekeyed account has to say who would have signed, or simulate refuses the
# group for the wrong reason and the check below reports `refused` when the
# truthful answer is "not asked". That is exactly the failure this repository
# exists to stop, and it was found by pointing this script at a second account:
# the first was not rekeyed, so the bug could not appear.
auth = info.get("auth-addr")

def run(fee, asset, revoke=None):
    txn = AssetTransferTxn(sender=address, receiver=address, amt=0, index=asset,
        close_assets_to=address, revocation_target=revoke,
        sp=SuggestedParams(fee=fee, first=sp.first, last=sp.last, gh=sp.gh,
                           gen=sp.gen, flat_fee=True, min_fee=sp.min_fee))
    signed = [transaction.SignedTransaction(t, None)
              for t in assign_group_id([txn])]
    if auth:
        for one in signed:
            one.authorizing_address = auth
    request = models.SimulateRequest(
        txn_groups=[models.SimulateRequestTransactionGroup(txns=signed)],
        allow_empty_signatures=True)
    try:
        return not client.simulate_transactions(request)["txn-groups"][0].get(
            "failure-message", "")
    except Exception:
        return False

if not empty:
    print("noempty")
else:
    print("whole=" + ("accepted" if run(spendable, empty[0]) else "refused"))
    print("clawback=" + ("accepted" if run(1000, empty[0], address) else "refused"))
PY
    if "${PYTHON}" "${WORK}/sim.py" > "${WORK}/sim.txt" 2>/dev/null; then
        check "the chain itself still bounds a fee only by the balance" \
            "accepted" "$(sed -n 's/^whole=//p' "${WORK}/sim.txt")"
        check "a close-out carrying asnd is refused by the chain" \
            "refused" "$(sed -n 's/^clawback=//p' "${WORK}/sim.txt")"
    else
        skip "mainnet simulation" "simulate call failed"
    fi
else
    skip "mainnet simulation" "set ALGOD_URL and SWEEP_ADDRESS"
fi

echo
echo "S4 — does a forfeit check the second opinion?"
echo "-------------------------------------------------------------------------"

check "classify consults disputed_dust" "1" \
    "$(grep -c 'if disputed_dust(holding, forfeit_threshold):' "${SWEEP}")"
check "the engine carries the evaluation's value onto the holding" "1" \
    "$(grep -c 'evaluated_value=evaluated_values.get(asset),' "${ENGINE}/core/sweep.py" 2>/dev/null || echo 0)"

cat > "${WORK}/asym.py" <<PY
import sys
sys.path.insert(0, "${ROUTER}")
from router.sweep import Holding, classify, closeable

def swept(value, evaluated):
    one = classify(Holding(asset=1134696561, unit="XALGO", amount=200000000,
        value=value, creator="ZCAYJLPV3SLSZWEKJ4S2XQJKE2VM73VB6HTO6SR7URJCFWB2JXO47PW5N4",
        priced_elsewhere=evaluated is not None,
        evaluated_value=evaluated), 5_000_000)
    return one.disposition, one in closeable([one], opted_in=(), excluded=())

for name, value, evaluated in (
    ("gap", None, 245_878_745),
    ("disputed", 50_000, 245_878_745),
    ("agreed", 50_000, 50_000),
    ("silent", 50_000, None),
):
    disposition, taken = swept(value, evaluated)
    print(f"{name}={disposition}:{'swept' if taken else 'safe'}")
PY

if "${PYTHON}" "${WORK}/asym.py" > "${WORK}/asym.txt" 2>/dev/null; then
    check "no router price at all: still unpriced and still safe" \
        "unpriced:safe" "$(sed -n 's/^gap=//p' "${WORK}/asym.txt")"
    check "wrong small price the evaluation disputes: kept, not swept" \
        "keep:safe" "$(sed -n 's/^disputed=//p' "${WORK}/asym.txt")"
    check "both sources calling it dust: still forfeited" \
        "forfeit:swept" "$(sed -n 's/^agreed=//p' "${WORK}/asym.txt")"
    check "evaluation with no opinion: still forfeited" \
        "forfeit:swept" "$(sed -n 's/^silent=//p' "${WORK}/asym.txt")"
else
    skip "forfeit asymmetry" "needs the router package importable"
fi

echo
echo "Before RESTRICT_TO_ADMIN comes off — the two levers that replace it"
echo "-------------------------------------------------------------------------"

check "routing can be stopped without a redeploy" "1" \
    "$(grep -c 'def set_paused' "${CONTRACT}")"
check "both route entry points honour the pause" "2" \
    "$(grep -c 'assert not self.paused, "routing is paused"' "${CONTRACT}")"
check "the pause is admin-only" "1" \
    "$(grep -c 'only the admin may pause routing' "${CONTRACT}")"
check "close_holding is NOT paused, so recovery survives it" "0" \
    "$(sed -n '/def close_holding/,/def route/p' "${CONTRACT}" | grep -c 'self.paused')"
# There is no input cap, and that is a decision rather than an omission: a
# bound in the input asset's base units cannot state a value -- the same number
# is 50,000 ALGO and 50,000 USDC -- and putting it in value terms needs a price
# oracle inside the contract. Asserted so the removal does not quietly come
# back as something a reader would have to be warned about.
check "no input cap, which could not have meant one thing" "0" \
    "$(grep -c 'max_input' "${CONTRACT}")"

# `paused` moves the global schema from (2, 5) to (3, 5). Three
# LocalNet fixtures used to pin the old pair by hand, and getting it wrong is
# an opaque HTTP 400 from the create rather than anything that names state --
# so nothing should restate it now.
check "the contract carries three global uints" "3" \
    "$(sed -n '/def __init__/,/def set_paused/p' "${CONTRACT}" | grep -c 'UInt64(')"
check "the test harness takes the schema from the compiler" "1" \
    "$(grep -c 'CompiledContract = namedtuple' "${ROUTER}/tests/localnet.py")"
check "no fixture pins a schema by hand any more" "0" \
    "$(grep -c '(2, 5)' "${ROUTER}/tests/test_contract_localnet.py")"

# Derived, not listed -- the method that found 12 of 14 when a hand pass had
# said 14 of 14, and that caught these two setters arriving without the guard.
cat > "${WORK}/guards.py" <<'GUARDS'
import re
import sys

source = open(sys.argv[1]).read()
parts = re.split(r"\n    @arc4\.(?:abimethod|baremethod)[^\n]*\n", source)
names, unguarded = [], []
for body in parts[1:]:
    named = re.match(r"\s*def (\w+)", body)
    if not named:
        continue
    end = re.search(r"\n    @(arc4\.(abimethod|baremethod)|subroutine)", body)
    chunk = body[: end.start()] if end else body
    names.append(named.group(1))
    if "_assert_group_is_clean()" not in chunk:
        unguarded.append(named.group(1))
print(f"{len(names)}/{len(names) - len(unguarded)}/{','.join(sorted(unguarded))}")
GUARDS

check "15 entry points, 13 walking the group, 2 inert" \
    "15/13/pool_budget,verify_discount" \
    "$("${PYTHON}" "${WORK}/guards.py" "${CONTRACT}" 2>/dev/null || echo unknown)"

echo
echo "S5 — does a malformed payload degrade rather than raise?"
echo "-------------------------------------------------------------------------"

check "the evaluation readers share one shape-tolerant reader" "2" \
    "$(grep -c 'for asset, item in _evaluation_items(evaluation):' "${SWEEP}")"
check "the browser checks share one too" "2" \
    "$(grep -c 'planLines(described).forEach' "${WIDGET}")"

cat > "${WORK}/shapes.py" <<'SHAPES'
import sys

sys.path.insert(0, sys.argv[1])
from router.sweep import priced_by_evaluation, values_by_evaluation

# Anything at all, including the shapes that used to raise: a payload that is
# not a mapping, an `asaitems` that is not iterable, an `asset` that is not a
# mapping.
for payload in (None, True, 7, "text", [], {}, {"asaitems": True},
                {"asaitems": 5}, {"asaitems": [None]}, {"asaitems": [{}]},
                {"asaitems": [{"asset": True}]},
                {"asaitems": [{"asset": {"id": "x"}}]}):
    try:
        priced_by_evaluation(payload)
        values_by_evaluation(payload)
    except Exception as error:
        print(f"raises on {payload!r}: {error}")
        break
else:
    print("degrades")
SHAPES

check "neither python reader raises on any shape" "degrades" \
    "$("${PYTHON}" "${WORK}/shapes.py" "${ROUTER}" 2>/dev/null || echo unknown)"

if [ -n "${HAVE_JS}" ]; then
    cat > "${WORK}/shapes.js" <<JS
global.atob = (b) => Buffer.from(b, "base64").toString("binary");
const sweep = require("${WIDGET}");
const data = require("${WORK}/groups.json");
const group = data.cases.honest.txns;
(async () => {
  for (const plan of [undefined, null, [], " ", "x", 7, true, {a: 1}, [null], [7]]) {
    try {
      sweep.closeOutProblems(group, data.owner, plan);
      await sweep.forfeitTargetProblems(group, plan, {});
    } catch (error) {
      console.log("raises: " + error.message);
      return;
    }
  }
  console.log("degrades");
})();
JS
    check "neither browser check raises on any shape" "degrades" \
        "$(node "${WORK}/shapes.js" 2>/dev/null || echo unknown)"
fi

echo
echo "S6 — is the conversion path checked at all?"
echo "-------------------------------------------------------------------------"
# These asserted the gap while S6 was open. They assert the fix now.

check "signAction dispatches on the engine's own action.kind" "1" \
    "$(sed -n '/^async function signAction/,/^}/p' "${WIDGET}" | grep -c 'if (action.kind === "convert") {')"
check "...and its convert branch no longer trusts it" "1" \
    "$(sed -n '/if (action.kind === "convert") {/,/^  }/p' "${WIDGET}" | grep -c 'routedGroupProblems(action.transactions, routerApp)')"
check "the browser mirrors the contract's three hygiene fields" "3" \
    "$(sed -n '/^function routedGroupProblems/,/^}/p' "${WIDGET}" | grep -c 'txn.rekey\|txn.close\|txn.aclose')"
check "...and the contract's group fee ceiling, by its number" "1" \
    "$(grep -c 'var MAX_GROUP_FEE = 1000000;' "${WIDGET}")"
check "which is the number the contract actually uses" "1" \
    "$(grep -c '^MAX_GROUP_FEE = 1_000_000$' "${CONTRACT}")"
check "a group that will not decode is refused, not skipped" "2" \
    "$(sed -n '/^function routedGroupProblems/,/^}/p' "${WIDGET}" | grep -c 'could not be decoded')"

# The contract would refuse these groups. It only ran if it was called, which
# was the whole of S6 - the same structural fact S3 §7 records for close-outs.
check "the hygiene guard refuses closes, when it runs" "2" \
    "$(sed -n '/def _assert_group_is_clean/,/def _signed_floor/p' "${CONTRACT}" | grep -c 'this group closes')"

if [ -f "${SWAPBRIDGE}" ]; then
    check "signAndSendPartial checks quote placement and signatures" "3" \
        "$(sed -n '/export async function signAndSendPartial/,/^}/p' "${SWAPBRIDGE}" | grep -c 'Quote authorization must be the final transaction\|Backend signature does not match the grouped transaction\|Backend quote signature is missing')"
else
    skip "the bridge's partial-group checks" "set SWAPBRIDGE=/path/to/swapBridge.ts"
fi

echo
echo "S7 — does the conversion path require the checks to actually run?"
echo "-------------------------------------------------------------------------"
# Mirroring the hygiene guard was not enough: hygiene is not what a transfer to
# a stranger violates. What refuses that is the router's own logic, and it runs
# only when the router is called.

check "a conversion must call a router method that guards" "1" \
    "$(sed -n '/^function routedGroupProblems/,/^}/p' "${WIDGET}" | grep -c 'calls no router method')"
check "the app id is page context, never the plan response" "1" \
    "$(grep -c 'data-router-app="{{ router_app_id }}"' "${WIDGETS}/inhouse/dustsweep/templates/dustsweep/index.html")"
check "...handed down by the view, not read from the engine" "1" \
    "$(grep -c 'context\["router_app_id"\] = getattr(settings, "ROUTER_APP_ID", ROUTER_APP_ID)' "${WIDGETS}/inhouse/dustsweep/views.py")"
check "...and the widget carries the same id as a fallback" "2" \
    "$(cat "${WIDGET}" "${WIDGETS}/inhouse/dustsweep/views.py" | grep -c '3689591968')"
check "which is the application the audit pins to mainnet" "1" \
    "$(grep -c '^Deployments.*3689591968\|mainnet .3689591968' "${HERE}/../REPORT.md")"

# The two entry points that skip the contract's guard cannot count as "called".
check "the exempt selectors are both excluded" "2" \
    "$(sed -n '/^var BUDGET_ONLY_SELECTORS/,/^];/p' "${WIDGET}" | grep -c '0x')"
cat > "${WORK}/selectors.py" <<'SEL'
"""Are the two excluded selectors the ones the contract actually exposes?

Hardcoding four bytes is fine; hardcoding the wrong four bytes silently turns
the S7 rule into "any router call counts". Recomputed here from the method
signatures rather than compared against a copy of themselves.
"""
import hashlib
import re
import sys

want = {
    hashlib.new("sha512_256", sig.encode()).digest()[:4].hex()
    for sig in ("verify_discount(byte[])void", "pool_budget()void")
}
block = re.search(
    r"var BUDGET_ONLY_SELECTORS = \[(.*?)\];", open(sys.argv[1]).read(), re.S
).group(1)
have = {
    "".join(part.strip().rstrip(",")[2:].zfill(2) for part in row.split(",") if part.strip())
    for row in re.findall(r"\[([^\]]*)\]", block)
    if row.strip()
}
print("ok" if have == want else "mismatch have=%s want=%s" % (sorted(have), sorted(want)))
SEL
check "...and they are the selectors the contract actually exposes" "ok" \
    "$("${PYTHON}" "${WORK}/selectors.py" "${WIDGET}" 2>/dev/null || echo unknown)"

echo
echo "S8 — what still gets through, and why the obvious rule cannot be it (OPEN)"
echo "-------------------------------------------------------------------------"
# Pins an OPEN finding: these assert the gap and the reason it is not closed.
# Invert them only if a complete fix lands.

check "the route binds only the transaction before it" "1" \
    "$(grep -c 'input must immediately precede the route' "${CONTRACT}")"
check "the hygiene guard reads no amount and no receiver" "0" \
    "$(sed -n '/def _assert_group_is_clean/,/def _signed_floor/p' "${CONTRACT}" | grep -c 'asset_amount\|asset_receiver')"
check "and the browser bounds no receiver either" "0" \
    "$(sed -n '/^function routedGroupProblems/,/^}/p' "${WIDGET}" | grep -c 'arcv\|rcv')"

# The reason a receiver whitelist is not the fix: a real conversion pays an
# address that is neither the router nor derivable from the group.
if [ -d "${HERE}/../evidence/groups" ]; then
    check "a conversion that executed pays a non-router address" "1" \
        "$("${PYTHON}" - "${HERE}/../evidence/groups/sweep-6-convert.json" <<'ESCROW'
import json, sys
router = "GV27MIISIGA7GV2EHG2TM5K423VRQKQXVBXLS7WNR2IAZ73AGTEEBPMUEU"
dec, text, i, out = json.JSONDecoder(), open(sys.argv[1]).read(), 0, []
while i < len(text):
    while i < len(text) and text[i].isspace():
        i += 1
    if i >= len(text):
        break
    obj, i = dec.raw_decode(text, i)
    out.append(obj["transaction"])
others = {
    t["asset-transfer-transaction"]["receiver"]
    for t in out
    if t["tx-type"] == "axfer"
    and t["asset-transfer-transaction"]["receiver"] != router
}
print(len(others))
ESCROW
)"
fi

# **The finding demonstrated, not described.** A conversion that executed on
# mainnet, plus one axfer moving an asset the sweep never mentioned to an
# address of the attacker's choosing. Both must be accepted for the finding to
# be true; the day the second one is refused, S8 is closed and this check is
# what says so.
FIXTURE="${WIDGETS}/inhouse/dustsweep/tests/javascript/mainnet-groups.json"
if [ -n "${HAVE_JS}" ] && [ -f "${FIXTURE}" ]; then
    cat > "${WORK}/s8.js" <<S8
global.atob = (b) => Buffer.from(b, "base64").toString("binary");
const sweep = require("${WIDGET}");
const groups = require("${FIXTURE}");

// msgpack, in the fixmap/fixstr/bin8/uint subset the widget decodes
function enc(obj) {
  const keys = Object.keys(obj), parts = [Buffer.from([0x80 | keys.length])];
  for (const k of keys) {
    parts.push(Buffer.from([0xa0 | k.length]), Buffer.from(k, "binary"));
    const v = obj[k];
    if (typeof v === "string") {
      parts.push(Buffer.from([0xa0 | v.length]), Buffer.from(v, "binary"));
    } else if (Buffer.isBuffer(v)) {
      parts.push(Buffer.from([0xc4, v.length]), v);
    } else if (v < 0x80) {
      parts.push(Buffer.from([v]));
    } else {
      const b = Buffer.alloc(5); b[0] = 0xce; b.writeUInt32BE(v, 1); parts.push(b);
    }
  }
  return Buffer.concat(parts).toString("base64");
}

const hostile = enc({
  amt: 4000000000,               // a whole balance
  arcv: Buffer.alloc(32, 7),     // an address the attacker controls
  fee: 1000,
  snd: Buffer.alloc(32, 3),      // the swept account
  type: "axfer",
  xaid: 31566704,                // an asset this sweep never mentioned
});

const honest = groups.sweep_3_convert;
const verdict = (g) => (sweep.routedGroupProblems(g, 3689591968).length ? "refused" : "accepted");
console.log("s8.honest=" + verdict(honest));
console.log("s8.attacked=" + verdict(honest.concat([hostile])));
S8
    if node "${WORK}/s8.js" > "${WORK}/s8.txt" 2>/dev/null; then
        check "a genuine conversion is accepted" "accepted" \
            "$(sed -n 's/^s8.honest=//p' "${WORK}/s8.txt")"
        check "...and so is the same group carrying a hostile transfer" \
            "accepted" "$(sed -n 's/^s8.attacked=//p' "${WORK}/s8.txt")"
    else
        skip "the S8 vector, demonstrated" "node could not run it"
    fi
else
    skip "the S8 vector, demonstrated" "needs node and the mainnet-groups fixture"
fi

# Why the tempting fix - committing the group's shape in the co-signed note -
# does not work: the engine holds the signing key in its own process, so an
# engine that can build a hostile group can sign a note describing it.
check "the quote signer key is read in the engine's own process" "2" \
    "$(grep -c 'private_key = _private_key(' "${ENGINE}/core/quote_signer.py" 2>/dev/null; true)"
check "...from a path on the engine's own host" "2" \
    "$(grep -c 'signer_key_path(network)' "${ENGINE}/core/quote_signer.py" 2>/dev/null; true)"
check "...and it validates group ids, not group composition" "0" \
    "$(sed -n '/^def _validate_group/,/^def sign_quote_authorization/p' "${ENGINE}/core/quote_signer.py" 2>/dev/null | grep -c 'receiver\|amount'; true)"

# The lookup that used to hang forever now refuses instead.
check "a creator lookup that never answers times out" "1" \
    "$(grep -c 'var CREATOR_LOOKUP_TIMEOUT = ' "${WIDGET}")"
check "...and a timeout resolves to null, so it joins the refusals" "1" \
    "$(sed -n '/^function withTimeout/,/^}/p' "${WIDGET}" | grep -c 'resolve(null)')"

echo
echo "context"
echo "-------------------------------------------------------------------------"
check "the asset cache is consulted before the node by default" "1" \
    "$(grep -c 'get_env_variable("USE_CACHED_NODE_DATA", "true")' "${ENGINE}/engine/settings.py" 2>/dev/null || echo 0)"
check "forfeit is included by default; unpriced is not" "1" \
    "$(grep -c 'forfeit: { label: "Forfeit", included: true' "${WIDGET}")"
check "unpriced is the only disposition that starts off" "1" \
    "$(grep -c 'unpriced: { label: "Unpriced", included: false' "${WIDGET}")"

echo
echo "-------------------------------------------------------------------------"
printf '  %d passed, %d failed, %d skipped\n' "${PASS}" "${FAIL}" "${SKIP}"
echo
[ "${FAIL}" -eq 0 ] || exit 1
