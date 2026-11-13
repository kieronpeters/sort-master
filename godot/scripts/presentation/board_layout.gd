class_name BoardLayout
extends RefCounted

## Pure layout maths for the 3D board.
##
## Everything is expressed in *design pixels* (the 1080-wide UI coordinate
## space) so the drawn vessels and the transparent 2D hit strips are derived
## from one place. Sharing this function is what keeps taps aligned with what
## the player sees at every window size and every tube count.

const DESIGN_W := 1080.0

## Vessel metrics in world units, taken from vessel_mesh.gd's lathe profile.
const VESSEL_WORLD_W := 0.172
const VESSEL_WORLD_H := 0.512

const VESSEL_GAP := 20.0        # design px between neighbouring vessels
const WIDTH_FRACTION := 0.88    # of the design width, including the outer margin
const BASELINE_FRACTION := 0.78 # of the design height, measured from the top
const MAX_HEIGHT_FRACTION := 0.46

## Returns {} for a degenerate request.
##
## scale      design px per screen px (1.0 at the 1080-wide reference size)
## design_h   design-space height of the viewport
## ppu        design px per world unit
## vessel_w   vessel width in design px
## slot       centre-to-centre distance in design px
## centres    design-space x centre of each vessel
## baseline   design-space y of the vessel bases
## hit_top    design-space y where the tap strip starts
static func compute(tube_count: int, viewport: Vector2) -> Dictionary:
	if tube_count <= 0 or viewport.x < 2.0 or viewport.y < 2.0:
		return {}

	var sx: float = viewport.x / DESIGN_W
	var design_h: float = viewport.y / sx

	var usable: float = DESIGN_W * WIDTH_FRACTION
	var ppu_w: float = (usable - float(tube_count - 1) * VESSEL_GAP) / (float(tube_count) * VESSEL_WORLD_W)
	var ppu_h: float = design_h * MAX_HEIGHT_FRACTION / VESSEL_WORLD_H
	var ppu: float = maxf(1.0, minf(ppu_w, ppu_h))

	var vessel_w: float = VESSEL_WORLD_W * ppu
	var slot: float = vessel_w + VESSEL_GAP
	var total: float = float(tube_count) * slot - VESSEL_GAP
	var start: float = (DESIGN_W - total) * 0.5

	var centres: Array = []
	for i in tube_count:
		centres.append(start + slot * (float(i) + 0.5))

	var baseline: float = design_h * BASELINE_FRACTION
	return {
		"scale": sx,
		"design_h": design_h,
		"ppu": ppu,
		"vessel_w": vessel_w,
		"slot": slot,
		"centres": centres,
		"baseline": baseline,
		"hit_top": baseline - VESSEL_WORLD_H * ppu * 1.06,
	}
