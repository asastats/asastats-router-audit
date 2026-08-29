**The LiquiHog STAMM AI audit (Claude Opus 4.6 multi-agent system analyzing 121 attack vectors) is a strong, systematic baseline focused on their multi-tier constant-product AMM pools (plus admin, factory, and registry).** It thoroughly covers mathematical correctness (128-bit arithmetic, K-invariant enforcement with fees, square roots, spill redistribution), state integrity vs. actual balances, input validation (rekey/close-to-zero, sender/asset consistency), access control, economic vectors (donation, flash-loan style, sandwich—note Algorand consensus reduces the latter), Algorand edge cases (ALGO min-balance, inner transactions), and their internal smart-routing across tiers. Verdict was no critical/high issues that could lose user funds; the 4 medium findings (strict K-comparison, hook DoS/invalid ID, seed-tier rate) were mitigated by design or admin-controlled.

Your contract is a **cross-AMM aggregator/router** (similar to Folks Finance, Haystack/Deflex, Vestige, LiquiHog-style routers, or Pact’s router). It interacts with *external* pools from multiple protocols rather than primarily managing its own stratified liquidity. This introduces additional surfaces the STAMM audit (which focused on self-contained pool + internal routing) does not fully stress. Below are concrete improvements and extra checks you can implement on top of that methodology.

### 1. Expand the Attack-Vector Matrix for Aggregator/Router Semantics
STAMM’s 121 vectors are excellent for a pool. For a router, systematically add (and document verdicts for) categories such as:

- **Path / route validation and manipulation**: Arbitrary or malicious pool addresses, circular paths, routes through unvetted/low-liquidity/attacker-controlled pools, factory-derived vs. user-supplied addresses. Never trust externally supplied pool IDs without verifying against known factories or a controlled registry.
- **Multi-hop / multi-leg correctness**: Intermediate amount calculations, cumulative slippage, fee accumulation across heterogeneous pools (different fee tiers, decimals, invariants), exact-in vs. exact-out consistency, and funds conservation (user input − fees ≈ final output, accounting for dust).
- **External call / inner-transaction risks**: Correct construction of application calls or asset transfers into foreign pools; validation of foreign apps/assets/accounts arrays; what happens if an external pool reverts, returns unexpected amounts, or has its own bugs.
- **Temporary fund holding**: Router should not lock user funds; pull vs. push patterns; dust or residual balances after failed multi-leg routes.
- **DoS via resource limits**: Opcode budget exhaustion on long routes, box/local-state growth, MBR manipulation that bricks the router account (a real finding in Deflex-related work), or repeated failed legs.

Cross-reference every vector against Algorand’s atomic groups and the fact that external pools are untrusted black boxes.

### 2. Algorand Platform-Specific Hardening Beyond STAMM Coverage
Draw from Trail of Bits “Not So Smart Contracts” (Algorand section), official guidelines, and the Algorand DevRel security best-practices guide:

- Explicit `GroupSize` / relative indexing (or ABI-typed `gtxn` parameters) to prevent padding/replay of legs.
- Inner-transaction fees forced to 0 (or carefully bounded); never expose controllable fees that drain the router.
- Strict `RekeyTo`, `CloseRemainderTo`, `AssetCloseTo` == zero on relevant transactions; never allow them on the router account.
- Asset-ID checks on *every* transfer (not just the outer ones).
- Full `OnComplete` handling (especially UpdateApplication / DeleteApplication blocked or strictly gated; ClearState program must not leave funds claimable insecurely).
- Foreign-array validation and opt-in checks for every asset/pool involved.
- Dynamic min-balance checks (`app.minBalance`) rather than hard-coded constants; ensure the router itself cannot be griefed into insolvency.
- Compiler pinning + known-bug review: Puya/PyTEAL ABI encoding length validation, missing-assert optimizations, and ARC-4 argument checks. Test both optimized and unoptimized builds.

These are partially covered in STAMM but become higher priority when the contract repeatedly calls external apps.

### 3. Arithmetic, Precision, and Invariant Checks for Cross-Pool Routing
STAMM’s 128-bit / invariant work is strong for a single stratified pool. Extend it:

- Multiplicative overflow / underflow / precision loss across hops with differing decimals or fee models.
- Explicit intermediate bounds and post-condition asserts after every leg (amount received ≥ expected, reserves still consistent if the router reads them).
- Edge cases: zero-liquidity pools, one-sided reserves, maximum `uint64` amounts, dust accumulation across many legs.
- Use `BigUint` (or equivalent) for intermediate products where needed; prove (semi-formally) that key quantities stay in safe ranges.

### 4. Economic / MEV / Availability Vectors Specific to Aggregators
- Slippage (`amountOutMin` / `amountInMax`) and deadline enforcement on the outer call *and* per-leg if feasible.
- Route selection if any is performed on-chain (spot-price manipulation risk, even if Algorand reduces classic sandwiching).
- Temporary balance donation or dust attacks that affect subsequent routing decisions or accounting.
- Availability: a single malicious or drained external pool must not permanently brick the whole router (fallback, partial-fill, or clean abort with refunds).

### 5. Process and Methodology Improvements on Top of Pure AI Audit
The STAMM audit itself documents limitations of AI-only work. Strengthen yours by:

- **Human expert review** by Algorand-experienced auditors (Runtime Verification audited Pact’s router; Vantage Point has Deflex/Folks work; others appear in the Algorand ecosystem audit collection). AI is excellent for exhaustive vector coverage and math; humans catch design-level assumptions about external pools and subtle economic interactions.
- **Property-based / fuzz testing** and scenario simulation against real mainnet pool states (or high-fidelity forks). Cover extreme liquidity, concurrent routes, and adversarial path construction.
- **Formal or semi-formal invariants**: “User funds in = user funds out + protocol fees + dust (non-negative)” and “router balance never decreases unexpectedly.”
- **Bytecode verification**: After any compilation, confirm the deployed TEAL matches the audited source; pin compiler versions and re-check after Puya/PyTEAL security bulletins.
- **Integration test matrix** against every supported AMM interface (Tinyman, Pact, Folks, etc.) including their failure modes.
- **Bug bounty** and continuous monitoring post-deployment.
- Explicit scope document (like STAMM’s) that lists *excluded* items (off-chain routing logic, front-end, specific external pool implementations) and residual risks.

### 6. Practical Checklist You Can Apply Immediately
- Inventory every external call site and write an attack vector for “what if this pool returns X / reverts / is malicious.”
- Add post-condition asserts after every leg and at the end of the route.
- Enforce factory-derived or whitelist-checked pool addresses.
- Audit the clear-state and any admin paths for residual balances.
- Measure opcode cost of the longest realistic route and leave headroom.
- Review temporary holding of assets inside the router account (prefer pure pass-through where possible).
- Cross-check against the full Trail of Bits Algorand patterns + the DevRel best-practices guide (access control, group security, arithmetic safety, updatability, ASA config, etc.).

The STAMM AI audit is a high-quality public example of systematic coverage for an AMM. Treating your router as an *aggregator of untrusted external contracts* and layering the above router-specific vectors, Algorand platform checks, multi-hop arithmetic rigor, and a hybrid AI+human+testing process will surface the residual risks that pure pool-centric analysis can miss. If you share more details about your router’s interface (how routes are supplied, which AMMs, whether it holds intermediate balances, language/compiler used), the vector list can be refined further.

-----

**Formal verification of multi-hop invariants** is a high-value addition for an Algorand AMM aggregator/router. It goes beyond the STAMM-style AI audit (which focused on single-pool math and internal tier routing) by mathematically proving properties that must hold across an arbitrary (or bounded) sequence of external pool interactions.

### Core Multi-Hop Invariants to Target
For a router that executes paths of the form  
`TokenA → Pool1 → TokenB → Pool2 → … → TokenZ`:

1. **Funds conservation (global)**  
   \[
   \text{input amount (normalized)} = \text{final output} + \sum \text{protocol/pool fees} + \text{residual dust} \geq 0
   \]
   The router’s net balance change for every asset is exactly accounted for; it never retains user funds unexpectedly and never creates value.

2. **Per-hop conservation**  
   Amount received from hop \(i\) (after pool fees and rounding) equals the amount sent into hop \(i+1\) (modulo any intermediate transfers or dust).

3. **Slippage / minimum-output**  
   If the path is valid and each leg respects its local constraints, then  
   \(\text{final amountOut} \geq \text{minAmountOut}\) (user-supplied).

4. **No overflow / underflow / precision loss**  
   All intermediate multiplications, divisions, and fee calculations stay within `uint64` (or are safely lifted to wider arithmetic) for every reachable hop sequence.

5. **Path validity implies safety**  
   Only factory-derived or whitelist-checked pools are callable; circular or malicious paths are rejected before any transfer.

6. **Router account safety**  
   After any successful or reverting multi-hop execution, the router’s ALGO and ASA balances satisfy its minimum-balance requirement and contain no unclaimed user assets.

These are the natural extensions of the single-pool K-invariant and fee-split proofs that appeared in the STAMM audit.

### Practical Approaches on Algorand

**1. Semi-formal / manual inductive proof (recommended starting point)**  
Algorand’s own guidelines explicitly advise this for arithmetic-heavy contracts: write the invariants as mathematical statements and prove them by induction on the number of hops (or on the length of the atomic group).  

- Base case: 0- or 1-hop (direct transfer or single pool).  
- Inductive step: assume conservation holds after \(k\) hops; show the \((k+1)\)-st inner transaction (or group leg) preserves it, accounting for the external pool’s own (assumed) constant-product or stableswap math, fees, and rounding.  
- Bound the maximum hops (common practice is 3–6) so the induction stays manageable.  

This is exactly the style used for the original TinyMan overflow analysis and is inexpensive yet highly effective.

**2. KAVM (Runtime Verification’s K-framework semantics)**  
KAVM provides an executable formal semantics of the Algorand Virtual Machine / TEAL.  

- Annotate PyTEAL (or Puya) methods with preconditions and postconditions that encode the multi-hop invariants.  
- Use concrete execution (`kavm run`) for testing and, where supported, symbolic execution / `kprove` for proof obligations.  
- Integrates with `py-algorand-sdk` and AlgoKit; you can model an entire transaction group containing the router call + the sequence of pool calls.  

It is the most mature production-oriented tool for Algorand contracts today. Runtime Verification has already applied related techniques to Pact’s router and other Algorand AMMs.

**3. High-level modeling in a theorem prover + refinement**  
- Formalize the *ideal* multi-hop router (and the individual pool math) in Lean 4, Coq, or Isabelle. There are existing Lean 4 formalizations of constant-product AMMs that already prove arbitrage and conservation properties; extend them to a sequence of pools.  
- Prove the invariants at the mathematical level.  
- Then show (by hand or with a refinement proof) that your TEAL/PyTEAL/Puya implementation refines the model, or that every reachable TEAL state satisfies the same predicates.  

Academic work (Bartoletti et al.) supplies a formal model of Algorand contracts that can serve as a starting point; AlgoMove demonstrates a similar “high-level language → TEAL with soundness proof” approach.

**4. Bounded SMT / symbolic execution**  
Encode the arithmetic and control-flow of a fixed maximum number of hops as SMT formulas (Z3, CVC5). Assert the negation of each invariant and check unsatisfiability. This works well when the hop bound is small and the external pools are modeled by their mathematical invariants rather than full TEAL.

**5. Hybrid with runtime assertions and fuzzing**  
Even without a full machine-checked proof, embed the invariants as `Assert` statements after every leg and at the end of the route. Combine with property-based testing (or KAVM concrete runs) against real mainnet pool states. This catches violations early and serves as executable documentation of the formal claims.

### Suggested Workflow for Your Router
1. Write the invariants in precise mathematical English (or as Lean/Coq statements).  
2. Prove them semi-formally by induction on hop count, carefully handling Algorand-specific details (atomic groups, inner-transaction fees = 0, asset decimals, `uint64` wrapping, min-balance).  
3. Encode the same claims as post-conditions in KAVM (or as runtime asserts).  
4. For the highest assurance, engage Runtime Verification (or another team experienced with KAVM / Algorand formal methods) to discharge the remaining proof obligations or to audit the model-to-code correspondence.  
5. Keep the maximum hop count low and documented; re-verify if you later raise it.

Formal verification will not replace a thorough human + AI audit, but it gives machine-checkable guarantees precisely where multi-hop aggregators are most fragile: conservation of value across untrusted external contracts. If you share the concrete language (PyTEAL / Puya / Tealish), the maximum hop bound, and how routes are supplied (on-chain vs. off-chain path encoding), more targeted encoding examples or KAVM claim sketches can be provided.

-----

**KAVM multi-hop proof examples** are limited in the public materials. Full symbolic proving (`kavm prove` / `kprove` with the Haskell backend) is still marked as work-in-progress in the main [avm-semantics](https://github.com/runtimeverification/avm-semantics) repository—specifications exist under `tests/specs/` but are not fully ported and currently fail. Concrete execution and claim-based verification (via the Python/PyTEAL interface) are functional and were demonstrated in the 2023 public beta.

The best available public example is the **K Coin Vault** demo from Runtime Verification (repository: [runtimeverification/kavm-demo](https://github.com/runtimeverification/kavm-demo)). It shows exactly how to attach preconditions and postconditions to PyTEAL methods so KAVM can check arithmetic invariants symbolically. This style can be adapted to multi-hop router conservation properties.

### Real Existing Example: K Coin Vault (Arithmetic Invariants)

The vault lets users mint K-coins against ALGO payments and burn them back. KAVM caught a classic integer-division ordering bug.

Decorators on the methods (simplified from the blog tutorial):

```python
@router.method
@router.precondition(expr='payment.get().amount() >= Int(10000)')
@router.precondition(expr='payment.get().amount() <= Int(20000)')
@router.postcondition(expr=f'output.get() == payment.get().amount() * Int({INITIAL_EXCHANGE_RATE}) / Int({SCALING_FACTOR})')
@router.hoare_method
def mint(payment: abi.PaymentTransaction, *, output: abi.Uint64) -> Expr:
    # implementation...

@router.method
@router.precondition(expr='asset_transfer.get().amount() >= Int(10000)')
@router.precondition(expr='asset_transfer.get().amount() <= Int(20000)')
@router.postcondition(expr=f'output.get() == asset_transfer.get().amount() * Int({SCALING_FACTOR}) / Int({INITIAL_EXCHANGE_RATE})')
@router.hoare_method
def burn(asset_transfer: abi.AssetTransferTransaction, *, output: abi.Uint64) -> Expr:
    # implementation...
```

Verification commands:

```bash
poetry run kavm-demo verify --verbose \
  --pyteal-code-file kcoin_vault/kcoin_vault_pyteal.py --method mint

poetry run kavm-demo verify --verbose \
  --pyteal-code-file kcoin_vault/kcoin_vault_pyteal.py --method burn
```

- `mint` passed.
- `burn` failed because the implementation did `amount / rate * scale` (integer division truncated early) while the postcondition required `amount * scale / rate`. KAVM produced a symbolic counter-example showing the two expressions are not equal under the preconditions.

After fixing the order of operations, both methods verified successfully. Simulation mode (`kavm-demo simulate`) can also replay concrete multi-call sequences to confirm the same properties.

This demonstrates the core workflow:  
**preconditions** constrain inputs → **postconditions** encode the desired invariant → KAVM checks that every feasible path satisfies the postcondition (or returns a counter-example).

### Adapting the Style to Multi-Hop Router Invariants

No public multi-hop router proofs exist yet, but the same decorator pattern works for a bounded-hop aggregator. You would annotate the top-level `swap` / `exactInput` / `exactOutput` method (and any internal leg helpers) with claims that capture the conservation properties discussed earlier.

Illustrative sketch (PyTEAL-style, not copy-paste ready):

```python
# Assume a method that accepts a path (list of pool app IDs + assets) 
# and executes up to MAX_HOPS legs via inner transactions / group.

MAX_HOPS = 3   # keep the bound small for tractability

@router.method
@router.precondition(expr='input_amount.get() > Int(0)')
@router.precondition(expr='path_length.get() >= Int(1)')
@router.precondition(expr='path_length.get() <= Int(MAX_HOPS)')
@router.precondition(expr='min_amount_out.get() >= Int(0)')
# Additional preconditions: each pool ID is from a known factory, 
# assets are opted-in, group size is correct, RekeyTo/CloseTo are zero, etc.

@router.postcondition(
    # Global conservation (normalized for decimals/fees)
    expr='''
    final_amount_out.get() + total_fees_collected.get() + residual_dust.get() 
    == input_amount.get()
    '''
)
@router.postcondition(
    # Slippage guarantee
    expr='final_amount_out.get() >= min_amount_out.get()'
)
@router.postcondition(
    # Router does not retain user funds
    expr='router_balance_delta.get() == Int(0)'   # or == -fees if fees stay in router
)
@router.hoare_method
def multi_hop_swap(
    input_amount: abi.Uint64,
    path: abi.DynamicArray[abi.Uint64],   # pool app IDs or encoded legs
    min_amount_out: abi.Uint64,
    *, 
    final_amount_out: abi.Uint64
) -> Expr:
    # ... construct inner calls / group for each leg ...
    # After each leg you can also assert local conservation:
    #   amount_received_from_leg_i == amount_sent_to_leg_i+1
```

For stronger inductive reasoning you can factor the legs into a helper and prove a per-leg lemma, then compose:

- Base: 1-hop conservation (mirrors the vault example).  
- Inductive step: if conservation holds after \(k\) hops, the next inner call (modeled as an external pool with its own K-invariant or fee formula) preserves it.

Because full symbolic multi-leg proofs are still limited, the practical path today is:

1. Write the claims exactly as above.
2. Use **concrete simulation** of realistic multi-hop groups (with real or mocked pool TEAL) via `kavm run` / the demo simulator.
3. Use the claim-checking mode on the top-level method for the arithmetic/fee parts that *are* supported.
4. For the remaining obligations (especially interactions with external untrusted pools), fall back to semi-formal induction + human audit, or engage Runtime Verification for a custom K-level specification.

### Current Practical Advice
- Start from the [kavm-demo](https://github.com/runtimeverification/kavm-demo) repository; it is the only public end-to-end example of the decorator + verify workflow.
- Keep hop bounds low (≤3–4) so the state space stays manageable.
- Explicitly model only the router’s own arithmetic and the *interface* of external pools (amount-in → amount-out + fee), not the full internal TEAL of every AMM.
- Combine with the semi-formal inductive proofs recommended in the Algorand developer guidelines for the parts KAVM cannot yet fully discharge.

If you share a concrete PyTEAL/Puya skeleton of your multi-hop entry point (or the maximum hop count and how paths are encoded), a more precise set of claim annotations can be sketched. For production-strength multi-hop proofs you will likely still need direct engagement with the Runtime Verification team, as the open-source symbolic backend remains incomplete.

-----

**ARC-4** (Application Binary Interface) is the standard that defines how Algorand smart contracts expose methods, encode arguments and return values, and interact with clients/wallets. Strict adherence is required by Algorand’s security guidelines. The main security risks center on **encoding validation**, type safety, method selectors, and interaction with transaction groups / OnComplete actions.

### 1. Core Encoding Validation Risks (Highest Priority)
Invalid or maliciously crafted ARC-4 encodings can cause panics, memory overwrites, or logic errors. This was the subject of a formal security bulletin (Puya compiler issues, October 2025).

**Fixed-length types** (e.g., `StaticArray[Byte, 32]`, `byte[32]`, fixed tuples):
- Must be exactly the expected length.
- Longer values can overflow into adjacent data (e.g., overwrite a subsequent constant or another field in a tuple).
- Shorter values can cause under-reads or incorrect offsets.

**Dynamic arrays** (`byte[]`, `uint64[]`, etc.):
- Prefixed with a 16-bit big-endian length.
- Mismatched length prefix vs. actual data → out-of-bounds access (AVM panic) or incomplete validation of elements.

**Dynamic tuples / structs**:
- Use head/tail encoding with offsets. Incorrect offsets can point into the wrong data or beyond the buffer.

**Affected languages & mitigations**:
- **PuyaPy / Algorand Python**: Validation added by default in ≥ 5.3.2 (and 4.11.0+). Older versions were vulnerable.
- **Puya-TS / Algorand TypeScript**: Fixed in later alphas/betas; update the compiler.
- **PyTEAL**: No automatic validation — you must add manual length/offset checks.
- TEALScript / Tealish have partial or no automatic checks.

**Secure pattern**:
```python
# Puya / Algorand Python (preferred — validation is on by default)
@abimethod  # or @arc4.abimethod
def swap(self, amount: arc4.UInt64, path: arc4.DynamicArray[arc4.Address]) -> arc4.UInt64:
    # Compiler inserts length checks for path
    ...

# Explicit control (rarely needed)
@abimethod(validate_encoding="unsafe_disabled")  # only for trusted internal data
```

For PyTEAL or manual TEAL, explicitly assert:
- `Len(arg) == expected_fixed_size`
- For dynamic arrays: length prefix matches actual element count and each element is well-formed.

Never disable validation (`validate_encoding="unsafe_disabled"` or equivalent flags) for **untrusted external callers**.

### 2. Method Selectors and Routing
- Method selectors are the first 4 bytes of `SHA512/256("method_name(arg_types)return_type")`.
- Always route on the selector first; reject unknown selectors.
- Bare calls (no arguments / empty ApplicationArgs) should be explicitly handled or rejected for sensitive OnComplete actions.
- ClearState is especially dangerous: the contract is incentivized never to fail, so never rely on the presence or validity of ABI arguments during ClearState.

**Pattern**:
```python
# Router / method dispatcher should reject unknown selectors
# and handle OnComplete separately from ABI methods
```

### 3. Transaction Group & Composability Patterns
ARC-4 methods frequently expect specific foreign transactions (payments, asset transfers, other app calls) in the same atomic group.

**Security patterns**:
- Prefer **typed ABI parameters** (e.g., `gtxn.PaymentTransaction` / `abi.PaymentTransaction`) over hard-coded group indexes. This avoids double-counting the same payment and improves composability.
- Never assume a fixed `GroupSize` if you want composability; instead validate relative positioning or use ABI-relative references.
- Explicitly check `RekeyTo`, `CloseRemainderTo`, `AssetCloseTo` == zero address on relevant transactions.
- Validate asset IDs, amounts, receivers, and senders of every referenced transaction.
- For multi-hop routers: validate the entire path (pool app IDs, asset order) before any inner calls.

### 4. Read-Only Methods (ARC-22)
Mark pure view methods with the `readonly` flag (ARC-22). They must not:
- Modify global/local state or boxes
- Issue inner transactions
- Call non-readonly methods

This enables safer off-chain simulation and clearer client expectations.

### 5. Return Values and Events
- Return values follow the same encoding rules as arguments — validate them when reading results from inner app calls.
- Events (ARC-28) reuse ARC-4 encoding + a 4-byte selector. Do not emit an event after logging a return value in the same method.

### 6. Practical Checklist for Router / Aggregator Contracts
- Pin a compiler version that includes ARC-4 encoding validation (Puya ≥ 5.3.2).
- Keep validation enabled for all externally callable methods.
- Manually validate any ABI data coming from inner calls to external pools if the compiler does not do so automatically.
- Use ARC-4 method signatures consistently so clients and explorers can decode calls correctly.
- Handle every `OnComplete` action explicitly (especially UpdateApplication, DeleteApplication, ClearState).
- Prefer high-level typed parameters over raw `ApplicationArgs` indexing.
- Document the exact ABI interface (ARC-32 / ARC-56 application specs are generated automatically by modern compilers).

### References
- Official ARC-4: [ARC-0004](https://github.com/algorandfoundation/ARCs/blob/main/ARCs/arc-0004.md)
- Encoding security details: Algorand Developer Portal ABI page + Puya security bulletin `001-arc4-encoding.md`
- Guidelines: “Strictly follow ARC-4” in the modern smart-contract security guidelines

For a multi-hop AMM router, the highest-impact ARC-4 patterns are **strict encoding validation on path/amount arguments** and **typed transaction references for each leg**. These prevent both client-side encoding mistakes and malicious overflows that could corrupt intermediate state or bypass slippage checks. If you share the language (Puya / PyTEAL / etc.) and a sample method signature, more concrete validation code can be provided.
