extends Node

# Inventory Manager
# Adds two things to the game's inventory screen, in the info panel at the bottom right:
#  - Delete: for items you can buy again (the drinks from the vending machine and the ring box). Unstacked items are
#    deleted one by one; for a stack there is "Delete 1" and "Delete all". Favorited items are never deleted.
#  - Open all chests: opens every treasure chest at once, with the same reward the game gives (a cosmetic you don't
#    own yet, otherwise $100), and shows one message instead of one per chest. Favorited chests are left alone.
# It never sorts or reorders the inventory, so it works next to inventory sorting mods.
# Both buttons need a second click within a few seconds, so nothing happens by accident.

const VERSION = "1.0.1"

const CHEST_ID = "treasure_chest"
const DELETABLE_IDS = ["ringbox"]        # sold in the general shop
const DELETABLE_PREFIXES = ["potion_"]   # every drink, all sold in the vending machine
const CONFIRM_TIME = 3.0                 # seconds the second click stays valid
const POLL = 0.1                         # seconds between button updates
const DWELL = 0.25                       # the mouse must rest this long on an item before the buttons switch to it
const RESTORE_AFTER = 0.3                # seconds outside the grid before the info panel goes back to the chosen item

const COL_NORMAL = Color(0.662745, 0.498039, 0.286275, 1)
const COL_HOVER = Color(0.772549, 0.603922, 0.384314, 1)
const COL_PRESSED = Color(0.631373, 0.466667, 0.258824, 1)
const COL_OFF = Color(0.5, 0.42, 0.32, 0.75)
const COL_WARN = Color(0.78, 0.33, 0.27, 1)
const COL_WARN_HOVER = Color(0.86, 0.42, 0.34, 1)
const COL_WARN_PRESSED = Color(0.66, 0.26, 0.21, 1)
const COL_TEXT = Color(1, 0.933333, 0.835294, 1)
const COL_TEXT_OFF = Color(0.85, 0.78, 0.68, 0.7)

var clock = 0.0
var poll = 0.0
var inv = null          # the game's inventory screen
var box = null          # my container of buttons, a child of the info panel
var row = null
var btn_one = null
var btn_all = null
var btn_chests = null
var target_ref = 0      # the item the buttons act on: the last item the mouse RESTED on (see DWELL)
var hover_ref = 0       # the item under the mouse right now (0 = none)
var hover_since = 0.0   # clock time the mouse arrived on hover_ref
var left_at = 0.0       # clock time the mouse last left an item
var panel_stale = false # the game's info panel shows some other item than the target
var armed_what = ""     # "one", "all" or "chests": the button that was clicked once
var armed_ref = 0
var armed_until = 0.0
var last_sig = ""


func _process(delta):
	clock += delta
	if inv != null and is_instance_valid(inv):
		_follow_mouse()
	poll += delta
	if poll < POLL:
		return
	poll = 0.0
	_tick()


# The items sit in a grid, so on the way from an item to the buttons the mouse crosses other items. Those must not
# become the target: an item only counts after the mouse has rested on it for DWELL. The game's info panel changes on
# every item the mouse touches, so once the mouse is off the items it is put back to the chosen item, which means the
# panel and the buttons always talk about the same item.
func _follow_mouse():
	var r = 0
	var hs = inv.get("hovered_slot")
	if typeof(hs) == TYPE_OBJECT and is_instance_valid(hs):
		var sr = hs.get("saved_ref")
		if sr != null:
			r = sr
	if r != hover_ref:
		hover_ref = r
		if r != 0:
			hover_since = clock
			panel_stale = r != target_ref   # the game's panel now shows r
		else:
			left_at = clock
	if hover_ref != 0:
		if hover_ref != target_ref and clock - hover_since >= DWELL:
			target_ref = hover_ref
			panel_stale = false
	elif panel_stale and clock - left_at >= RESTORE_AFTER:
		_restore_panel()


func _slot_for(ref):
	if ref == 0:
		return null
	var grid = inv.get("item_grid")
	if typeof(grid) != TYPE_OBJECT or not is_instance_valid(grid):
		grid = inv.get_node_or_null("Panel/items")
	if grid == null:
		return null
	for c in grid.get_children():
		if c.is_queued_for_deletion():
			continue
		if c.get("saved_ref") == ref:
			return c
	return null


# Shows the target item in the game's info panel again, with the game's own function for hovering an item.
func _restore_panel():
	panel_stale = false
	var slot = _slot_for(target_ref)
	var item = find_item(target_ref)
	if slot == null or item == null or not inv.has_method("_item_entered"):
		return
	inv._item_entered(slot, item)
	inv.hovered_slot = null   # the mouse is not on that item


func _on_button_hover():
	if panel_stale and hover_ref == 0:
		_restore_panel()


func _tick():
	_find_inventory()
	if inv == null or box == null or not is_instance_valid(box):
		return
	if not inv.is_visible_in_tree():
		_disarm()
		last_sig = ""
		return
	# only an item that is on the screen right now can be the target (the page or the tab may have changed)
	if target_ref != 0 and (find_item(target_ref) == null or _slot_for(target_ref) == null):
		target_ref = 0
		panel_stale = false
	_update_ui()


# ---------------------------------------------------------------------------------------------------- finding the screen

func _find_inventory():
	# looked up every time: a new player (new world, respawn) builds a new HUD with a new inventory screen
	var players = get_tree().get_nodes_in_group("controlled_player")
	if players.size() == 0:
		return
	var hud = players[0].get("hud")
	if typeof(hud) != TYPE_OBJECT or not is_instance_valid(hud):
		return
	var screen = hud.get_node_or_null("main/menu/tabs/inventory")
	if screen == null:
		return
	if screen == inv and box != null and is_instance_valid(box):
		return
	if screen.get_node_or_null("Panel3") == null:
		print("[InventoryManager] the inventory screen has no info panel, buttons not added")
		return
	inv = screen
	_build_ui()


func _build_ui():
	var panel = inv.get_node("Panel3")
	var old = panel.get_node_or_null("InventoryManagerButtons")
	if old != null:
		old.queue_free()
	box = VBoxContainer.new()
	box.name = "InventoryManagerButtons"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.margin_left = 12
	box.margin_right = -12
	box.margin_top = -12
	box.margin_bottom = -12
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.add_constant_override("separation", 6)
	box.visible = false
	panel.add_child(box)

	row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_constant_override("separation", 6)
	box.add_child(row)

	btn_one = _make_button("_on_one")
	btn_all = _make_button("_on_all")
	row.add_child(btn_one)
	row.add_child(btn_all)
	btn_chests = _make_button("_on_chests")
	box.add_child(btn_chests)
	last_sig = ""


func _make_button(method):
	var b = Button.new()
	# the game's own button script: hover and click sounds
	var generic = "res://Scenes/Menus/Main Menu/ui_generic_button.gd"
	if ResourceLoader.exists(generic):
		b.set_script(load(generic))
	b.rect_min_size = Vector2(0, 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_color_override("font_color", COL_TEXT)
	b.add_color_override("font_color_hover", COL_TEXT)
	b.add_color_override("font_color_pressed", COL_TEXT)
	b.add_color_override("font_color_disabled", COL_TEXT_OFF)
	b.connect("pressed", self, method)
	b.connect("mouse_entered", self, "_on_button_hover")
	_style(b, false)
	return b


func _style(b, warn):
	b.add_stylebox_override("normal", _box(COL_WARN if warn else COL_NORMAL))
	b.add_stylebox_override("hover", _box(COL_WARN_HOVER if warn else COL_HOVER))
	b.add_stylebox_override("pressed", _box(COL_WARN_PRESSED if warn else COL_PRESSED))
	b.add_stylebox_override("disabled", _box(COL_OFF))
	b.add_stylebox_override("focus", StyleBoxEmpty.new())


func _box(color):
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(8)
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s


# ---------------------------------------------------------------------------------------------------- what is on offer

func is_deletable(id):
	id = str(id)
	if DELETABLE_IDS.has(id):
		return true
	for p in DELETABLE_PREFIXES:
		if id.begins_with(p):
			return true
	return false


func find_item(ref):
	if ref == null or ref == 0:
		return null
	for it in PlayerData.inventory:
		if it.get("ref") == ref:
			return it
	return null


func count_of(item):
	if item.has("count"):
		return int(max(int(item["count"]), 1))
	return 1


func is_favorite(ref):
	return PlayerData.locked_refs.has(ref)


func item_name(id):
	var d = Globals.item_data.get(id)
	if d != null and d.has("file"):
		return str(d["file"].item_name)
	return str(id)


# how many chests "open all" would open (favorited ones are skipped)
func chest_total():
	var total = 0
	for it in PlayerData.inventory:
		if it.get("id") == CHEST_ID and not is_favorite(it.get("ref")):
			total += count_of(it)
	return total


func _armed(what, ref):
	return armed_what == what and armed_ref == ref and clock < armed_until


func _disarm():
	armed_what = ""
	armed_ref = 0
	armed_until = 0.0


func _update_ui():
	var item = find_item(target_ref)
	if item == null:
		target_ref = 0
	var can_delete = item != null and is_deletable(item.get("id"))
	var fav = can_delete and is_favorite(target_ref)
	var count = count_of(item) if can_delete else 0
	var chests = chest_total()
	var a_one = _armed("one", target_ref)
	var a_all = _armed("all", target_ref)
	var a_chests = _armed("chests", 0)
	var sig = str([can_delete, fav, count, chests, a_one, a_all, a_chests, target_ref])
	if sig == last_sig:
		return
	last_sig = sig

	row.visible = can_delete
	btn_one.visible = can_delete
	btn_all.visible = can_delete and count > 1 and not fav
	btn_chests.visible = chests > 0
	box.visible = can_delete or chests > 0

	if can_delete:
		if fav:
			btn_one.text = "Unfavorite to delete"
			btn_one.disabled = true
			_style(btn_one, false)
		else:
			btn_one.disabled = false
			if a_one:
				btn_one.text = "Click again"
			elif count > 1:
				btn_one.text = "Delete 1"
			else:
				btn_one.text = "Delete"
			_style(btn_one, a_one)
		if count > 1 and not fav:
			btn_all.disabled = false
			btn_all.text = "Click again" if a_all else "Delete all (x" + str(count) + ")"
			_style(btn_all, a_all)
	if chests > 0:
		btn_chests.disabled = false
		if a_chests:
			btn_chests.text = "Click again to open " + str(chests)
		else:
			btn_chests.text = "Open all chests (" + str(chests) + ")"
		_style(btn_chests, a_chests)


# ---------------------------------------------------------------------------------------------------- clicks

func _on_one():
	_click("one", target_ref)

func _on_all():
	_click("all", target_ref)

func _on_chests():
	_click("chests", 0)


func _click(what, ref):
	if _armed(what, ref):
		_disarm()
		last_sig = ""
		if what == "chests":
			open_all_chests()
		else:
			delete_item(ref, what == "all")
		return
	armed_what = what
	armed_ref = ref
	armed_until = clock + CONFIRM_TIME
	last_sig = ""
	_update_ui()


func delete_item(ref, whole_stack):
	var item = find_item(ref)
	if item == null:
		return
	var id = item.get("id")
	# checked again here, not only when the button is drawn
	if not is_deletable(id) or is_favorite(ref):
		return
	var count = count_of(item)
	var nm = item_name(id).to_lower()
	if whole_stack and count > 1:
		PlayerData._remove_item(ref, true, true, true)
		PlayerData._send_notification("deleted " + nm + " (x" + str(count) + ")", 1)
	else:
		PlayerData._remove_item(ref)
		PlayerData._send_notification("deleted " + nm, 1)
	target_ref = 0
	last_sig = ""


# Same reward as the game's _open_chest: a cosmetic you don't own yet, otherwise $100.
func open_all_chests():
	var stacks = []
	var total = 0
	for it in PlayerData.inventory:
		if it.get("id") == CHEST_ID and not is_favorite(it.get("ref")):
			var n = count_of(it)
			stacks.append([it["ref"], n])
			total += n
	if total == 0:
		return
	# the game's own switch for silent unlocks: no popup per cosmetic, one summary below instead
	var was_silent = PlayerData.cosmetic_reset_lock
	PlayerData.cosmetic_reset_lock = true
	var got = []
	var cash = 0
	for i in total:
		var cosm = PlayerData._get_unowned_cosmetic()
		if cosm != null:
			PlayerData._unlock_cosmetic(cosm)
			if not PlayerData.new_cosmetics.has(cosm):
				PlayerData.new_cosmetics.append(cosm)
			got.append(cosm)
		else:
			PlayerData.money += 100
			cash += 100
	PlayerData.cosmetic_reset_lock = was_silent
	for s in stacks:
		PlayerData._remove_item(s[0], true, false, true)
	PlayerData.emit_signal("_inventory_refresh")
	PlayerData.emit_signal("_hotbar_refresh")

	var text = "opened " + str(total) + (" chest" if total == 1 else " chests") + ": "
	var parts = []
	if got.size() > 0:
		if got.size() <= 3:
			var names = []
			for c in got:
				names.append(str(Globals.cosmetic_data[c]["file"].name).to_lower())
			parts.append(", ".join(names))
		else:
			parts.append(str(got.size()) + " new cosmetics")
	if cash > 0:
		parts.append("$" + str(cash))
	text += " and ".join(parts)
	PlayerData._send_notification(text)
	last_sig = ""
