extends SceneTree
## Every character the game writes on screen is in its own font. The web build has no
## system fonts to borrow a missing glyph from, so one the built-in font lacks (◀, ✓...)
## shows as a box there, while the desktop quietly fills it in. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/glyphs_test.gd
## Scans every script's code (not its ## comments) for characters beyond plain ASCII
## and checks each against the default font. Exits 1 if anything failed.

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var font: Font = ThemeDB.fallback_font
	var missing := {}
	var seen := {}
	for path in _scripts("res://scripts"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code: String = lines[i].get_slice("##", 0)
			for k in code.length():
				var c := code.unicode_at(k)
				if c <= 127 or c == 0xFEFF:
					continue
				seen[c] = true
				if font is FontFile and not (font as FontFile).has_char(c) and not missing.has(c):
					missing[c] = "%s:%d" % [path.get_file(), i + 1]
	var list := []
	for c in missing:
		list.append("%s (U+%04X, %s)" % [String.chr(c), c, missing[c]])
	check(font is FontFile and missing.is_empty(), "Every character on screen is in the built-in font (%d kinds beyond ASCII)%s"
			% [seen.size(), "" if missing.is_empty() else ": missing " + ", ".join(list)])
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _scripts(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out += _scripts(dir + "/" + d)
	return out
