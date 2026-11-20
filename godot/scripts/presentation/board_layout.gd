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
const WIDTH_FRACTION := 0.94    # of the design width, including the outer margin
const BASELINE_FRACTION := 0.66 # of the design height, measured from the top
const MAX_HEIGHT_FRACTION := 0.46
const MAX_PER_ROW := 6            # vessels across before the board stacks
const ROW_GAP := 26.0             # design px between stacked rows

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

	# Rows. A single row of 10 vessels would be ~80 design px wide each and the
	# bands would be unreadable, so the board stacks instead: five to a row, then
	# a second row, then a third. This is how the genre gets more jugs on screen.
	var rows: int = int(ceil(float(tube_count) / float(MAX_PER_ROW)))
	var per_row: Array = []
	var remaining: int = tube_count
	for r in rows:
		var rows_left: int = rows - r
		var take: int = int(ceil(float(remaining) / float(rows_left)))
		per_row.append(take)
		remaining -= take

	var widest: int = 0
	for c in per_row:
		widest = maxi(widest, int(c))

	var usable: float = DESIGN_W * WIDTH_FRACTION
	var ppu_w: float = (usable - float(widest - 1) * VESSEL_GAP) / (float(widest) * VESSEL_WORLD_W)

	# More rows means each row is shorter; the board area grows a little to
	# compensate so the vessels do not become thimbles.
	var board_fraction: float = MAX_HEIGHT_FRACTION if rows == 1 else 0.60
	var usable_h: float = design_h * board_fraction
	var row_h: float = (usable_h - float(rows - 1) * ROW_GAP) / float(rows)
	var ppu_h: float = row_h * 0.94 / VESSEL_WORLD_H
	var ppu: float = maxf(1.0, minf(ppu_w, ppu_h))

	var vessel_w: float = VESSEL_WORLD_W * ppu
	var vessel_h: float = VESSEL_WORLD_H * ppu
	var slot: float = vessel_w + VESSEL_GAP

	var bottom_baseline: float = design_h * (0.66 if rows == 1 else 0.74)
	var row_baseline: Array = []
	for r in rows:
		row_baseline.append(bottom_baseline - float(rows - 1 - r) * (vessel_h + ROW_GAP))

	var centres: Array = []
	var vessels: Array = []
	var index: int = 0
	for r in rows:
		var count: int = int(per_row[r])
		var total: float = float(count) * slot - VESSEL_GAP
		var start: float = (DESIGN_W - total) * 0.5
		for i in count:
			var cx: float = start + slot * (float(i) + 0.5)
			centres.append(cx)
			vessels.append({
				"x": cx,
				"baseline": row_baseline[r],
				"row": r,
				"hit_top": row_baseline[r] - VESSEL_WORLD_H * ppu * 1.06,
				"hit_bottom": row_baseline[r] + 16.0,
			})
			index += 1

	return {
		"scale": sx,
		"design_h": design_h,
		"ppu": ppu,
		"vessel_w": vessel_w,
		"vessel_h": vessel_h,
		"slot": slot,
		"rows": rows,
		"per_row": per_row,
		"centres": centres,
		"vessels": vessels,
		"baseline": bottom_baseline,
		"hit_top": bottom_baseline - VESSEL_WORLD_H * ppu * 1.06,
	}
