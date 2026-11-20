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

## The real blocker on "as many rows and columns as Magic Sort"

This one is not about rendering, and it is the finding that matters most.

The engine already draws three rows: `board_layout.compute` seats up to 14 jugs in
three rows, and a rules test asserts every one of them lands on screen with its own
tap strip.

What blocks a *wider catalogue* is **puzzle verification**:

- Our palette is capped at **eight colours** by measured colour separation
  (CIEDE2000 under deuteranopia: 8 colours gives 15.3/14.0, ten gives 12.3, twelve
  gives 9.7 which is below the forbidden line). More jugs therefore means more
  *spare* jugs, not more colours.
- Spare jugs make boards **easier**, and they enlarge the search space enormously.
  An attempt to generate twelve-jug and fourteen-jug levels with BFS verification
  did not produce a single level in **28 minutes**; the generator was killed twice.
- Shipping an unverified level is not acceptable, so the catalogue stops at **ten
  jugs** (eight colours, two spares) - two rows of five.

To go wider, the work is a **faster solver** (A\* or IDA\* with an admissible bound on
remaining moves), not a different renderer. That is the next concrete step if wider
boards matter.

## Visual features still missing, in order of impact

1. **Refraction and depth absorption through the glass** - the largest remaining
   difference. Real liquid darkens with depth and bends what is behind it.
2. **World-level liquid during a tilt** - our bands rotate with the bottle; real
   liquid stays horizontal. Most games in this genre also cheat here.
3. **Pour splash particles** - added; splace at the landing point with gravity.
4. **Seal celebration** - added; a spinning star ring and a four-note chime when a
   jug corks.
