"""Do the sweep's two price sources disagree on live data?

The measurement `S4` was originally argued without, and the one thing this
audit had listed as out of scope. It needs both halves at once: an account
evaluation, which only the full engine produces, and the router's `al:*` price
map, which is a Redis read.

`disputed_dust` fires only when the router puts a holding at or below the
forfeit threshold *and* the evaluation puts it above. So the interesting
number is not how closely the two agree on average -- it is how wide the
disagreement gets, and whether any holding sits near enough to the threshold
for that width to carry it across.

Usage:

    REDIS_AUTH=... python measure-divergence.py <evaluation.json> [more.json ...]

Each argument is the JSON the engine's own account endpoint returns
(`GET /api/v2/internal/accounts/<address>/`). Reads only; no keys, no chain.

**A note on units, because getting it wrong here is loud in one direction and
silent in the other.** `asset_prices` returns microALGO per *base* unit, and
`engine.core.sweep.holdings_for` values a holding as `amount * per_unit` with
no decimals division. Dividing by `10 ** decimals` -- which is what "price per
unit" reads like -- understates every asset that has decimals by that factor
and reports almost every holding as disputed. The first run of this script did
exactly that; what gave it away was that the only holdings it got right were
the ones with zero decimals.
"""

import json
import os
import sys

sys.path.insert(0, os.environ.get("ROUTER", "../../router"))

import redis  # noqa: E402

from router.cache import pools_from_cache  # noqa: E402
from router.selection import asset_prices  # noqa: E402
from router.sweep import FORFEIT_THRESHOLD, MICRO_ALGO  # noqa: E402

ALGO_ID = 0


def holdings(paths, client):
    """Return `(account, unit, evaluated, routed)` for every holding.

    :param paths: evaluation JSON files
    :type paths: list
    :param client: Redis client holding the `al:*` map
    :type client: :class:`redis.Redis`
    :return: list
    """
    rows = []
    for path in paths:
        items = json.load(open(path))["asaitems"]
        prices = asset_prices(
            pools_from_cache(
                assets=[one["asset"]["id"] for one in items], client=client
            )
        )
        for one in items:
            identifier = one["asset"]["id"]
            if identifier == ALGO_ID:
                continue  # `classify` keeps ALGO; it is never a forfeit

            try:
                evaluated = float(one.get("value") or 0) * MICRO_ALGO
            except (TypeError, ValueError):
                evaluated = None

            per_unit = prices.get(identifier)
            rows.append(
                (
                    os.path.basename(path).split(".")[0],
                    one["asset"].get("unit") or str(identifier),
                    evaluated,
                    None if per_unit is None else one.get("amount", 0) * per_unit,
                )
            )
    return rows


def main(paths):
    client = redis.Redis(
        host=os.environ.get("REDIS_HOST", "localhost"),
        port=int(os.environ.get("REDIS_PORT", 6379)),
        db=int(os.environ.get("REDIS_DB", 0)),
        password=os.environ["REDIS_AUTH"],
    )
    rows = holdings(paths, client)
    paired = [row for row in rows if row[2] and row[3]]
    ratios = sorted((row[3] / row[2], row[0], row[1]) for row in paired)

    print(f"accounts       : {len(paths)}")
    print(f"holdings       : {len(rows)}")
    print(f"priced by both : {len(paired)}")
    print(f"router unpriced: {sum(1 for row in rows if row[3] is None)}")

    print("\nagreement (router value / evaluation value)")
    for label, index in (
        ("min   ", 0),
        ("median", len(ratios) // 2),
        ("max   ", -1),
    ):
        ratio, account, unit = ratios[index]
        print(f"  {label} {ratio:7.3f}   ({unit} on {account})")

    band = [row for row in paired if row[3] <= FORFEIT_THRESHOLD]
    disputed = [row for row in band if row[2] > FORFEIT_THRESHOLD]
    print(f"\nin the router's forfeit band : {len(band)}")
    print(f"  disputed by the evaluation : {len(disputed)}")
    for account, unit, evaluated, routed in disputed:
        print(
            f"    {unit:<10} on {account}: router {routed / MICRO_ALGO:.6f} "
            f"ALGO, evaluation {evaluated / MICRO_ALGO:.6f}"
        )
    return len(disputed)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
