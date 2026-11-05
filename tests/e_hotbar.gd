extends SceneTree
# Headless test of the bigger hotbar in the InventoryManager mod, against stand-ins for the game's HUD, player and slots.

var fails = 0
var PD
var mod
var player
var hud
var inv
var bar

class HotSlot extends Button:
	var force_hotkey = -1
	var saved_ref = 0
	var slot = 0
	func _setup_item(ref):
		saved_ref = ref

class Tip extends Control:
	var body = ""

class InvSlot extends Button:
	var slot = 0
	var saved_ref = 0
	var hotkey_node = null

class HudStub extends Control:
	var using_chat = false
	var popups = []
	var pressed_with = []
	func _item_pressed(item):
		pressed_with.append(item)

class PlayerStub extends Node:
	var hud = null
	var busy = false
	var locked = false
	var equipped = []
	func _equip_hotbar(slot):
		equipped.append(slot)

class InvStub extends Control:
	var hovered_slot = null
	var tab_type = "tool"
	var item_grid = null
	func _item_entered(button, item):
		hovered_slot = button

func check(cond, msg):
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		fails += 1

func make_hud(slots = 5, centered = true):
	var h = HudStub.new()
	h.rect_size = Vector2(1920, 1080)
	var main = Control.new(); main.name = "main"; h.add_child(main)
	var in_game = Control.new(); in_game.name = "in_game"; main.add_child(in_game)
	var row = HBoxContainer.new(); row.name = "hotbar"
	row.anchor_right = 1.0
	row.rect_size = Vector2(1920, 72)
	row.alignment = BoxContainer.ALIGN_CENTER
	row.add_constant_override("separation", 10)
	in_game.add_child(row)
	for i in range(slots):
		var s = HotSlot.new()
		s.name = "item" + str(i + 1) if i > 0 else "item"
		s.rect_min_size = Vector2(72, 72)
		s.force_hotkey = i + 1
		row.add_child(s)
	var menu = Control.new(); menu.name = "menu"; main.add_child(menu)
	var tabs = Control.new(); tabs.name = "tabs"; menu.add_child(tabs)
	inv = InvStub.new(); inv.name = "inventory"; tabs.add_child(inv); inv.hide()
	var pgrid = Panel.new(); pgrid.name = "Panel"; inv.add_child(pgrid)
	var items = GridContainer.new(); items.name = "items"; pgrid.add_child(items)
	inv.item_grid = items
	var p3 = Panel.new(); p3.name = "Panel3"; inv.add_child(p3)
	var hdr = RichTextLabel.new(); hdr.name = "header"; p3.add_child(hdr)
	return h

# a headless run can't press real keys: the mod can be given the key states instead (see _key_down)
func index_of(code):
	for i in range(mod.HOTBAR_KEYS.size()):
		if mod.HOTBAR_KEYS[i].has(code):
			return i
	return -1

func key(code, down):
	var i = index_of(code)
	if i == -1:
		return
	if mod.key_override == null:
		mod.key_override = [false, false, false, false, false]
	mod.key_override[i] = down

func tap(code):
	key(code, true)
	yield(create_timer(0.05), "timeout")
	key(code, false)
	yield(create_timer(0.05), "timeout")

func slots_of(row):
	var out = []
	for c in row.get_children():
		out.append(c)
	return out

func _initialize():
	call_deferred("run")

func run():
	PD = root.get_node("PlayerData")
	player = PlayerStub.new()
	player.add_to_group("controlled_player")
	root.add_child(player)
	hud = make_hud()
	player.hud = hud
	root.add_child(hud)
	mod = load("res://mods/InventoryManager/main.gd").new()
	root.add_child(mod)
	yield(create_timer(0.4), "timeout")
	bar = hud.get_node("main/in_game/hotbar")

	print("== five slots are added after the game's five")
	check(bar.get_child_count() == 10, "ten slots in the row: " + str(bar.get_child_count()))
	var labels = []
	for c in slots_of(bar):
		labels.append(c.force_hotkey)
	check(labels == [1, 2, 3, 4, 5, 6, 7, 8, 9, 0], "labels 1 2 3 4 5 6 7 8 9 0: " + str(labels))
	check(PD.hotbar.has(5) and PD.hotbar.has(9) and PD.hotbar.size() == 10, "the game's hotbar list has ten entries")
	check(bar.get_child(7).is_connected("pressed", hud, "_item_pressed"), "clicking an extra slot reaches the HUD like the others")
	check(bar.get_child(9).get_script() == bar.get_child(0).get_script(), "extra slots are the same kind of node as the game's")
	check(bar.get_child(9).rect_min_size == Vector2(72, 72), "same size as the game's slots")
	yield(create_timer(0.1), "timeout")
	var first = bar.get_child(0)
	var last = bar.get_child(9)
	var left = first.rect_position.x
	var right = bar.rect_size.x - (last.rect_position.x + last.rect_size.x)
	check(abs(left - right) < 1.0, "the whole row is centred (left gap %s, right gap %s)" % [left, right])
	check(bar.get_child_count() == 10, "no more slots on later ticks")

	print("== keys 6 7 8 9 0 equip their slot")
	player.equipped.clear()
	yield(tap(KEY_6), "completed")
	yield(tap(KEY_7), "completed")
	yield(tap(KEY_8), "completed")
	yield(tap(KEY_9), "completed")
	yield(tap(KEY_0), "completed")
	check(player.equipped == [5, 6, 7, 8, 9], "number row: " + str(player.equipped))
	player.equipped.clear()
	yield(tap(KEY_KP_6), "completed")
	yield(tap(KEY_KP_0), "completed")
	check(player.equipped == [5, 9], "keypad too: " + str(player.equipped))
	player.equipped.clear()
	yield(tap(KEY_1), "completed")
	yield(tap(KEY_5), "completed")
	check(player.equipped.empty(), "keys 1-5 are left to the game")

	print("== typing in chat or a menu: the keys do nothing")
	player.equipped.clear()
	hud.using_chat = true
	player.busy = true
	yield(tap(KEY_6), "completed")
	yield(tap(KEY_0), "completed")
	check(player.equipped.empty(), "chat open: nothing")
	hud.using_chat = false
	yield(tap(KEY_7), "completed")
	check(player.equipped.empty(), "menu open (busy): nothing")
	player.busy = false
	hud.popups = [1]
	yield(tap(KEY_8), "completed")
	check(player.equipped.empty(), "popup open: nothing")
	hud.popups = []
	player.busy = true
	key(KEY_9, true)
	yield(create_timer(0.1), "timeout")
	player.busy = false
	yield(create_timer(0.1), "timeout")
	check(player.equipped.empty(), "a key held down while chat closes does not fire")
	key(KEY_9, false)
	yield(create_timer(0.1), "timeout")
	yield(tap(KEY_9), "completed")
	check(player.equipped == [8], "and works again after: " + str(player.equipped))

	print("== inventory open: hovering an item and pressing 6-0 puts it on that slot")
	player.equipped.clear()
	PD.inventory.clear()
	PD.hotbar = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	yield(create_timer(0.2), "timeout")
	check(PD.hotbar.size() == 10, "a hotbar list brought back short (new game, loaded save) is completed again")
	PD.inventory.append({"id": "x", "size": 1.0, "ref": 4242, "quality": 0, "tags": []})
	PD.inventory.append({"id": "y", "size": 1.0, "ref": 4343, "quality": 0, "tags": []})
	var sl = InvSlot.new()
	sl.slot = 1
	sl.saved_ref = 4343
	var hk = Label.new()
	hk.text = "10"
	sl.hotkey_node = hk
	var root_n = Control.new(); root_n.name = "root"; sl.add_child(root_n)
	var tip = Tip.new(); tip.name = "tooltip_node"; root_n.add_child(tip)
	tip.body = "text\n(Press 1-5 to equip to hotbar)"
	inv.item_grid.add_child(sl)
	inv.hovered_slot = sl
	player.busy = true   # the game marks a menu as busy
	inv.show()
	yield(tap(KEY_8), "completed")
	check(PD.hotbar[7] == 4343, "slot 8 now holds the hovered item: " + str(PD.hotbar[7]))
	check(player.equipped.empty(), "and nothing was equipped")
	yield(tap(KEY_0), "completed")
	check(PD.hotbar[9] == 4343 and PD.hotbar[7] == 0, "key 0 moves it to slot 10 (the game's own bind rule)")
	hud.using_chat = true
	yield(tap(KEY_6), "completed")
	check(PD.hotbar[5] == 0, "typing in chat with the inventory open binds nothing")
	hud.using_chat = false
	inv.hovered_slot = null
	yield(tap(KEY_6), "completed")
	check(PD.hotbar[5] == 0, "no item under the mouse: nothing")
	yield(create_timer(0.2), "timeout")
	check(hk.text == "0", "the inventory's own label for slot 10 reads 0, not 10")
	check(tip.body.find("1-0") != -1 and tip.body.find("1-5") == -1, "tooltip says 1-0: " + tip.body)
	inv.hide()
	player.busy = false

	print("== a new HUD (new world, respawn) gets its own extra slots")
	var hud2 = make_hud()
	var inv2 = inv
	player.hud = hud2
	root.add_child(hud2)
	hud.queue_free()
	yield(create_timer(0.4), "timeout")
	var bar2 = hud2.get_node("main/in_game/hotbar")
	check(bar2.get_child_count() == 10, "new hotbar has ten slots")
	player.equipped.clear()
	yield(tap(KEY_7), "completed")
	check(player.equipped == [6], "keys work on the new HUD")

	print("== a hotbar another mod already widened is left alone")
	var hud3 = make_hud(10)
	player.hud = hud3
	root.add_child(hud3)
	hud2.queue_free()
	yield(create_timer(0.4), "timeout")
	var bar3 = hud3.get_node("main/in_game/hotbar")
	check(bar3.get_child_count() == 10, "still ten slots, none added")
	player.equipped.clear()
	yield(tap(KEY_6), "completed")
	check(player.equipped.empty(), "and the keys are not read")

	print("FAILURES: ", fails)
	quit()
