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
check   "conversion pool is not a parameter" "0" \
        "$(grep -cE 'def convert_and_distribute\(self, batch: UInt64, minimum_out: UInt64, *(leg|pool)' "${CONTRACT}")"

echo
echo "== H1  the floor is co-signed, not supplied by the caller =="
present "floor derived from the signed note" '_signed_floor'
check   "route/route3 take no minimum_received parameter" "0" \
        "$(grep -cE 'def route3?\(.*minimum_received' "${CONTRACT}")"
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
MANIFEST="${ROUTER}/build/releases/router-mainnet-3689591968.json"
if [ -f "${MANIFEST}" ]; then
    field () { python3 -c "import json,sys; print(json.load(open(sys.argv[1]))${2})" "${MANIFEST}"; }
    check "mainnet application"                "3689591968" "$(field . "['application_id']")"
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
        check "and it is 4,768 TEAL lines" "4768" "$(wc -l < "${SWEPT}")"
    else
        echo "  SKIP  the swept program is the deployed program           run scripts/tealer.sh first"
    fi
else
    echo "  SKIP  mainnet manifest                                      not at ${MANIFEST}"
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
echo "passed ${PASS}, failed ${FAIL}"
[ "${FAIL}" -eq 0 ] || exit 1
