AI audits provide a solid baseline for catching standard vulnerabilities like overflow errors, basic access control flaws, and missing signature checks. However, when building an AMM router for Algorand in Python, automated tools consistently miss the architectural nuances of the AVM and the composability risks inherent in cross-pool routing.

Here are the critical attack vectors and optimizations you need to manually audit on top of an AI baseline:

### 1. AVM Resource and State Griefing

* **MBR (Minimum Balance Requirement) Draining:** To route trades, the contract often needs to temporarily hold ASAs, which requires an opt-in. If the router automatically opts into any ASA passed in the transaction group, an attacker can route thousands of worthless, unverified ASAs through the contract. This forces the router to pay the 0.1 ALGO MBR per asset, quickly draining its operational ALGO. Ensure the router either requires the caller to cover the MBR, tears down the local state immediately after the swap, or strictly whitelists assets.
* **Opcode Budget Exhaustion:** AI tools rarely calculate dynamic opcode consumption. Multi-hop routes across different protocols (e.g., Tinyman to Pact to Humble) can easily exceed the 700 opcode-per-transaction limit. Verify that the inner transactions correctly pool their opcode budgets and that the total routing path never exceeds the 16-transaction group limit, which would cause sudden execution failures on mainnet.

### 2. Protocol Composability & Input Validation

* **Application ID Spoofing:** A router interacts with external pool contracts. An AI might verify that an inner transaction is well-formed, but it won't check if the target `ApplicationID` is legitimate. An attacker could deploy a malicious contract mimicking an AMM pool and pass its ID to the router, tricking the contract into sending it the user's funds. The router must cryptographically verify that any target pool was deployed by the official factory contract of that specific DEX.
* **Fee Pooling Exploits:** Algorand allows fee pooling across grouped transactions. If the router uses a pooled fee model, ensure it doesn't inadvertently cover the network fees for an attacker's outer, unrelated malicious transactions within the same group.

### 3. Asset Accounting and Precision

* **Dust Accumulation:** Multi-hop swaps inevitably leave behind micro-fractions of ASAs and ALGO inside the router due to rounding math. AI audits generally ignore this. Over thousands of swaps, this accumulated dust can disrupt exact-amount-out routing logic or become a target for sweep attacks. Implement a secure, admin-only sweep function or ensure the logic forwards all remaining fractional dust to the caller at the end of the group execution.
* **Inner Transaction Isolation:** When the router issues an inner `AssetTransfer` transaction, verify that the `Amount` and `AssetReceiver` fields are strictly isolated to the router's current swap step. AI struggles to trace state changes across deeply nested inner transactions, especially when interacting with protocols that might temporarily update global state before the final payout.