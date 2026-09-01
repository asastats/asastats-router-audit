# Recorded verification run

Output of `./verify.sh` on the revision named below. Re-run it yourself:

```
ROUTER=/path/to/router ./verify.sh
```

The last section reads `router/build/releases/router-mainnet-3689591968.json`
— the deployment manifest — rather than describing what is deployed. Both
errors that did this series the most damage are answered by that file, and
neither audit that made them opened it.

Its last two checks compare the Tealer-swept program against that manifest by
hash. They report `SKIP` until `bash scripts/tealer.sh` has been run in the
router checkout, since that is what produces the file they read.

```
router:   <router-checkout>
revision: 657c9ff
tree:     1 file(s) modified
date:     2026-09-01 18:50:52Z

== C1  convert_and_distribute is admin-only and reads its pool from state ==
  PASS  admin assertion exists                                     12 occurrence(s)
  PASS  same-group approval refused                                2 occurrence(s)
  PASS  conversion pool is not a parameter                         batch,minimum_out

== H1  the floor is co-signed, not supplied by the caller ==
  PASS  floor derived from the signed note                         4 occurrence(s)
  PASS  route takes no minimum_received parameter                  payment,first_leg,second_leg,asset_in,middle,asset_out
  PASS  route3 takes no minimum_received parameter                 payment,first_leg,second_leg,third_leg,asset_in,first_middle,second_middle,asset_out
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
  PASS  entry points                                               15
  PASS  of which assert group hygiene (see REPORT 3.1)             13
  PASS  rekey refused                                              1 occurrence(s)
  PASS  ALGO close refused                                         1 occurrence(s)
  PASS  ASA close refused                                          1 occurrence(s)
  PASS  and the group's total fee is bounded                       1 occurrence(s)

== the deployment  what is compiled into mainnet, from its own manifest ==
  PASS  mainnet application                                        3689591968
  PASS  RESTRICT_TO_ADMIN                                          0
  PASS  restrict_to_admin, as recorded                             False
  PASS  compiler                                                   puyapy 5.9.0
  PASS  global uints, three since set_paused                       3
  PASS  the pause exists in the source                             1
  PASS  and both route entry points honour it                      2
  PASS  the group fee ceiling                                      1
  PASS  the swept program is the deployed program                  f568200e72799fb8ef043e2433d5d6d09bc2162296a2d1e959ff329c97cc8aa4
  PASS  and it is 4,768 TEAL lines                                 4768

== admin bounds ==
  PASS  fee ceiling is 100 bps                                     1
  PASS  fee ceiling enforced                                       1 occurrence(s)
  PASS  delete needs a zero accrued balance                        20 occurrence(s)

== input provenance ==
  PASS  input must come from the caller                            1 occurrence(s)
  PASS  input must be adjacent                                     1 occurrence(s)
  PASS  the whole input must be spent                              3 occurrence(s)

== the suite ==
  note  tests collected: 999
  note  tests/test_sweep.py collects: 140  (audit v5 claimed 982)

passed 39, failed 0, skipped 0
```

## What is deliberately not in here

`verify.sh` needs no node, no key and no network, and that is a design
constraint rather than an accident: anybody can run it against a checkout of
the router in one command. The claims that need a running system live in
[verify-groups.py](verify-groups.py) and its recorded output,
[GROUP-RESULTS.md](GROUP-RESULTS.md); the claims that need the sweep's
off-chain estate live in [verify-sweep.sh](verify-sweep.sh) and
[SWEEP-RESULTS.md](SWEEP-RESULTS.md); the static analysis is in
[tools/tealer.md](../tools/tealer.md).
