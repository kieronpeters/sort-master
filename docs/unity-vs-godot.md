# Unity versus Godot for this game

Written after playing Magic Sort! (Unity, `com.grandgames.magicsort`) through its
first levels on a physical S23 Ultra, and after measuring what this project can and
cannot do in Godot 4.7.2.

## The short answer

**Unity would not make this game look like Magic Sort.** The difference in look is
not engine capability; it is authored shader and art work. Everything that has been
reported as "looking wrong" so far turned out to be a defect in our own code:

| Reported | Actual cause | Engine |
|---|---|---|
| Yellow aura under a jug | selection sprite was parented to the jug | Godot |
| Black line at the base | a near-black plinth cylinder wider than the glass | Godot |
| Top of a draining jug keeps colour | meniscus was a sibling pinned at a fixed height | Godot |
| Squares visible in the liquid | seam darkening at each band's edges | Godot |
| Only one music track heard | tracks were 150 s, so the first change came late | Godot |

None of those needed a different engine, and all five were fixed.

## What Magic Sort actually uses

From the listing and from playing it:

- **Unity** (`com.unity3d.player.UnityPlayerActivity`), 193 MB install.
- Liquid drawn as tall rounded columns with a **specular streak, fresnel edge
  brightening, and a domed surface**; bands of one colour merge seamlessly.
- **Corked bottles** when a colour completes.
- **Hidden colours**: some bands render as opaque black with "?" marks and are
  revealed layer by layer as you pour.
- Board layout grows to **two rows** by the mid levels (observed: 4 + 3 at level 6,
  4 + 4 at level 7, five columns).
- Three boosters, each with three uses: undo, shuffle, add bottle.

None of that is Unity-specific. All of it is achievable in Godot's Vulkan mobile
renderer, which this project already ships and which was confirmed drawing on the
S23 (`Vulkan 1.3.128 - Forward Mobile - Adreno 740`).

## What Unity would actually buy

| Advantage | Worth switching? |
|---|---|
| Shader Graph for authoring the liquid look | Marginal: the same maths is ~150 lines of GLSL |
| Asset Store fluid/particle packs | Genuinely useful, and the strongest argument for Unity |
| Larger artist and contractor pool | Only if hiring |
| Console/mobile middleware | Not needed |

## What a port would cost

Everything written in GDScript would be rewritten: UI, pour animation, boosters,
settings, audio director, 3-D board, level loader. What survives a port because it is
engine-neutral: the 500 level files, `rules-v1`, the Python solver, the test suites,
the audio and art assets.

So a port keeps the *content* and loses the *implementation* - several weeks to
parity, and it would still need the same shader work at the end.

## Rows and columns: now at fourteen jugs, in three rows

Magic Sort grows its boards to two rows. Ours now goes further: levels 441-500 ship
twelve and fourteen jugs, laid out in **two rows of six** or **three rows of five,
five and four**, all verified playable through the real tap path.

Getting there needed two things, neither of them a different renderer:

1. **A layout that stacks.** `board_layout.compute` seats up to fourteen jugs across
   three rows, each with its own tap strip. A rules test asserts every vessel lands
   on screen.

2. **A cheaper proof of playability.** Proving the *exact* minimum does not scale:
   BFS on a twelve-jug board produced no level in twenty-eight minutes (killed
   twice), and A* - with an admissible bound of `sum(tubes holding each colour - 1)`
   - closed only one of four twelve-jug boards and none of the thirteen-jug ones.

   What *is* cheap is proving a board is **solvable**: depth-first search with
   consolidation-first ordering closes a fourteen-jug board in about 20 ms. So the
   wide tiers ship with a recorded solution and **no** `minMoves`. They do not claim
   optimality they have not proved; every recorded solution is replayed through the
   real rules before shipping.

The catalogue therefore has two guarantees, and the level files say which applies:

| Levels | Guarantee |
|---|---|
| 1-440 | minimum move count, proved by exact search |
| 441-500 | solvable, proved by replay; no minimum claimed |

The colour ceiling is still eight (measured CIEDE2000 separation), so the extra jugs
in the wide tiers are spares. That makes them more forgiving, which is why their
recorded solutions are longer (26-42 moves) rather than shorter.

## Visual features still missing, in order of impact

1. **Refraction and depth absorption through the glass** - the largest remaining
   difference. Real liquid darkens with depth and bends what is behind it.
2. **World-level liquid during a tilt** - our bands rotate with the bottle; real
   liquid stays horizontal. Most games in this genre also cheat here.
3. **Pour splash particles** - added; splace at the landing point with gravity.
4. **Seal celebration** - added; a spinning star ring and a four-note chime when a
   jug corks.
