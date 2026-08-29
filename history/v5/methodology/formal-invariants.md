# Formal Multi-Hop Invariants & Proof Sketches (v5)

This document formalizes the multi-hop mathematical invariants enforced by the ASA Stats Smart Router across arbitrary execution paths.

---

## 1. Multi-Hop Value Conservation (Global Invariant)

### Theorem 1 (Funds Conservation)
For any valid multi-hop swap route $R = (L_1, L_2, \dots, L_k)$ where input amount $A_{\text{in}}$ of asset $T_{\text{in}}$ is deposited:

$$\text{UserReceived}(T_{\text{out}}) + \text{SkimFee}_{\text{ALGO}} + \sum_{i=1}^k \text{PoolFee}_i + \text{Dust} = A_{\text{in}} \cdot \prod_{i=1}^k \text{EffectiveRate}(L_i)$$

And the router's net balance change for all non-fee assets is strictly zero:
$$\forall T \neq \text{ALGO}, \quad \Delta \text{RouterBalance}(T) = 0$$
$$\Delta \text{RouterBalance}(\text{ALGO}) = \text{SkimFee}_{\text{ALGO}} = \Delta \text{accrued}$$

### Proof Sketch (Induction on Hop Count $k$):
1. **Base Case ($k=1$):** Single hop executes via `_swap_leg`. Input $A_{\text{in}}$ is transferred to verified pool escrow. Router measures $\Delta \text{Held}(T_{\text{out}}) = \text{Held}_{\text{after}} - \text{Held}_{\text{before}}$. If $T_{\text{in}} \neq 0$, `_assert_input_spent` proves $\text{Held}(T_{\text{in}}) = \text{Held}_{\text{initial}} - A_{\text{in}}$. Payout transfers $\Delta \text{Held}(T_{\text{out}})$ to caller, closing holding if opened in group. Net router delta is 0.
2. **Inductive Step ($k \to k+1$):** Assume conservation holds for $k$ hops. At hop $k+1$, input to leg $k+1$ is exactly the realised output delta of leg $k$ ($\text{carried} = \Delta \text{Held}_k$). Because inner fees are hardcoded to 0, no intermediate value leaks. Skim is subtracted at most once on ALGO intermediate. Output of leg $k+1$ is measured as $\Delta \text{Held}_{k+1}$ and forwarded to caller. Thus, conservation holds for $k+1$ hops. $\blacksquare$

---

## 2. Slippage & Floor Guarantee (Local & Global)

### Theorem 2 (Floor Enforcement)
For any transaction group containing $M$ route calls asserting floor $F_{\text{signed}}$:

$$\sum_{j=1}^M \text{RealisedOutput}_j \ge F_{\text{signed}}$$

### Proof Sketch:
1. `_signed_floor` parses the note of the terminating `pool_budget()` transaction signed by `quote_signer`.
2. The note commits to the caller address, current application ID, output asset ID, and per-index input amounts.
3. The designated asserting route call invokes `_group_paid()`, which reads the ARC-4 return logs from all prior route calls in the group and adds its own realised output.
4. If the sum is strictly less than $F_{\text{signed}}$, the contract triggers an AVM `assert` failure.
5. In Algorand consensus, an assertion failure in any inner or outer transaction rolls back the entire atomic group. Therefore, no trade can execute below $F_{\text{signed}}$. $\blacksquare$

---

## 3. Transient MBR Neutrality

### Theorem 3 (Zero Float Drain)
Let $S_{\text{open}}$ be the set of ASA holdings opened by the router during transaction group $G$. At the completion of $G$:

$$|S_{\text{surviving}}| = 0 \implies \Delta \text{MBR}_{\text{router}} = 0$$

### Proof Sketch:
1. When `_open_holding(asset)` executes for an asset not previously held, it issues an inner asset opt-in with `fee=0`, increasing router MBR by 0.1 ALGO.
2. The subroutine marks the asset as transiently opened (`_opened_in_group`).
3. During payout / settlement, `_pay_out` sets `AssetCloseTo = Txn.sender` (or router close-out if empty), closing the ASA holding and returning the 0.1 ALGO MBR to the router account.
4. Because all inner transactions use `fee=0`, the router's spendable ALGO balance at group termination equals its initial balance plus any accrued skim fees. $\blacksquare$
