extends SceneTree
## Renders every sprite (both walk frames, then any attack poses, stacked) and the
## ground tiles into one PNG for review, and reports rows that aren't 16 wide.
## Run: godot --headless --path . -s tools/sprite_sheet.gd -- /path/to/out.png [prefix,prefix...]
## (the optional prefixes limit the sheet to sprites whose names start with one of them)

const Sprites = preload("res://scripts/sprites.gd")
const ZOOM := 6
const PER_ROW := 9
const POSES := ["swing", "strike", "strike2", "strum", "draw", "cast", "punch", "kick", "throw", "plant", "catch"]


func _initialize() -> void:
	var out := "res://sprite_sheet.png"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]

	var names := Sprites.SPRITES.keys()
	if args.size() > 1:
		var prefixes := args[1].split(",")
		names = names.filter(func(n): return Array(prefixes).any(func(pre): return n.begins_with(pre)))
	for n in names:
		var s: Dictionary = Sprites.SPRITES[n]
		var all: Array = s["rows"] + s.get("legs_b", [])
		if (s["rows"] as Array).size() != Sprites.SIZE:
			print("%s has %d rows" % [n, (s["rows"] as Array).size()])
		for i in all.size():
			if (all[i] as String).length() < Sprites.SIZE:
				print("%s row %d has %d chars: %s" % [n, i, (all[i] as String).length(), all[i]])

	# Each cell is a column of textures: walk A, walk B, then poses.
	var cells := []
	for n in names:
		var texes: Array = Sprites.frames(n).duplicate()
		for p in POSES:
			var t = Sprites.pose(n, p)
			if t != null:
				texes.append(t)
		cells.append(texes)
	var cw := 28
	var ch := Sprites.SIZE + 2
	var tallest := 0
	for c in cells:
		tallest = maxi(tallest, (c as Array).size())
	var groups := ceili(names.size() / float(PER_ROW))
	var sheet := Image.create(cw * PER_ROW, ch * (groups * tallest + 1), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.25, 0.47, 0.22))
	for i in names.size():
		var col := i % PER_ROW
		var row := (i / PER_ROW) * tallest
		var texes: Array = cells[i]
		for f in texes.size():
			var img: Image = (texes[f] as ImageTexture).get_image()
			sheet.blend_rect(img, Rect2i(0, 0, img.get_width(), Sprites.SIZE), Vector2i(col * cw + 1, (row + f) * ch + 1))
	for v in 5:
		var img: Image = Sprites.ground_tile(v).get_image()
		sheet.blit_rect(img, Rect2i(0, 0, Sprites.SIZE, Sprites.SIZE), Vector2i(v * cw + 1, groups * tallest * ch + 1))
	sheet.resize(sheet.get_width() * ZOOM, sheet.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out)
	print("order: ", names)
	print("saved ", out)
	quit()
