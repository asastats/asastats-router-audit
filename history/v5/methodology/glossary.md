# Smart Router Audit Glossary (v5)

| Term | Definition in this Codebase |
|------|-----------------------------|
| **AVM** | Algorand Virtual Machine; the execution runtime executing TEAL bytecode. |
| **ARC-4** | Algorand standard Application Binary Interface (ABI) defining method selectors, argument encoding, and return logs. |
| **Atomic Group** | A collection of 2 to 16 transactions executed as a single all-or-nothing unit by Algorand consensus. |
| **Inner Transaction (`itxn`)** | A transaction issued directly by a smart contract from its own account during execution. |
| **MBR** | Minimum Balance Requirement; the base ALGO required to hold an account or ASA opt-in (0.1 ALGO per asset). |
| **Pact MWPT** | Managed Weighted Pool on Pact DEX; multi-token pool where reserves reside in a shared Vault contract. |
| **STAMM** | Stratified Tiered Automated Market Maker; AMM featuring multiple fee/liquidity tiers and notification hubs. |
| **Tinyman v2** | Constant-product AMM using stateless logic signature contracts as individual pool accounts. |
| **AlgoFi** | Defunct constant-product AMM protocol whose remaining liquid pools are curated and routed through a whitelist. |
| **Quote Signer** | The trusted backend key that co-signs the slippage floor note attached to the terminating `pool_budget` transaction. |
| **Voucher Signer** | The backend key authorizing fee discount percentages for qualified callers. |
| **Float** | The operational ALGO balance held by the router application to temporarily fund MBRs during swaps. |
| **Accrued Fees** | Accumulated protocol revenue in ALGO held in `self.accrued` awaiting batched conversion to ASASTATS. |
| **Dust Sweep** | The portfolio management subsystem that classifies and clears zero-balance, forfeit-eligible, or convertible assets. |
