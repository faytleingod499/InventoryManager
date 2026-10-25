extends SceneTree
# Renders the mod's buttons on a mock of the game's inventory screen (real anchors/margins of the HUD scene; panel colours and font are approximations).
var PD
var GL
var mod
var inv
var hs
var out = ""

class Slot extends Button:
	var saved_ref = 0
class InvStub extends Control:
	var hovered_slot = null
	var tab_type = "tool"
	var item_grid = null
	func _item_entered(button, item):
		hovered_slot = button
class PlayerStub extends Node:
	var hud = null
class Cosm extends Resource:
	var name = ""
	var chest_reward = true

func panel(parent, nm, al, at, ar, ab, ml, mt, mr, mb, col):
	var p = Panel.new()
	p.name = nm
	p.anchor_left = al; p.anchor_top = at; p.anchor_right = ar; p.anchor_bottom = ab
	p.margin_left = ml; p.margin_top = mt; p.margin_right = mr; p.margin_bottom = mb
	var s = StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(10)
	p.add_stylebox_override("panel", s)
	parent.add_child(p)
	return p

func res(nm):
	var r = load("res://stubs/item_resource.gd").new()
	r.item_name = nm
	return r

func add(id, count = 0):
	var e = {"id": id, "size": 1.0, "ref": randi(), "quality": 0, "tags": []}
	if count > 0: e["count"] = count
	PD.inventory.append(e)
	return e["ref"]

func _initialize():
	call_deferred("run")

func run():
	out = OS.get_environment("OUT")
	PD = root.get_node("PlayerData")
	GL = root.get_node("Globals")
	GL.item_data = {
		"potion_catch": {"file": res("Catcher's Cola")},
		"potion_wine": {"file": res("Red Carp-ernet Sauvignon Wine")},
		"ringbox": {"file": res("Ring Box")},
		"treasure_chest": {"file": res("Treasure Chest")},
	}
	for n in ["a", "b"]:
		var c = Cosm.new(); c.name = "Hat " + n; GL.cosmetic_data[n] = {"file": c}
	var player = PlayerStub.new()
	player.add_to_group("controlled_player")
	root.add_child(player)
	var hud = Control.new()
	hud.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	var bg = ColorRect.new(); bg.color = Color(0.25, 0.35, 0.3); bg.set_anchors_and_margins_preset(Control.PRESET_WIDE); hud.add_child(bg)
	var main = Control.new(); main.name = "main"; main.set_anchors_and_margins_preset(Control.PRESET_WIDE); hud.add_child(main)
	var menu = Control.new(); menu.name = "menu"; menu.set_anchors_and_margins_preset(Control.PRESET_WIDE); main.add_child(menu)
	var back = panel(menu, "Panel", 0.2, 0.3, 0.8, 0.9, 0, 0, 0, 0, Color(0.83, 0.67, 0.45))
	var tabs = Control.new(); tabs.name = "tabs"
	tabs.anchor_left = 0.2; tabs.anchor_top = 0.3; tabs.anchor_right = 0.8; tabs.anchor_bottom = 0.9
	tabs.margin_left = 12; tabs.margin_top = 12; tabs.margin_right = -12; tabs.margin_bottom = -12
	menu.add_child(tabs)
	inv = InvStub.new(); inv.name = "inventory"; inv.set_anchors_and_margins_preset(Control.PRESET_WIDE); tabs.add_child(inv)
	var gpanel = panel(inv, "Panel", 0.0, 0.08, 0.6, 1.0, 12, 12, -12, -12, Color(0.42, 0.27, 0.13))
	var grid = GridContainer.new(); grid.name = "items"; gpanel.add_child(grid)
	inv.item_grid = grid
	panel(inv, "Panel2", 0.6, 0.0, 1.0, 0.6, 12, 12, -12, -12, Color(0.42, 0.27, 0.13))
	var p3 = panel(inv, "Panel3", 0.6, 0.6, 1.0, 1.0, 12, 12, -12, -12, Color(0.42, 0.27, 0.13))
	var header = RichTextLabel.new(); header.name = "header"; header.bbcode_enabled = true
	header.anchor_right = 1.0; header.anchor_bottom = 1.0; header.margin_left = 12; header.margin_top = 12; header.margin_right = -12; header.margin_bottom = -12
	header.add_color_override("default_color", Color(1, 0.933333, 0.835294)); p3.add_child(header)
	var body = RichTextLabel.new(); body.name = "body"; body.bbcode_enabled = true
	body.anchor_right = 1.0; body.anchor_bottom = 1.0; body.margin_left = 12; body.margin_top = 42; body.margin_right = -12; body.margin_bottom = -12
	body.add_color_override("default_color", Color(1, 0.933333, 0.835294)); p3.add_child(body)
	player.hud = hud
	hs = Slot.new(); hs.visible = false
	root.add_child(hud)
	grid.add_child(hs)
	mod = load("res://mods/InventoryManager/main.gd").new()
	root.add_child(mod)
	yield(create_timer(0.5), "timeout")

	var ring = add("ringbox")
	var cola = add("potion_catch", 12)
	var wine = add("potion_wine", 3)
	add("treasure_chest", 4)

	var states = [
		["1_single", ring, "Ring Box", "A romantic gift for someone! (Or yourself?)", ""],
		["2_stack", cola, "Catcher's Cola (x12)", "Gives a catch boost for a while.", ""],
		["3_armed", cola, "Catcher's Cola (x12)", "Gives a catch boost for a while.", "all"],
		["4_fav", wine, "Red Carp-ernet Sauvignon Wine (x3)", "Fancy.", "fav"],
	]
	for st in states:
		mod._disarm()
		PD.locked_refs.clear()
		header.bbcode_text = "[color=#ffeed5]" + st[2] + "[/color]"
		body.bbcode_text = st[3]
		hs.saved_ref = st[1]
		inv.hovered_slot = hs
		if st[4] == "fav": PD.locked_refs.append(wine)
		yield(create_timer(0.7), "timeout")
		if st[4] == "all":
			mod.armed_what = "all"; mod.armed_ref = cola; mod.armed_until = mod.clock + 30; mod.last_sig = ""
			yield(create_timer(0.7), "timeout")
		yield(self, "idle_frame")
		yield(self, "idle_frame")
		var img = root.get_texture().get_data()
		img.flip_y()
		img.save_png(out + "/shot_" + st[0] + ".png")
	quit()
