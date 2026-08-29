# General & AVM Platform Attack Vectors (v5)

This domain analyzes fundamental Algorand Virtual Machine platform vulnerabilities, access controls, state persistence, resource limits, and transaction group mechanics.

---

## Vector Categories & Coverage

| Category File | Focus Area | Verdict |
|---------------|------------|:-------:|
| [reentrancy.md](reentrancy.md) | Cross-transaction group state manipulation, inner call re-entry, and execution phase integrity | **DEFENDED** |
| [group-transactions.md](group-transactions.md) | Rekey attacks, close-remainder-to exploits, group padding, and relative indexing | **DEFENDED** |
| [resource-limits.md](resource-limits.md) | Opcode budget exhaustion, reference limits (apps/assets/boxes), and 16-txn group bounds | **DEFENDED** |
| [deployment.md](deployment.md) | Puya compiler settings, template substitutions, clear-state safety, and application retirement | **DEFENDED** |
| [mbr.md](mbr.md) | Minimum balance draining, opt-in griefing, and float solvency | **DEFENDED** |
| [economic.md](economic.md) | Fee skimming manipulation, discount voucher forging, and treasury conversion drainage | **DEFENDED** |
