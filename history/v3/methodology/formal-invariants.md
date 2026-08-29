# Mathematical Invariant Modeling & Semi-Formal Proofs

## 1. Multi-Hop Formal Invariants

Let a multi-hop swap route through $N$ hops be denoted as:
$$T_0 \xrightarrow{\text{Leg}_1} T_1 \xrightarrow{\text{Leg}_2} T_2 \dots \xrightarrow{\text{Leg}_N} T_N$$
where $T_0$ is the input asset, $T_N$ is the output asset, and $T_1, \dots, T_{N-1}$ are intermediate assets ($N \in \{2, 3\}$).

---

### Invariant 1: Global Conservation of Value
**Formal Statement:**
For any executed swap with user input $A_{\text{in}} > 0$:
$$A_{\text{out}} + \Phi_{\text{platform}} + \sum_{k=1}^N \Phi_{\text{pool}, k} \le \text{Value}(A_{\text{in}})$$
where:
- $A_{\text{out}}$ is the realized tokens delivered to the caller.
- $\Phi_{\text{platform}}$ is the fee skimmed in ALGO by the router (`self.accrued`).
- $\Phi_{\text{pool}, k}$ are the legitimate swap fees taken by the respective AMM pools.
- No value is created out of nothing ($A_{\text{out}} \le \prod f_k(A_{\text{in}})$ where each pool transfer function $f_k$ is monotonically bounded by its constant-product or stableswap invariant).

**Proof Sketch:**
Each inner swap leg is fixed-input:
1. For Leg 1: Router deposits $A_{\text{in}}$ into Pool 1. By pool invariant $k_1$, Pool 1 transfers $\Delta B_1 = f_1(A_{\text{in}})$ of $T_1$ to the router.
2. If $T_1 = \text{ALGO}$, router computes:
   $$\text{Fee} = \lfloor \Delta B_1 \times \text{fee\_bps} / 10000 \rfloor - \lfloor \text{Fee} \times \text{discount} / 100 \rfloor$$
   $$\text{Carried}_1 = \Delta B_1 - \text{Fee}$$
   and $\text{self.accrued} \leftarrow \text{self.accrued} + \text{Fee}$.
3. For Leg 2: Router deposits $\text{Carried}_1$ into Pool 2. Pool 2 transfers $\Delta B_2 = f_2(\text{Carried}_1)$ to the router.
4. If $N = 3$, Leg 3 receives $\text{Carried}_2$ and produces $\Delta B_3 = f_3(\text{Carried}_2)$.
5. Payout transfers exactly $\Delta B_N$ to `Txn.sender`.
Since each leg is measured strictly as $\text{Balance}_{\text{after}} - \text{Balance}_{\text{before}}$, intermediate funds cannot be diverted or duplicated.

---

### Invariant 2: Router Balance Neutrality
**Formal Statement:**
Let $S_{\text{start}}$ and $S_{\text{end}}$ denote the contract's asset holding state before and after the execution of any `route` or `route3` call.
For all assets $A \neq \text{ALGO}$:
$$\Delta \text{Balance}_{\text{router}}(A) = 0$$
For $\text{ALGO}$:
$$\Delta \text{Balance}_{\text{router}}(\text{ALGO}) = \Phi_{\text{platform}}$$

**Proof Sketch:**
1. **Input Asset ($T_0$):**
   - If $T_0 \neq \text{ALGO}$:
     - If holding was opened in the group: `_opened_in_group(T_0)` is true. `_assert_input_spent` verifies $\text{Balance}_{\text{after}} = \text{Balance}_{\text{before}} - A_{\text{in}}$. Then line 2005/2133 closes the holding with `asset_close_to=Txn.sender`, releasing the holding to zero balance and returning the 0.1 ALGO MBR.
     - If holding was already open: `_assert_input_spent` ensures net balance delta is exactly zero.
2. **Intermediate Asset ($T_1, T_2$):**
   - If intermediate is opened in route (`carrying == True`): `_swap_leg(Leg 2)` consumes the intermediate. Line 1989/2112 asserts $\text{self.\_held}(T_{\text{int}}) == 0$, and closes the holding to `Txn.sender`, returning the MBR.
3. **Output Asset ($T_N$):**
   - If $T_N \neq \text{ALGO}$: `_pay_out(Txn.sender, T_N, received, close=opened)` transfers the full amount `received` and closes the holding if it was opened in this call.
4. **ALGO Intermediate:**
   - When ALGO is intermediate, `_skim` extracts $\Phi_{\text{platform}}$ and adds it to `self.accrued`. The remaining balance is deposited into the next leg or paid out. The net ALGO change of the router account equals exactly $\Phi_{\text{platform}}$.

Thus, the router retains no caller assets and zero stray inventory.

---

### Invariant 3: Slippage Protection & Quoted Floor Bound
**Formal Statement:**
If a transaction group containing a set of route calls $R = \{r_1, r_2, \dots, r_m\}$ executes successfully:
$$\sum_{r \in R} \text{RealizedOutput}(r) \ge \text{QuotedMinimumOut}$$
where $\text{QuotedMinimumOut}$ is authenticated by the quote signer's key.

**Proof Sketch:**
1. `_signed_floor` extracts $\text{QuotedMinimumOut}$ from the note at group index $G-1$.
2. The note is signed by `self.quote_signer` and binds `Global.current_application_id`, `Txn.sender`, `asset_out`, and the exact input amount $A_{\text{in}}$ at the call's group index.
3. `asserting = op.extract_uint64(note, FLOOR_ASSERT_INDEX)` specifies the group index where the floor assertion occurs.
4. On the asserting call ($Txn.\text{group\_index} == \text{asserting}$):
   $$\text{TotalPaid} = \text{own} + \sum_{k < \text{group\_index}} \text{LoggedOutput}(k)$$
   Line 1981/2106 asserts $\text{TotalPaid} \ge \text{minimum\_received}$.
5. If the total paid is less than the floor, the assertion fails and the entire atomic group reverts, guaranteeing that no user funds are swapped below their agreed quote.

---

### Invariant 4: Bounded Execution & Resource Safety
**Formal Statement:**
For any valid route $R$:
1. $\text{ReferenceCount}(R) \le 8$
2. $\text{GroupSize}(R) \le 16$
3. $\text{OpcodeConsumption}(R) \le 700 \times \text{AppCallsInGroup} + 700 \times \text{OpupCount}$

**Proof Sketch:**
- The router limits routes to 2 or 3 legs. STAMM legs (which consume high reference slots and opcode budgets) are restricted to 2-leg routes where reference count $\le 8$.
- `MAX_STAMM_OPUPS = 8` bounds inner budget calls to $\le 8$ no-ops ($5,600$ additional opcode units).
- Group builders statically enforce reference counts and group sizing before submission.
