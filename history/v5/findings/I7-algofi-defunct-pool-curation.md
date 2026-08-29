# Finding I7: AlgoFi Defunct Pool Whitelist Curation

- **Severity:** Informational
- **Category:** AMM Whitelisting / Upgradability
- **Location:** `contracts/router_app.py:TemplateVar[Bytes]("ALGOFI_POOLS")`
- **Origin:** v3 Audit (2026-08-15)
- **Status (v5):** **ACCEPTED BY DESIGN**

---

## 1. Description
AlgoFi pool applications are hardcoded into an immutable bytecode array of 23 pool IDs.

---

## 2. Evaluation & Verification
Because AlgoFi protocol factories are permanently frozen/defunct, no new genuine AlgoFi pools can be deployed. Hardcoding the 23 verified liquid pools in the contract is optimal and prevents spoofing.
