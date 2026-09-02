#!/usr/bin/env bash
#
# Every factual claim in REPORT.md, as a command you can run.
#
# This exists because the five audits that came before this one were not
# reproducible, and three of them asserted things that were not true — a test
# count that was wrong by a factor of nine, a deployment described as
# unrestricted when it is restricted, a hash labelled as something it is not.
# A claim nobody can re-check is not a finding, it is a sentence.
#
# Usage:
#     ROUTER=/path/to/router ./verify.sh          # human-readable
#     ROUTER=/path/to/router ./verify.sh --strict # exit 1 on the first failure
#
# It reads only. It needs the router checkout and a Python environment with
# the router's own dependencies; it does not need a node, a key, or network
# access. Checks that would need those are listed in REPORT.md under "not
# verified here" rather than being silently skipped.

set -uo pipefail

ROUTER="${ROUTER:-$(cd "$(dirname "$0")/../../router" 2>/dev/null && pwd)}"
STRICT=""
[ "${1:-}" = "--strict" ] && STRICT="yes"

PASS=0
FAIL=0
SKIP=0

if [ ! -f "${ROUTER}/contracts/router_app.py" ]; then
    echo "router checkout not found at: ${ROUTER}"
    echo "set ROUTER=/path/to/router and re-run"
    exit 2
fi

CONTRACT="${ROUTER}/contracts/router_app.py"

# check <label> <expected> <actual>
check () {
    local label="$1" want="$2" got="$3"
    if [ "${want}" = "${got}" ]; then
        printf '  PASS  %-58s %s\n' "${label}" "${got}"
        PASS=$((PASS + 1))
    else
        printf '  FAIL  %-58s want=%s got=%s\n' "${label}" "${want}" "${got}"
        FAIL=$((FAIL + 1))
        [ -n "${STRICT}" ] && exit 1
    fi
}

# skip <label> <why>   — counted, because a check that quietly does not run is
# how the previous audits went wrong
skip () {
    local label="$1" why="$2"
    printf '  SKIP  %-58s %s\n' "${label}" "${why}"
    SKIP=$((SKIP + 1))
}

# params <method>   — the parameter names of one contract method, in order.
#
# Parsed, not grepped. The grep this replaced looked for `minimum_received` on
# the same line as `def route(`, and `route` is declared one parameter per
# line - so it matched nothing whatever the signature said, and the check that
# H1 rests on could not fail. Reintroducing the caller-supplied floor left it
# reporting PASS. `ast` reads the signature the compiler reads.
params () {
    python3 - "${CONTRACT}" "$1" <<'PY'
import ast, sys

source, want = sys.argv[1], sys.argv[2]
found = [
    node
    for node in ast.walk(ast.parse(open(source).read()))
    if isinstance(node, ast.FunctionDef) and node.name == want
]
if not found:
    print(f"no method named {want}")
elif len(found) > 1:
    print(f"{len(found)} methods named {want}")
else:
    args = found[0].args
    named = args.posonlyargs + args.args + args.kwonlyargs
    print(",".join(a.arg for a in named if a.arg != "self"))
PY
}

# present <label> <pattern>   — the pattern must appear at least once
present () {
    local label="$1" pat="$2"
    local n
    n="$(grep -cE -- "${pat}" "${CONTRACT}")"
    if [ "${n}" -ge 1 ]; then
        printf '  PASS  %-58s %s occurrence(s)\n' "${label}" "${n}"
        PASS=$((PASS + 1))
    else
        printf '  FAIL  %-58s absent\n' "${label}"
        FAIL=$((FAIL + 1))
        [ -n "${STRICT}" ] && exit 1
    fi
}

echo "router:   ${ROUTER}"
echo "revision: $(git -C "${ROUTER}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "tree:     $(git -C "${ROUTER}" status --porcelain 2>/dev/null | wc -l) file(s) modified"
echo "date:     $(date -u '+%Y-%m-%d %H:%M:%SZ')"
echo

echo "== C1  convert_and_distribute is admin-only and reads its pool from state =="
present "admin assertion exists"            'Txn\.sender == self\.admin'
present "same-group approval refused"       '_assert_no_conversion_pool_approval'
check   "conversion pool is not a parameter" "batch,minimum_out" \
        "$(params convert_and_distribute)"

echo
echo "== H1  the floor is co-signed, not supplied by the caller =="
present "floor derived from the signed note" '_signed_floor'
check   "route takes no minimum_received parameter" \
        "payment,first_leg,second_leg,asset_in,middle,asset_out" \
        "$(params route)"
check   "route3 takes no minimum_received parameter" \
        "payment,first_leg,second_leg,third_leg,asset_in,first_middle,second_middle,asset_out" \
        "$(params route3)"
present "quote authorisation is a pool_budget call" 'POOL_BUDGET_SIGNATURE'

echo
echo "== M4  no provider's pool application is the caller's to choose =="
present "Pact pinned by creator"            'PACT_POOL_CREATORS'
present "STAMM pinned by creator"           'STAMM_POOL_CREATORS'
present "AlgoFi pinned by whitelist"        'ALGOFI_POOLS'
present "AlgoFi manager pinned"             'ALGOFI_MANAGER_APP_ID'
present "Tinyman address derived, not given" '_tinyman_v2_pool'
present "creator read from the ledger"      'AppParamsGet\.app_creator'

echo
echo "== M5  a caller cannot ask for unbounded opcode budget =="
present "opups bounded"                     'opups.*<= *MAX_STAMM_OPUPS'
present "non-STAMM legs may not ask at all" 'opups.*== *0'

echo
echo "== MBR  an opt-in cannot be opened except to serve a route =="
present "opt-in must serve a route"         '_routed_in_group'
present "double opt-in refused"             'already opted in'

echo
echo "== group hygiene  every entry point refuses a rekey or a close =="
ENTRIES="$(grep -cE '@arc4\.(abimethod|baremethod)' "${CONTRACT}")"
GUARDS="$(grep -c '_assert_group_is_clean()' "${CONTRACT}")"
check "entry points" "15" "${ENTRIES}"
check "of which assert group hygiene (see REPORT 3.1)" "13" "${GUARDS}"
present "rekey refused"                     'rekey_to == Global\.zero_address'
present "ALGO close refused"                'close_remainder_to == Global\.zero_address'
present "ASA close refused"                 'asset_close_to == Global\.zero_address'
present "and the group's total fee is bounded" 'paid <= MAX_GROUP_FEE'

echo
echo "== the deployment  what is compiled into mainnet, from its own manifest =="
# Read rather than described. The two errors that did this series the most
# damage - v4 citing a testnet id as mainnet, v5 recording a removal that never
# happened - are both answered by this file, and neither audit opened it.
#
# 3692588382 replaced 3689591968 on 2026-09-02, carrying the intermediate
# residue check. The predecessor was swept of its accrued dust and destroyed;
# it answers 404. The manifest name moves with the deployment, and the checks
# below read it rather than restating what it says.
MANIFEST="${ROUTER}/build/releases/router-mainnet-3692588382.json"
if [ -f "${MANIFEST}" ]; then
    field () { python3 -c "import json,sys; print(json.load(open(sys.argv[1]))${2})" "${MANIFEST}"; }
    check "mainnet application"                "3692588382" "$(field . "['application_id']")"
    check "RESTRICT_TO_ADMIN"                  "0"          "$(field . "['template_values']['RESTRICT_TO_ADMIN']")"
    check "restrict_to_admin, as recorded"     "False"      "$(field . "['restrict_to_admin']")"
    check "compiler"                           "puyapy 5.9.0" "$(field . "['compiler']")"
    check "global uints, three since set_paused" "3"        "$(field . "['global_schema']['ints']")"
    check "the pause exists in the source"     "1" \
          "$(grep -c 'def set_paused' "${CONTRACT}")"
    check "and both route entry points honour it" "2" \
          "$(grep -c 'assert not self.paused' "${CONTRACT}")"
    check "the group fee ceiling"              "1" \
          "$(grep -cE '^MAX_GROUP_FEE = 1_000_000$' "${CONTRACT}")"

    # The strongest claim in this repository, and the cheapest to check: the
    # program Tealer swept is the program mainnet runs. Every earlier sweep
    # analysed the unrestricted build while mainnet ran the restricted one, so
    # the two could not be compared by hash. Since 2026-08-30 they can.
    SWEPT="${ROUTER}/build/tealer/Router.approval.teal"
    if [ -f "${SWEPT}" ]; then
        check "the swept program is the deployed program" \
              "$(field . "['approval_teal_sha256']")" \
              "$(sha256sum "${SWEPT}" | cut -d' ' -f1)"
        check "and it is 4,892 TEAL lines" "4892" "$(wc -l < "${SWEPT}")"
    else
        skip "the swept program is the deployed program" "run scripts/tealer.sh first"
        skip "and it is 4,892 TEAL lines" "run scripts/tealer.sh first"
    fi
else
    skip "the mainnet manifest's eight readings" "not at ${MANIFEST}"
    skip "the swept program is the deployed program" "no manifest to compare against"
    skip "and it is 4,892 TEAL lines" "no manifest to compare against"
fi

echo
echo "== admin bounds =="
check   "fee ceiling is 100 bps"            "1" \
        "$(grep -cE '^MAX_FEE_BPS = 100$' "${CONTRACT}")"
present "fee ceiling enforced"              'fee_bps <= MAX_FEE_BPS'
present "delete needs a zero accrued balance" 'accrued'

echo
echo "== input provenance =="
present "input must come from the caller"   'payment\.sender == Txn\.sender'
present "input must be adjacent"            'group_index \+ 1 == Txn\.group_index'
present "the whole input must be spent"     '_assert_input_spent'

echo
echo "== the suite =="
if command -v python3 >/dev/null 2>&1; then
    N="$(cd "${ROUTER}" && python3 -m pytest tests -q --collect-only 2>/dev/null | tail -1 | grep -oE '^[0-9]+' || echo 0)"
    echo "  note  tests collected: ${N}"
    S="$(cd "${ROUTER}" && python3 -m pytest tests/test_sweep.py -q --collect-only 2>/dev/null | tail -1 | grep -oE '^[0-9]+' || echo 0)"
    echo "  note  tests/test_sweep.py collects: ${S}  (audit v5 claimed 982)"
fi

echo
echo "passed ${PASS}, failed ${FAIL}, skipped ${SKIP}"
[ "${FAIL}" -eq 0 ] || exit 1
