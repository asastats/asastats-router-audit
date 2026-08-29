# Attack Vector Analysis Matrix (v5)

This directory contains the exhaustive 161-vector security analysis matrix for the ASA Stats Smart Router, organized into dedicated functional domains.

---

## Attack Vector Domains

| Domain | Subdirectory | Vectors Analyzed | Key Focus |
|--------|--------------|:----------------:|-----------|
| **General & AVM Platform** | [`general/`](general/) | 45 | Rekeying, group layout, MBR draining, opcode exhaustion, reentrancy-analogue, deployment integrity |
| **Route & Aggregator Logic**| [`route/`](route/) | 42 | Multi-hop atomicity, slippage floor authentication, value conservation, path validation, cycling |
| **Provider Integrations** | [`provider/`](provider/) | 46 | Pool spoofing, LogicSig derivations, creator pins, array indexing, tier splits |
| **Pact MWPT Integration** | [`pact/`](pact/) | 28 | Weighted curve math, dynamic vault resolution, reserve query safety, asymmetric weights |
| **Total Attack Vectors** | | **161** | **Exhaustive coverage** |
