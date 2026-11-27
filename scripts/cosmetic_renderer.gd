extends RefCounted

## Shared palette-remapped pixel sprite & accessory renderer for Pixel Porter.
## Guarantees 100% visual parity across in-game gameplay, Supply Depot row thumbnails,
## and the interactive Supply Depot preview stage across all 4 walk directions.

static var _worker_tex_cache: Dictionary = {}
static var _crate_tex_cache: Dictionary = {}


static func clear_cache() -> void:
	_worker_tex_cache.clear()
	_crate_tex_cache.clear()


static func get_worker_texture(skin_id: String, base_tex: Texture2D) -> Texture2D:
	if base_tex == null or skin_id.is_empty() or skin_id == "classic":
		return base_tex
	var key: String = "%s:%d" % [skin_id, base_tex.get_rid().get_id()]
	if _worker_tex_cache.has(key):
		return _worker_tex_cache[key] as Texture2D

	var src_img: Image = base_tex.get_image()
	if src_img == null:
		return base_tex
	var img: Image = src_img.duplicate()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var w: int = img.get_width()
	var h: int = img.get_height()
	var bytes: PackedByteArray = img.get_data()
	var lut: Dictionary = {}

	for y in range(h):
		var yn: float = float(y) / float(maxi(1, h))
		# Spatial bands prevent cap vs shirt confusion and keep eyes (y < 0.415) intact
		var band: int = 0 if yn < 0.415 else (1 if yn < 0.515 else (2 if yn < 0.595 else (3 if yn < 0.675 else 4)))
		var row_off: int = y * w * 4
		for x in range(w):
			var idx: int = row_off + x * 4
			var a: int = bytes[idx + 3]
			if a < 128:
				continue
			var r: int = bytes[idx]
			var g: int = bytes[idx + 1]
			var b: int = bytes[idx + 2]
			var lut_key: int = (r << 19) | (g << 11) | (b << 3) | band
			var mapped: Color
			if lut.has(lut_key):
				mapped = lut[lut_key]
			else:
				mapped = _remap_worker_pixel(skin_id, Color8(r, g, b, a), band)
				lut[lut_key] = mapped
			bytes[idx] = clampi(int(round(mapped.r * 255.0)), 0, 255)
			bytes[idx + 1] = clampi(int(round(mapped.g * 255.0)), 0, 255)
			bytes[idx + 2] = clampi(int(round(mapped.b * 255.0)), 0, 255)

	var out_img: Image = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	var out_tex: Texture2D = ImageTexture.create_from_image(out_img)
	_worker_tex_cache[key] = out_tex
	return out_tex


static func get_crate_texture(skin_id: String, base_tex: Texture2D) -> Texture2D:
	if base_tex == null or skin_id.is_empty() or skin_id == "classic_wood":
		return base_tex
	var key: String = "%s:%d" % [skin_id, base_tex.get_rid().get_id()]
	if _crate_tex_cache.has(key):
		return _crate_tex_cache[key] as Texture2D

	var src_img: Image = base_tex.get_image()
	if src_img == null:
		return base_tex
	var img: Image = src_img.duplicate()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var w: int = img.get_width()
	var h: int = img.get_height()
	var bytes: PackedByteArray = img.get_data()
	var lut: Dictionary = {}

	for y in range(h):
		var row_off: int = y * w * 4
		for x in range(w):
			var idx: int = row_off + x * 4
			var a: int = bytes[idx + 3]
			if a < 128:
				continue
			var r: int = bytes[idx]
			var g: int = bytes[idx + 1]
			var b: int = bytes[idx + 2]
			var lut_key: int = (r << 16) | (g << 8) | b
			var mapped: Color
			if lut.has(lut_key):
				mapped = lut[lut_key]
			else:
				mapped = _remap_crate_pixel(skin_id, Color8(r, g, b, a))
				lut[lut_key] = mapped
			bytes[idx] = clampi(int(round(mapped.r * 255.0)), 0, 255)
			bytes[idx + 1] = clampi(int(round(mapped.g * 255.0)), 0, 255)
			bytes[idx + 2] = clampi(int(round(mapped.b * 255.0)), 0, 255)

	var out_img: Image = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	var out_tex: Texture2D = ImageTexture.create_from_image(out_img)
	_crate_tex_cache[key] = out_tex
	return out_tex


static func _remap_worker_pixel(skin_id: String, col: Color, band: int) -> Color:
	var h: float = col.h
	var s: float = col.s
	var v: float = col.v

	var is_red: bool = (h >= 0.91 or h <= 0.032) and s >= 0.50 and v >= 0.25
	# Guard band >= 1 so blue eyes in head region (y < 0.415) stay untouched
	var is_blue: bool = band >= 1 and (h >= 0.54 and h <= 0.68) and s >= 0.44 and v >= 0.16
	var is_glove: bool = band >= 2 and (h >= 0.082 and h <= 0.145) and s >= 0.58 and v >= 0.48
	var is_cap_badge: bool = band == 0 and s <= 0.16 and v >= 0.78

	match skin_id:
		"safety_vest":
			if is_red and band == 0:
				# High-vis safety orange cap
				return Color.from_hsv(0.068, clampf(s * 0.96, 0.72, 0.92), clampf(v * 1.12, 0.30, 1.0))
			if is_red and band >= 1:
				# Charcoal undershirt under safety vest
				return Color.from_hsv(0.60, 0.18, clampf(v * 0.44, 0.16, 0.46))
			if is_blue:
				if band <= 2:
					# Bright fluorescent orange torso vest
					return Color.from_hsv(0.062, 0.92, clampf(v * 1.24, 0.44, 1.0))
				elif band == 3:
					# Crisp reflective silver safety band across mid-torso
					return Color.from_hsv(0.58, 0.08, clampf(v * 1.38 + 0.16, 0.68, 0.97))
				else:
					# Deep slate industrial work trousers
					return Color.from_hsv(0.60, 0.28, clampf(v * 0.62, 0.18, 0.46))
			if is_cap_badge:
				return Color(0.95, 0.98, 1.0)
		"mechanic":
			if is_red and band == 0:
				# Slate-steel mechanic cap
				return Color.from_hsv(0.59, 0.36, clampf(v * 0.85, 0.24, 0.74))
			if is_red and band >= 1:
				# Ash grey undershirt
				return Color.from_hsv(0.58, 0.12, clampf(v * 0.86, 0.28, 0.76))
			if is_blue:
				# Deep navy workshop coveralls
				return Color.from_hsv(0.61, 0.66, clampf(v * 0.76, 0.18, 0.64))
		"foreman":
			if is_red and band == 0:
				# Glossy construction safety yellow hardhat
				return Color.from_hsv(0.125, clampf(s * 0.95, 0.74, 0.92), clampf(v * 1.18, 0.38, 1.0))
			if is_red and band >= 1:
				# Clean ivory collared workshirt sleeves
				return Color.from_hsv(0.11, 0.10, clampf(v * 1.15 + 0.08, 0.56, 0.96))
			if is_blue:
				# Tailored warm khaki cargo uniform
				return Color.from_hsv(0.095, 0.46, clampf(v * 1.05, 0.28, 0.80))
		"hazmat":
			if is_red and band == 0:
				# Caution-lime bio containment hood
				return Color.from_hsv(0.185, 0.72, clampf(v * 1.16, 0.42, 0.96))
			if is_cap_badge:
				# Blend cap emblem into bright lime hood cleanly
				return Color(0.86, 0.95, 0.36)
			if is_red and band >= 1:
				# Acid-lime containment sleeves
				return Color.from_hsv(0.195, 0.62, clampf(v * 1.14, 0.40, 0.92))
			if is_blue:
				# Crisp clinical white-mint biohazard suit with teal seam
				if band == 3:
					return Color.from_hsv(0.46, 0.55, clampf(v * 0.95, 0.35, 0.82))
				return Color.from_hsv(0.46, 0.10, clampf(v * 1.25 + 0.18, 0.62, 0.96))
			if is_glove:
				# Sealed bio-teal chemical gloves
				return Color.from_hsv(0.48, 0.76, clampf(v * 0.88, 0.35, 0.86))
		"golden_porter":
			if is_red and band == 0:
				# Lustrous 24K gold prestige cap
				return Color.from_hsv(0.12, 0.80, clampf(v * 1.24, 0.44, 1.0))
			if is_red and band >= 1:
				# Crisp ivory shirt
				return Color.from_hsv(0.11, 0.14, clampf(v * 1.18 + 0.06, 0.58, 0.97))
			if is_blue:
				# Deep obsidian-navy tailored trousers / royal trim
				return Color.from_hsv(0.62, 0.42, clampf(v * 0.58, 0.16, 0.46))

	return col


static func _remap_crate_pixel(skin_id: String, col: Color) -> Color:
	var h: float = col.h
	var s: float = col.s
	var v: float = col.v

	var is_wood: bool = (h >= 0.055 and h <= 0.10) and s >= 0.45
	var is_rivet: bool = (h >= 0.102 and h <= 0.16) and v >= 0.68
	var is_frame: bool = s < 0.36 and v >= 0.14

	match skin_id:
		"steel_container":
			if is_wood:
				# Brushed cool titanium-silver steel planks
				return Color.from_hsv(0.59, 0.24, clampf(v * 1.22 + 0.06, 0.24, 0.86))
			if is_frame:
				return Color.from_hsv(0.60, 0.28, clampf(v * 1.05, 0.16, 0.78))
			if is_rivet:
				return Color.from_hsv(0.58, 0.14, clampf(v * 1.06, 0.72, 0.98))
		"cryo_vault":
			if is_wood:
				# Frosted glacial cyan-white insulated casing
				return Color.from_hsv(0.535, 0.56, clampf(v * 1.42 + 0.10, 0.36, 0.96))
			if is_frame:
				return Color.from_hsv(0.58, 0.52, clampf(v * 1.12, 0.20, 0.78))
			if is_rivet:
				return Color(0.88, 0.98, 1.0)
		"hazard_box":
			if is_wood:
				# Dark matte carbon slate interior
				return Color.from_hsv(0.61, 0.18, clampf(v * 0.64, 0.14, 0.44))
			if is_frame:
				# Caution amber-yellow outer steel frame
				return Color.from_hsv(0.10, 0.86, clampf(v * 1.48 + 0.18, 0.38, 0.98))
			if is_rivet:
				return Color(1.0, 0.85, 0.22)
		"luxury_safe":
			if is_wood:
				# Deep obsidian vault steel panel
				return Color.from_hsv(0.62, 0.22, clampf(v * 0.44, 0.11, 0.32))
			if is_frame:
				# 24K brushed champagne gold outer vault trim
				return Color.from_hsv(0.118, 0.74, clampf(v * 1.46 + 0.18, 0.42, 0.98))
			if is_rivet:
				return Color(1.0, 0.94, 0.68)

	return col


static func draw_worker_accessories(canvas: CanvasItem, rect: Rect2, facing_dir: Vector2i, skin_id: String, anim_time: float = 0.0) -> void:
	if canvas == null or skin_id.is_empty() or skin_id == "classic":
		return
	var hw: float = rect.size.x
	var hh: float = rect.size.y
	var center: Vector2 = rect.get_center()
	var is_side: bool = (facing_dir == Vector2i.LEFT or facing_dir == Vector2i.RIGHT)
	var face_x: float = float(facing_dir.x)

	match skin_id:
		"safety_vest":
			if facing_dir != Vector2i.UP:
				var vest_y: float = rect.position.y + hh * 0.58
				var span: float = hw * (0.11 if is_side else 0.17)
				var cx_off: float = face_x * (hw * 0.04) if is_side else 0.0
				# Compact reflective chest clasp centered inside vest width
				canvas.draw_rect(Rect2(center.x + cx_off - span * 0.3, vest_y - 1.5, span * 0.6, 3.0), Color(0.95, 0.98, 1.0, 0.95))
		"mechanic":
			var belt_y: float = rect.position.y + hh * 0.65
			var half_b: float = hw * (0.14 if is_side else 0.21)
			var cx_off: float = face_x * (hw * 0.03) if is_side else 0.0
			canvas.draw_line(Vector2(center.x + cx_off - half_b, belt_y), Vector2(center.x + cx_off + half_b, belt_y), Color(0.12, 0.14, 0.20, 0.95), maxf(2.0, hh * 0.045))
			if facing_dir != Vector2i.UP:
				var buckle_x: float = center.x + face_x * (hw * 0.06)
				canvas.draw_rect(Rect2(buckle_x - hw * 0.045, belt_y - hh * 0.03, hw * 0.09, hh * 0.06), Color(0.92, 0.78, 0.32, 0.98))
				# Side silver wrench handle
				var wrench_x: float = center.x + (-face_x * hw * 0.08 if is_side else half_b * 0.72)
				canvas.draw_line(Vector2(wrench_x, belt_y), Vector2(wrench_x, belt_y + hh * 0.09), Color(0.82, 0.88, 0.96, 0.95), maxf(1.8, hw * 0.035))
		"foreman":
			if facing_dir != Vector2i.UP:
				var helm_y: float = rect.position.y + hh * 0.17
				var em_x: float = center.x + face_x * (hw * 0.10) if is_side else center.x
				canvas.draw_circle(Vector2(em_x, helm_y), maxf(2.0, hw * 0.042), Color(1.0, 0.96, 0.75, 0.95))
		"hazmat":
			if facing_dir != Vector2i.UP:
				var visor_y: float = rect.position.y + hh * 0.35
				var visor_w: float = hw * (0.115 if is_side else 0.17)
				var visor_x_off: float = face_x * (hw * 0.095) if is_side else 0.0
				var v_rect := Rect2(center.x + visor_x_off - visor_w, visor_y - hh * 0.045, visor_w * 2.0, hh * 0.088)
				canvas.draw_rect(v_rect.grow(1.0), Color(0.06, 0.22, 0.30, 0.85))
				canvas.draw_rect(v_rect, Color(0.22, 0.94, 1.0, 0.90))
				canvas.draw_line(
					Vector2(v_rect.position.x + 2.0, v_rect.position.y + 1.5),
					Vector2(v_rect.end.x - 3.0, v_rect.position.y + 1.5),
					Color(0.92, 1.0, 1.0, 0.95), maxf(1.2, hh * 0.025)
				)
			else:
				var pack_y: float = rect.position.y + hh * 0.56
				canvas.draw_circle(Vector2(center.x - hw * 0.09, pack_y), maxf(2.2, hw * 0.045), Color(0.25, 0.95, 0.55, 0.92))
				canvas.draw_circle(Vector2(center.x + hw * 0.09, pack_y), maxf(2.2, hw * 0.045), Color(0.25, 0.95, 0.55, 0.92))
		"golden_porter":
			if facing_dir != Vector2i.UP:
				# Crisp brass belt buckle + crown jewel badge
				var badge_x: float = center.x + (face_x * hw * 0.09 if is_side else 0.0)
				canvas.draw_circle(Vector2(badge_x, rect.position.y + hh * 0.18), maxf(2.0, hw * 0.045), Color(1.0, 0.92, 0.45, 0.98))
			var t_val: float = anim_time if anim_time > 0.0 else float(Time.get_ticks_msec()) / 1000.0
			var shimmer: float = sin(t_val * 4.5) * 0.25 + 0.75
			canvas.draw_circle(center + Vector2(0, -hh * 0.40), maxf(1.8, hw * 0.045) * shimmer, Color(1.0, 0.95, 0.60, 0.85))
			canvas.draw_circle(center + Vector2(-hw * 0.30, -hh * 0.10), maxf(1.4, hw * 0.032) * (1.2 - shimmer), Color(1.0, 0.85, 0.30, 0.75))
			canvas.draw_circle(center + Vector2(hw * 0.30, -hh * 0.15), maxf(1.4, hw * 0.032) * shimmer, Color(1.0, 0.88, 0.40, 0.75))


static func draw_crate_accessories(canvas: CanvasItem, rect: Rect2, skin_id: String, on_goal: bool = false) -> void:
	if canvas == null or on_goal or skin_id.is_empty() or skin_id == "classic_wood":
		return
	var c_center: Vector2 = rect.get_center()
	var s: float = rect.size.x

	match skin_id:
		"steel_container":
			var brace_len: float = s * 0.22
			var b_col: Color = Color(0.86, 0.94, 1.0, 0.88)
			var lw: float = maxf(1.5, s * 0.042)
			canvas.draw_line(rect.position, rect.position + Vector2(brace_len, 0), b_col, lw)
			canvas.draw_line(rect.position, rect.position + Vector2(0, brace_len), b_col, lw)
			canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - brace_len, rect.position.y), b_col, lw)
			canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + brace_len), b_col, lw)
			canvas.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + brace_len, rect.end.y), b_col, lw)
			canvas.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - brace_len), b_col, lw)
			canvas.draw_line(rect.end, rect.end - Vector2(brace_len, 0), b_col, lw)
			canvas.draw_line(rect.end, rect.end - Vector2(0, brace_len), b_col, lw)
		"hazard_box":
			var c_len: float = s * 0.18
			var lw: float = maxf(2.0, s * 0.065)
			canvas.draw_line(c_center - Vector2(c_len, c_len), c_center + Vector2(c_len, c_len), Color(1.0, 0.72, 0.14, 0.94), lw)
			canvas.draw_line(c_center - Vector2(c_len, -c_len), c_center + Vector2(c_len, -c_len), Color(1.0, 0.72, 0.14, 0.94), lw)
			canvas.draw_circle(c_center, maxf(1.8, s * 0.06), Color(0.12, 0.13, 0.16, 0.95))
		"cryo_vault":
			# Glowing frosted diamond core + 4 crystalline corner studs
			var r_d: float = s * 0.13
			canvas.draw_colored_polygon(PackedVector2Array([
				c_center + Vector2(0, -r_d), c_center + Vector2(r_d, 0),
				c_center + Vector2(0, r_d), c_center + Vector2(-r_d, 0)
			]), Color(0.84, 0.98, 1.0, 0.92))
			var pad: float = s * 0.16
			for pt in [
				rect.position + Vector2(pad, pad),
				rect.position + Vector2(s - pad, pad),
				rect.position + Vector2(pad, rect.size.y - pad),
				rect.position + Vector2(s - pad, rect.size.y - pad)
			]:
				canvas.draw_circle(pt, maxf(1.6, s * 0.045), Color(0.90, 0.99, 1.0, 0.92))
		"luxury_safe":
			canvas.draw_circle(c_center, maxf(4.2, s * 0.135), Color(0.10, 0.11, 0.15, 0.94))
			canvas.draw_circle(c_center, maxf(3.2, s * 0.105), Color(1.0, 0.86, 0.28, 0.98))
			canvas.draw_circle(c_center, maxf(1.4, s * 0.042), Color(0.28, 0.19, 0.05, 1.0))
			var g_pad: float = s * 0.15
			for pt in [
				rect.position + Vector2(g_pad, g_pad),
				rect.position + Vector2(s - g_pad, g_pad),
				rect.position + Vector2(g_pad, rect.size.y - g_pad),
				rect.position + Vector2(s - g_pad, rect.size.y - g_pad)
			]:
				canvas.draw_circle(pt, maxf(1.6, s * 0.048), Color(1.0, 0.88, 0.34, 0.96))

