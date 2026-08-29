# [INFORMATIONAL] I3: ARC-4 ABI Encoding Validation & Puya Version Pinning

## Description
Earlier versions of Puya compilers (< 5.3.2) lacked automatic length and offset validation on dynamic ARC-4 byte array arguments, creating potential out-of-bounds or buffer overwrite risks.

## Verification
The current build uses Puya 5.9.0, which enforces strict ARC-4 dynamic array length checks by default on all ABI methods. All method arguments (`verify_discount`, `route`, `route3`, `set_conversion_pool`) are strictly validated against their schema.

## Status
**Verified Defended.**
