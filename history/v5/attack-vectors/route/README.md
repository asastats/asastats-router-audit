# Route & Aggregator Attack Vectors (v5)

This domain analyzes multi-hop route safety, slippage protection, path sanitization, intermediate asset handling, and funds conservation.

---

## Vector Categories & Coverage

| Category File | Focus Area | Verdict |
|---------------|------------|:-------:|
| [slippage.md](slippage.md) | Co-signed floor note verification, sandwiching mitigation, and price impact bounds | **DEFENDED** |
| [mhop.md](mhop.md) | Multi-hop atomicity, intermediate asset wiring, and balance delta chaining | **DEFENDED** |
| [path-validation.md](path-validation.md) | Route cycles, duplicate assets, and endpoint validation | **DEFENDED** |
| [conservation.md](conservation.md) | Global funds conservation, pre-held asset protection, and dust sweep handling | **DEFENDED** |
