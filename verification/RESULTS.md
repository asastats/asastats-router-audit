# Recorded verification run

Output of `./verify.sh` on the revision named below. Re-run it yourself:

```
ROUTER=/path/to/router ./verify.sh
```

```
router:   <router-checkout>
revision: 8d130d6
tree:     2 file(s) modified
date:     2026-08-29 18:27:55Z

== C1  convert_and_distribute is admin-only and reads its pool from state ==
  PASS  admin assertion exists                                     11 occurrence(s)
  PASS  same-group approval refused                                2 occurrence(s)
  PASS  conversion pool is not a parameter                         0

== H1  the floor is co-signed, not supplied by the caller ==
  PASS  floor derived from the signed note                         4 occurrence(s)
  PASS  route/route3 take no minimum_received parameter            0
  PASS  quote authorisation is a pool_budget call                  2 occurrence(s)

== M4  no provider's pool application is the caller's to choose ==
  PASS  Pact pinned by creator                                     1 occurrence(s)
  PASS  STAMM pinned by creator                                    1 occurrence(s)
  PASS  AlgoFi pinned by whitelist                                 1 occurrence(s)
  PASS  AlgoFi manager pinned                                      2 occurrence(s)
  PASS  Tinyman address derived, not given                         5 occurrence(s)
  PASS  creator read from the ledger                               3 occurrence(s)

== M5  a caller cannot ask for unbounded opcode budget ==
  PASS  opups bounded                                              1 occurrence(s)
  PASS  non-STAMM legs may not ask at all                          1 occurrence(s)

== MBR  an opt-in cannot be opened except to serve a route ==
  PASS  opt-in must serve a route                                  5 occurrence(s)
  PASS  double opt-in refused                                      1 occurrence(s)

== group hygiene  every entry point refuses a rekey or a close ==
  PASS  entry points                                               14
  PASS  of which assert group hygiene (see REPORT 4.3)             12
  PASS  rekey refused                                              1 occurrence(s)
  PASS  ALGO close refused                                         1 occurrence(s)
  PASS  ASA close refused                                          1 occurrence(s)

== admin bounds ==
  PASS  fee ceiling is 100 bps                                     1
  PASS  fee ceiling enforced                                       1 occurrence(s)
  PASS  delete needs a zero accrued balance                        20 occurrence(s)

== input provenance ==
  PASS  input must come from the caller                            1 occurrence(s)
  PASS  input must be adjacent                                     1 occurrence(s)
  PASS  the whole input must be spent                              3 occurrence(s)

== the suite ==
  note  tests collected: 948
  note  tests/test_sweep.py collects: 123  (audit v5 claimed 982)

passed 27, failed 0
```
