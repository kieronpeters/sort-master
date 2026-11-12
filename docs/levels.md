# Level catalogue

All 30 levels are verified by `tools/solver/solve.py` under `rules-v1`.
Minimum move counts are exact: the search is exhaustive and unbounded.
Levels are ordered by measured minimum moves, so difficulty rises
monotonically. Stage names are design guidance, not hard bands.

| Level | Stage | Colours | Tubes | Min moves | States searched |
|---:|---|---:|---:|---:|---:|
| 1 | Discovery | 2 | 4 | 3 | 7 |
| 2 | Discovery | 3 | 5 | 6 | 37 |
| 3 | Discovery | 3 | 5 | 6 | 108 |
| 4 | Discovery | 3 | 5 | 7 | 109 |
| 5 | Discovery | 3 | 5 | 7 | 157 |
| 6 | Discovery | 4 | 6 | 8 | 91 |
| 7 | Growing complexity | 4 | 6 | 8 | 212 |
| 8 | Growing complexity | 4 | 6 | 9 | 465 |
| 9 | Growing complexity | 3 | 5 | 10 | 301 |
| 10 | Growing complexity | 4 | 6 | 10 | 479 |
| 11 | Growing complexity | 4 | 6 | 11 | 301 |
| 12 | Growing complexity | 4 | 6 | 11 | 549 |
| 13 | Strategy | 4 | 6 | 11 | 574 |
| 14 | Strategy | 4 | 6 | 11 | 807 |
| 15 | Strategy | 4 | 6 | 12 | 532 |
| 16 | Strategy | 5 | 7 | 12 | 1679 |
| 17 | Strategy | 4 | 5 | 13 | 52 |
| 18 | Strategy | 4 | 6 | 13 | 985 |
| 19 | Mastery | 5 | 7 | 14 | 1912 |
| 20 | Mastery | 5 | 7 | 15 | 1309 |
| 21 | Mastery | 5 | 6 | 16 | 79 |
| 22 | Mastery | 5 | 7 | 16 | 1129 |
| 23 | Mastery | 5 | 7 | 16 | 3379 |
| 24 | Mastery | 5 | 7 | 16 | 3586 |
| 25 | Expert | 6 | 8 | 18 | 1907 |
| 26 | Expert | 6 | 8 | 18 | 1968 |
| 27 | Expert | 6 | 8 | 18 | 2199 |
| 28 | Expert | 6 | 8 | 19 | 1571 |
| 29 | Expert | 6 | 8 | 19 | 1891 |
| 30 | Expert | 6 | 8 | 20 | 3728 |

## Difficulty metrics recorded

Per level: minimum moves (exact), colour count, tube count, and the number
of states the solver explored (a proxy for branching and dead ends).

## Notes

- No two levels share a canonical tube arrangement.
- Every level satisfies the `rules-v1` invariants: 4 units per colour,
  capacity 4, at least one empty tube, not won at load.
- The five original hand-designed levels are preserved; only their
  positions in the progression changed.
