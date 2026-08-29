# Recommended Completion Plan

This is the work remaining after the source review and completed Phase 1
adversarial-pool coverage, ordered by risk reduction.

## Gate 1: Release signing

- Define where the quote signer signs after group assembly.
- Bind the signature to the final grouped transaction set.
- Submit one group with normal signature validation, not empty signatures.
- Test a rotated signer and an expired validity window.

## Gate 2: Contract regression

- Run the patched contract on LocalNet with a pre-held input ASA. **Complete in
  Phase 1.**
- Use a malicious stub that returns output while leaving input behind; assert
  the group reverts and no balances change. **Complete in Phase 1.**
- Exercise route3 with every supported provider combination that fits the
  eight-reference limit.
- Exercise a large final conversion with `minimum_out = 0` and a dust final
  conversion with zero output.
- Submit a group whose final signer transaction is a payment or another app
  call and assert rejection.

## Gate 3: Resource and adversarial testing

- Hypothesis-generate transaction groups with missing, duplicated, non-adjacent
  and mismatched funding references.
- Fuzz route assets, repeated paths, invalid provider codes, `opups`, app IDs,
  boxes and foreign arrays.
- Add a malicious pool harness for wrong output, residual input, extra output,
  unexpected fees and failed inner calls.
- Measure opcode headroom for worst-case route3 and maximum supported STAMM
  budget values.

## Gate 4: Provider and deployment assurance

- Verify source, compiler version, template substitutions and deployed approval
  bytes independently.
- Record each provider's factory/deployer, update authority and program hash.
- Alert on provider leg counts dropping to zero, admin method calls, float
  changes and unexpected `accrued` changes.
- Run end-to-end conversion on the deployment network.

## Gate 5: Human review and launch controls

- Obtain review from an Algorand-experienced smart-contract auditor.
- Start a bug bounty only after the human review and release-signing test.
- Lift `RESTRICT_TO_ADMIN` only through a fresh deployment whose bytecode and
  template values are pinned in the release record.
