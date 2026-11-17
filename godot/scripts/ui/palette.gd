class_name Palette
extends RefCounted

## Single source of truth for the M5-01 Prism Garden palette.
## Every screen and widget reads these values so the identity stays coherent.

const BG := Color("#0B1F27")
const BG_DEEP := Color("#061116")
const PANEL := Color("#102832")
const PANEL_HI := Color("#173642")
const PANEL_LO := Color("#0C212A")
const LINE := Color("#2A5A66")
const TEXT := Color("#EAF7FF")
const MUTED := Color("#8FB3BF")
const DIM := Color("#5E808C")
const ACCENT := Color("#46D8D0")
const ACCENT_DARK := Color("#1E8F8C")
const GOLD := Color("#FFC24B")
const PINK := Color("#F87AA7")
const DANGER := Color("#F87AA7")

const TITLE_SIZE := 60
const HEADING_SIZE := 44
const BODY_SIZE := 32
const SMALL_SIZE := 27
const TINY_SIZE := 22

## QA-05 type scale (owner-approved for 1.0, 17 Nov 2026).
##
## The design is 1080 px wide and stretched with `canvas_items`, so one design
## pixel maps to 1080/1440 = 0.427 dp on the 1440-wide S23 Ultra. The sizes
## above were authored by eye at that scale and put body text at ~10-13 dp,
## under the 14 sp Material baseline for body copy and the 12 sp caption floor.
##
## Every label and button multiplies its size by this factor at render time, so
## the ramp below and every call site move together. Measured result on the
## S23 Ultra: 24 -> 12.3 dp, 32 -> 16.4 dp, 36 -> 18.4 dp.
const TYPE_SCALE := 1.2

## Apply the type scale to a design-space font size.
static func type_size(design_px: int) -> int:
	return int(round(design_px * TYPE_SCALE))
