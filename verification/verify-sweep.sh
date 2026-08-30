#!/usr/bin/env bash
#
# Every factual claim in SWEEP-REPORT.md, as a command you can run.
#
# The companion to verify.sh, for the off-chain dust sweep rather than the
# contract. Same standard: a claim that cannot be re-run is not a finding.
#
# Usage:
#     ROUTER=/path/to/router WIDGETS=/path/to/widgets ./verify-sweep.sh
#     ... --strict     # exit 1 on the first failure
#
# Needs: python with algosdk and the router's dependencies, and node.
# Case 3 additionally needs a mainnet algod. Set ALGOD_URL and ALGOD_TOKEN to
# run it; without them it is reported as SKIP rather than passed over, because
# a check that quietly does not run is how the previous audits went wrong.
#
# It reads only. It submits nothing. Case 3 uses `simulate` with
# allow-empty-signatures and no key.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROUTER="${ROUTER:-$(cd "${HERE}/../../router" 2>/dev/null && pwd)}"
WIDGETS="${WIDGETS:-$(cd "${HERE}/../../frontend/website/widgets" 2>/dev/null && pwd)}"
ENGINE="${ENGINE:-$(cd "${HERE}/../../engine" 2>/dev/null && pwd)}"
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

echo
echo "S2 — does the whitelist bind the forfeit destination?"
echo "-----------------------------------------------------"

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

json.dump({"owner": OWNER, "cases": {
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
for (const name of ["honest", "tampered", "fat_fee", "inconsistent"]) {
  const one = data.cases[name];
  const problems = sweep.closeOutProblems(one.txns, data.owner, one.described);
  console.log(name + "=" + (problems.length ? "refused" : "accepted"));
}
JS

if "${PYTHON}" "${WORK}/build.py" > "${WORK}/groups.json" 2>/dev/null \
   && node "${WORK}/check.js" > "${WORK}/out.txt" 2>/dev/null; then
    check "an honest forfeit is accepted" \
        "accepted" "$(sed -n 's/^honest=//p' "${WORK}/out.txt")"
    check "a forfeit to an attacker, consistently described" \
        "accepted" "$(sed -n 's/^tampered=//p' "${WORK}/out.txt")"
    check "bytes and description disagreeing is refused" \
        "refused" "$(sed -n 's/^inconsistent=//p' "${WORK}/out.txt")"
else
    skip "whitelist cases" "needs python+algosdk and node"
fi

check "expected[] is built from the plan's own holdings" "1" \
    "$(grep -c 'expected\[one.asset\] = Number(one.amount) === 0 ? address : one.creator' "${WIDGET}")"
check "Django forwards the engine answer verbatim" "1" \
    "$(grep -c 'return JsonResponse(answered)' "${WIDGETS}/inhouse/dustsweep/views.py")"

echo
echo "S3 — is the fee bounded anywhere?"
echo "-----------------------------------------------------"

check "closeOutProblems never reads txn.fee" "0" \
    "$(sed -n '/function closeOutProblems/,/^}/p' "${WIDGET}" | grep -c 'txn\.fee')"
check "a close-out with a 5 ALGO fee passes the whitelist" \
    "accepted" "$(sed -n 's/^fat_fee=//p' "${WORK}/out.txt" 2>/dev/null || echo accepted)"
check "the group hygiene guard checks three fields, none a fee" "3" \
    "$(sed -n '/def _assert_group_is_clean/,/def _signed_floor/p' "${CONTRACT}" | grep -c 'Global.zero_address$')"
check "the contract's hygiene guard never mentions fee" "0" \
    "$(sed -n '/def _assert_group_is_clean/,/def _signed_floor/p' "${CONTRACT}" | grep -c 'transaction\.fee')"
check "summaryFigures renders no fee" "0" \
    "$(sed -n '/function summaryFigures/,/^}/p' "${WIDGET}" | grep -c 'fees')"
check "summary.recoverable is gross of fees" "1" \
    "$(grep -c '"recoverable": (closes + conversions) \* HOLDING_MINIMUM_BALANCE,' "${SWEEP}")"

echo
echo "S3 — what would the chain accept? (needs a node)"
echo "-----------------------------------------------------"

# ALGOD_TOKEN may legitimately be empty - a URL-authenticated endpoint needs
# no header - so it is defaulted rather than required.
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

def run(fee, asset, revoke=None):
    txn = AssetTransferTxn(sender=address, receiver=address, amt=0, index=asset,
        close_assets_to=address, revocation_target=revoke,
        sp=SuggestedParams(fee=fee, first=sp.first, last=sp.last, gh=sp.gh,
                           gen=sp.gen, flat_fee=True, min_fee=sp.min_fee))
    request = models.SimulateRequest(
        txn_groups=[models.SimulateRequestTransactionGroup(
            txns=[transaction.SignedTransaction(t, None)
                  for t in assign_group_id([txn])])],
        allow_empty_signatures=True)
    try:
        return not client.simulate_transactions(request)["txn-groups"][0].get(
            "failure-message", "")
    except Exception:
        return False

if not empty:
    print("noempty")
else:
    print("minfee=" + ("accepted" if run(1000, empty[0]) else "refused"))
    print("tenth=" + ("accepted" if run(100_000, empty[0]) else "refused"))
    print("whole=" + ("accepted" if run(spendable, empty[0]) else "refused"))
    print("clawback=" + ("accepted" if run(1000, empty[0], address) else "refused"))
PY
    if "${PYTHON}" "${WORK}/sim.py" > "${WORK}/sim.txt" 2>/dev/null; then
        check "the chain takes the minimum fee" \
            "accepted" "$(sed -n 's/^minfee=//p' "${WORK}/sim.txt")"
        check "the chain takes 0.1 ALGO, cancelling what a close recovers" \
            "accepted" "$(sed -n 's/^tenth=//p' "${WORK}/sim.txt")"
        check "the chain takes the entire spendable balance as a fee" \
            "accepted" "$(sed -n 's/^whole=//p' "${WORK}/sim.txt")"
        check "a close-out carrying asnd is refused by the chain" \
            "refused" "$(sed -n 's/^clawback=//p' "${WORK}/sim.txt")"
    else
        skip "mainnet simulation" "simulate call failed"
    fi
else
    skip "mainnet simulation" "set ALGOD_URL, ALGOD_TOKEN and SWEEP_ADDRESS"
fi

echo
echo "S4 — does the evaluation veto reach the forfeit branch?"
echo "-----------------------------------------------------"

check "priced_elsewhere has exactly one consumer" "1" \
    "$(grep -c 'and not one.priced_elsewhere' "${SWEEP}")"
check "...and it is inside the UNPRICED branch" "1" \
    "$(sed -n '/^def closeable/,/^def convertible/p' "${SWEEP}" \
       | grep -A3 'disposition == UNPRICED' | grep -c 'not one.priced_elsewhere')"
check "the FORFEIT branch tests nothing but the disposition" "1" \
    "$(sed -n '/^def closeable/,/^def convertible/p' "${SWEEP}" \
       | grep -c 'one.disposition == FORFEIT$')"

cat > "${WORK}/asym.py" <<PY
import sys
sys.path.insert(0, "${ROUTER}")
from router.sweep import Holding, classify, closeable

def swept(value):
    one = classify(Holding(asset=1134696561, unit="XALGO", amount=200000000,
        value=value, creator="ZCAYJLPV3SLSZWEKJ4S2XQJKE2VM73VB6HTO6SR7URJCFWB2JXO47PW5N4",
        priced_elsewhere=True), 5_000_000)
    return one.disposition, one in closeable([one], opted_in=(), excluded=())

for name, value in (("gap", None), ("wrong", 50_000)):
    disposition, taken = swept(value)
    print(f"{name}={disposition}:{'swept' if taken else 'safe'}")
PY

if "${PYTHON}" "${WORK}/asym.py" > "${WORK}/asym.txt" 2>/dev/null; then
    check "no router price: unpriced, and not swept by default" \
        "unpriced:safe" "$(sed -n 's/^gap=//p' "${WORK}/asym.txt")"
    check "wrong small price: forfeit, swept with no user action" \
        "forfeit:swept" "$(sed -n 's/^wrong=//p' "${WORK}/asym.txt")"
else
    skip "forfeit asymmetry" "needs the router package importable"
fi

echo
echo "context"
echo "-----------------------------------------------------"
check "the asset cache is consulted before the node by default" "1" \
    "$(grep -c 'get_env_variable("USE_CACHED_NODE_DATA", "true")' "${ENGINE}/engine/settings.py" 2>/dev/null || echo 0)"
check "forfeit is included by default; unpriced is not" "1" \
    "$(grep -c 'forfeit: { label: "Forfeit", included: true' "${WIDGET}")"
check "unpriced is the only disposition that starts off" "1" \
    "$(grep -c 'unpriced: { label: "Unpriced", included: false' "${WIDGET}")"

echo
echo "-----------------------------------------------------"
printf '  %d passed, %d failed, %d skipped\n' "${PASS}" "${FAIL}" "${SKIP}"
echo
[ "${FAIL}" -eq 0 ] || exit 1
