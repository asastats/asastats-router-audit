# [INFORMATIONAL] I5: Unbounded Admin Batch Repetition for Fee Conversions

## Description
While `convert_and_distribute` enforces `MAX_CONVERSION_BATCH` (500 ALGO) per transaction call, an admin key can call the method repeatedly in separate transactions to convert larger total sums.

## Evaluation
This is an intentional design trade-off: large treasury conversions are executed in bounded batches to limit market impact per pool swap. The admin key remains trusted for treasury operations.

## Status
**Documented and Accepted.**
