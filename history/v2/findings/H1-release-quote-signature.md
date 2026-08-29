# H1 — Production route groups lack the quote-signer signature

**Severity:** High availability / release blocker
**Status:** Patched in the worktree; wallet runtime verification pending

## Description

The signed-floor design adds a final application call sent by `quote_signer`.
The contract correctly refuses any group whose final transaction is not sent by
that account. The production route API, however, serializes the assembled
transactions unsigned for a wallet. A wallet can sign its own transactions but
cannot sign the transaction sent by the separate quote signer.

The engine now signs the quote transaction server-side and returns it separately
from the unsigned user transactions. The wallet bridge preserves that signature
and asks the wallet to sign only non-quote indexes. The two-normal-signature
Testnet submission now passes; mobile-wallet runtime verification remains.

## Impact and recommendation

Before the worktree change, routed groups failed closed in production. The
remaining risk is release integration: a wallet adapter that drops or regroups
the backend-signed transaction will produce a rejected group.

The worktree implements backend co-signing after group assembly and keeps the
quote signer key separate from admin and voucher keys. Complete Pera/Defly
runtime tests before release.
