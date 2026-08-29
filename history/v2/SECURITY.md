# Reporting and Limitations

This repository is an AI-assisted security review. It is not a guarantee of
security and must not be treated as an independent human audit. In particular,
the repository does not contain a KAVM proof, exhaustive provider code review,
or a production quote-signer submission test.

Report suspected issues to the project operators through the project security
channel. Do not publish exploitable transaction details while user funds could
be at risk. Include the deployed application ID, network, transaction group,
source/compiler identifiers and a minimal reproduction where safe.

The most valuable unresolved review areas are the quote note and transaction
signing boundary, pre-held input balances, route3, unrestricted opcode/resource
combinations, provider upgrade authority and treasury approval timing.
