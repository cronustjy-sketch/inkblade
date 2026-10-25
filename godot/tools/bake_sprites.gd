extends SceneTree

# Bakes the raw Codex sprite sheets in art_src/raw/<unit>.png (white background, 4x2 grid:
# top row = walk, bottom row = attack) into game-ready sheets:
#   sprites/<unit>_gold.png  player version (gold trim, as drawn)
#   sprites/<unit>_red.png   enemy version (gold hues shifted to red)
#   data/sprite_meta.gd      cell size and drawn character height per unit
#
# Run:  godot --headless --path . --script res://tools/bake_sprites.gd
# then: godot --headless --path . --import

const RAW_DIR: String = "res://art_src/raw/"
const RAW_PROPS_DIR: String = "res://art_src/raw_bg/"
const OUT_DIR: String = "res://sprites/"
const META_PATH: String = "res://data/sprite_meta.gd"
const WIDE_SHEETS: Array[String] = ["cavalry", "catapult"] # 3 columns x 4 rows; everything else is 6 columns x 2 rows
const WALK_FRAMES: int = 6
const MARGIN: int = 8
const BG_MIN: int = 232 # a border-connected pixel whose darkest channel is >= this is background
const WHITE_MIN: int = 246 # enclosed pure-white patches at least WHITE_BLOB px big are holes too
const WHITE_BLOB: int = 80
const ALPHA_MIN: int = 24
const MIN_BLOB: int = 6

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var meta: Dictionary = {}
	for raw_dir: String in [RAW_DIR, RAW_PROPS_DIR]:
		var dir := DirAccess.open(raw_dir)
		var names: PackedStringArray = dir.get_files()
		names.sort()
		for file_name in names:
			if not file_name.ends_with(".png") or (raw_dir == RAW_PROPS_DIR and not file_name.begins_with("props_")):
				continue
			var key: String = file_name.get_basename()
			var info: Dictionary = _bake(key, raw_dir)
			if not info.is_empty() and not key.begins_with("props_"):
				meta[key] = info
				print("baked %s: px_h=%d" % [key, info["px_h"]])
			elif not info.is_empty():
				print("baked %s" % key)
	_write_meta(meta)
	quit()

@warning_ignore("integer_division")
func _bake(key: String, raw_dir: String = RAW_DIR) -> Dictionary:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(raw_dir + key + ".png")) != OK:
		push_error("cannot load " + key)
		return {}
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var data: PackedByteArray = img.get_data()
	_remove_background(data, w, h)
	_clear_enclosed_white(data, w, h)
	if key.begins_with("props_"):
		return _bake_props(key, data, w, h)
	if key.begins_with("prop_"):
		return _bake_prop(key, data, w, h)

	var wide: bool = key in WIDE_SHEETS
	var cols: int = 3 if wide else 6
	var rows: int = 4 if wide else 2
	var out_w: int = 384 if wide else 256
	var out_h: int = 192 if wide else 256
	# Group opaque pixels into blobs and give each blob to the cell holding its centre, so a sword that
	# crosses a cell border stays with its warrior instead of being chopped in two.
	var cw: int = w / cols
	var ch: int = h / rows
	var labels := PackedInt32Array()
	labels.resize(w * h)
	var blob_cell: Array[int] = [-1]
	var blob_box: Array[Rect2i] = [Rect2i()]
	var next_id: int = 1
	for start in w * h:
		if labels[start] != 0 or data[start * 4 + 3] <= ALPHA_MIN:
			continue
		var id: int = next_id
		next_id += 1
		var stack := PackedInt32Array([start])
		labels[start] = id
		var min_x: int = w
		var min_y: int = h
		var max_x: int = 0
		var max_y: int = 0
		var sum_x: int = 0
		var sum_y: int = 0
		var count: int = 0
		while not stack.is_empty():
			var p: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var px: int = p % w
			var py: int = p / w
			min_x = mini(min_x, px)
			max_x = maxi(max_x, px)
			min_y = mini(min_y, py)
			max_y = maxi(max_y, py)
			sum_x += px
			sum_y += py
			count += 1
			for dy in range(-1, 2):
				var yy: int = py + dy
				if yy < 0 or yy >= h:
					continue
				for dx in range(-1, 2):
					var xx: int = px + dx
					if xx < 0 or xx >= w:
						continue
					var q: int = yy * w + xx
					if labels[q] == 0 and data[q * 4 + 3] > ALPHA_MIN:
						labels[q] = id
						stack.append(q)
		var cell: int = -1
		if count >= MIN_BLOB:
			var col: int = clampi(sum_x / count / cw, 0, cols - 1)
			var row: int = clampi(sum_y / count / ch, 0, rows - 1)
			cell = row * cols + col
		blob_cell.append(cell)
		blob_box.append(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))

	# Per-cell bounding box = union of its blobs.
	var boxes: Array[Rect2i] = []
	boxes.resize(cols * rows)
	var has_box: Array[bool] = []
	has_box.resize(cols * rows)
	for id in range(1, next_id):
		var cell: int = blob_cell[id]
		if cell < 0:
			continue
		boxes[cell] = blob_box[id] if not has_box[cell] else boxes[cell].merge(blob_box[id])
		has_box[cell] = true

	var scale_f: float = 1.0
	for i in boxes.size():
		if has_box[i]:
			scale_f = minf(scale_f, minf(float(out_w - MARGIN * 2) / boxes[i].size.x, float(out_h - MARGIN * 2) / boxes[i].size.y))

	var sheet := Image.create(out_w * cols, out_h * rows, false, Image.FORMAT_RGBA8)
	var walk_h: float = 0.0
	for i in boxes.size():
		if not has_box[i]:
			continue
		var box: Rect2i = boxes[i]
		var cell_img := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
		for y in box.size.y:
			for x in box.size.x:
				var p: int = (box.position.y + y) * w + box.position.x + x
				var id: int = labels[p]
				if id != 0 and blob_cell[id] == i:
					var o: int = p * 4
					cell_img.set_pixel(x, y, Color8(data[o], data[o + 1], data[o + 2], data[o + 3]))
		var nw: int = maxi(1, roundi(box.size.x * scale_f))
		var nh: int = maxi(1, roundi(box.size.y * scale_f))
		cell_img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
		var col: int = i % cols
		var row: int = i / cols
		# Keep the character's horizontal position inside its source cell; feet go on a common baseline.
		var src_center: float = box.position.x + box.size.x * 0.5 - col * cw
		var cx: float = out_w * 0.5 + (src_center - cw * 0.5) * scale_f
		var x0: int = clampi(roundi(cx - nw * 0.5), 0, out_w - nw)
		var y0: int = out_h - MARGIN - nh
		sheet.blit_rect(cell_img, Rect2i(0, 0, nw, nh), Vector2i(col * out_w + x0, row * out_h + y0))
		if i < WALK_FRAMES:
			walk_h += nh
	walk_h /= float(WALK_FRAMES)

	sheet.save_png(ProjectSettings.globalize_path(OUT_DIR + key + "_gold.png"))
	_recolor_gold_to_red(sheet)
	sheet.save_png(ProjectSettings.globalize_path(OUT_DIR + key + "_red.png"))
	return {"cell_w": out_w, "cell_h": out_h, "cols": cols, "rows": rows, "px_h": roundi(walk_h)}

# Flood-fills the near-white background from the image border to transparent, then softens the edge.
@warning_ignore("integer_division")
func _remove_background(data: PackedByteArray, w: int, h: int) -> void:
	var bg := PackedByteArray()
	bg.resize(w * h)
	var queue := PackedInt32Array()
	for x in w:
		queue.append(x)
		queue.append((h - 1) * w + x)
	for y in h:
		queue.append(y * w)
		queue.append(y * w + w - 1)
	var head: int = 0
	while head < queue.size():
		var p: int = queue[head]
		head += 1
		if bg[p] == 1:
			continue
		var o: int = p * 4
		if mini(data[o], mini(data[o + 1], data[o + 2])) < BG_MIN:
			continue
		bg[p] = 1
		var px: int = p % w
		var py: int = p / w
		if px > 0:
			queue.append(p - 1)
		if px < w - 1:
			queue.append(p + 1)
		if py > 0:
			queue.append(p - w)
		if py < h - 1:
			queue.append(p + w)
	# Edge softening: pixels next to the background fade by how light they are, so no white halo remains.
	for p in w * h:
		var o: int = p * 4
		if bg[p] == 1:
			data[o + 3] = 0
			continue
		var px: int = p % w
		var py: int = p / w
		if _touches_bg(bg, w, h, px, py, 2):
			var minc: int = mini(data[o], mini(data[o + 1], data[o + 2]))
			data[o + 3] = int(clampf((BG_MIN + 10.0 - minc) / 110.0, 0.0, 1.0) * 255.0)

func _touches_bg(bg: PackedByteArray, w: int, h: int, px: int, py: int, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		var yy: int = py + dy
		if yy < 0 or yy >= h:
			continue
		for dx in range(-radius, radius + 1):
			var xx: int = px + dx
			if xx >= 0 and xx < w and bg[yy * w + xx] == 1:
				return true
	return false

# Pure-white patches fully enclosed by ink (e.g. between an arm and the body) are also background.
@warning_ignore("integer_division")
func _clear_enclosed_white(data: PackedByteArray, w: int, h: int) -> void:
	var seen := PackedByteArray()
	seen.resize(w * h)
	for start in w * h:
		var so: int = start * 4
		if seen[start] == 1 or data[so + 3] <= ALPHA_MIN or mini(data[so], mini(data[so + 1], data[so + 2])) < WHITE_MIN:
			continue
		var blob := PackedInt32Array([start])
		seen[start] = 1
		var i: int = 0
		while i < blob.size():
			var p: int = blob[i]
			i += 1
			var px: int = p % w
			var py: int = p / w
			for n: int in [p - 1, p + 1, p - w, p + w]:
				if n < 0 or n >= w * h or seen[n] == 1:
					continue
				if (n == p - 1 and px == 0) or (n == p + 1 and px == w - 1):
					continue
				var no: int = n * 4
				if data[no + 3] > ALPHA_MIN and mini(data[no], mini(data[no + 1], data[no + 2])) >= WHITE_MIN:
					seen[n] = 1
					blob.append(n)
		if blob.size() >= WHITE_BLOB:
			for p in blob:
				data[p * 4 + 3] = 0

# Enemy version: shift gold / yellow hues to the enemy red (#de4b3f), leaving black ink and parchment alone.
func _recolor_gold_to_red(img: Image) -> void:
	var red_hue: float = Color("de4b3f").h
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.05:
				continue
			if c.h >= 0.07 and c.h <= 0.19 and c.s > 0.32 and c.v > 0.3:
				img.set_pixel(x, y, Color.from_hsv(red_hue, minf(1.0, c.s * 1.05), c.v, c.a))

func _write_meta(meta: Dictionary) -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	f.store_string("# Generated by tools/bake_sprites.gd - do not edit.\n# Cell size and drawn character height (pixels) of each baked sprite sheet.\nextends RefCounted\n\nconst META: Dictionary = {\n")
	var keys: Array = meta.keys()
	keys.sort()
	for k in keys:
		var m: Dictionary = meta[k]
		var cols: int = m.get("cols", 6)
		var rows: int = m.get("rows", 2)
		f.store_string('\t"%s": {"cell_w": %d, "cell_h": %d, "cols": %d, "rows": %d, "px_h": %d},\n' % [k, m["cell_w"], m["cell_h"], cols, rows, m["px_h"]])
	f.store_string("}\n")

# Single illustrations (art_src/raw/prop_<name>.png, e.g. the castle): background removed, cropped to the
# artwork, saved as sprites/prop_<name>_gold.png and _red.png. meta: width / height in pixels.
func _bake_prop(key: String, data: PackedByteArray, w: int, h: int) -> Dictionary:
	var min_x: int = w
	var min_y: int = h
	var max_x: int = 0
	var max_y: int = 0
	for y in h:
		for x in w:
			if data[(y * w + x) * 4 + 3] > ALPHA_MIN:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	var full := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	var crop := full.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
	crop.save_png(ProjectSettings.globalize_path(OUT_DIR + key + "_gold.png"))
	_recolor_gold_to_red(crop)
	if key == "prop_statue":
		_darken_stone(crop)
	crop.save_png(ProjectSettings.globalize_path(OUT_DIR + key + "_red.png"))
	return {"cell_w": crop.get_width(), "cell_h": crop.get_height(), "px_h": crop.get_height()}

# A 3x2 sheet of scenery props (art_src/raw_bg/props_<theme>.png) is cut into six tight PNGs:
# sprites/props_<theme>_0.png ... _5.png (row-major). Returns a non-empty dict when done.
@warning_ignore("integer_division")
func _bake_props(key: String, data: PackedByteArray, w: int, h: int) -> Dictionary:
	var cols: int = 3
	var rows: int = 2
	var cw: int = w / cols
	var ch: int = h / rows
	var full := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	for i in cols * rows:
		var cell := Rect2i((i % cols) * cw, (i / cols) * ch, cw, ch)
		var part: Image = full.get_region(cell)
		var used: Rect2i = part.get_used_rect()
		if used.size.x <= 0:
			continue
		var crop: Image = part.get_region(used)
		if crop.get_height() > 512:
			crop.resize(roundi(crop.get_width() * 512.0 / crop.get_height()), 512, Image.INTERPOLATE_LANCZOS)
		crop.save_png(ProjectSettings.globalize_path(OUT_DIR + "%s_%d.png" % [key, i]))
	return {"cell_w": cw, "cell_h": ch, "px_h": ch}

# Enemy statue: the grey stone goes dark and bluish while saturated accents (the red recolour) stay bright.
func _darken_stone(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.05 or c.s > 0.35:
				continue
			img.set_pixel(x, y, Color.from_hsv(0.62, minf(0.25, c.s + 0.1), c.v * 0.42, c.a))
