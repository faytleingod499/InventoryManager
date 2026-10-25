extends SceneTree
# Headless test of the InventoryManager mod against stand-ins for the game's screen.
# PD's item functions are the game's own code (see stubs/playerdata.gd).

var fails = 0
var PD
var GL
var mod
var inv
var player
var hs  # fake slot under the mouse

class Slot extends Button:
	var saved_ref = 0

class InvStub extends Control:
	var hovered_slot = null
	var tab_type = "tool"

class Cosm extends Resource:
	var name = ""
	var chest_reward = true

class PlayerStub extends Node:
	var hud = null
	var unequipped = []
	func _ready():
		get_node("/root/PlayerData").connect("_item_removal", self, "_gone")
	func _gone(ref):
		unequipped.append(ref)

func check(cond, msg):
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		fails += 1

func item(id, count = 0, ref = -1):
	var e = {"id": id, "size": 1.0, "ref": ref if ref != -1 else randi(), "quality": 0, "tags": []}
	if count > 0:
		e["count"] = count
	PD.inventory.append(e)
	return e["ref"]

func res(nm, stackable = false, sold = true):
	var r = load("res://stubs/item_resource.gd").new()
	r.item_name = nm
	r.stackable = stackable
	r.can_be_sold = sold
	return r

func hover(ref):
	hs.saved_ref = ref
	inv.hovered_slot = hs

func box():
	return inv.get_node("Panel3/InventoryManagerButtons")

func buttons():
	var b = box()
	return [b.get_child(0).get_child(0), b.get_child(0).get_child(1), b.get_child(1)]  # one, all, chests

func click(i):
	buttons()[i].emit_signal("pressed")

func reset_inventory():
	PD.inventory.clear()
	PD.locked_refs.clear()
	PD.notifications.clear()
	PD.hotbar = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	player.unequipped.clear()
	mod._disarm()
	mod.target_ref = 0
	mod.last_sig = ""

func _initialize():
	call_deferred("run")

func run():
	PD = root.get_node("PlayerData")
	GL = root.get_node("Globals")
	# --- the game's data
	GL.item_data = {
		"potion_catch": {"file": res("Catcher's Cola", true, false)},
		"potion_wine": {"file": res("Red Carp-ernet Sauvignon Wine", true, false)},
		"ringbox": {"file": res("Ring Box", false, false)},
		"treasure_chest": {"file": res("Treasure Chest", false, true)},
		"fishing_rod_simple": {"file": res("Simple Rod", false, false)},
		"scratch_off": {"file": res("Scratch-Off", false, true)},
		"fish_lake_salmon": {"file": res("Salmon", false, true)},
	}
	for n in ["a_hat", "b_hat", "c_hat"]:
		var c = Cosm.new()
		c.name = "Hat " + n
		GL.cosmetic_data[n] = {"file": c}
	var closed = Cosm.new()
	closed.name = "Not from chests"
	closed.chest_reward = false
	GL.cosmetic_data["d_shop_only"] = {"file": closed}

	# --- a stand-in for the HUD: hud/main/menu/tabs/inventory/Panel3
	player = PlayerStub.new()
	player.add_to_group("controlled_player")
	root.add_child(player)
	var hud = Control.new()
	var main = Control.new(); main.name = "main"; hud.add_child(main)
	var menu = Control.new(); menu.name = "menu"; main.add_child(menu)
	var tabs = Control.new(); tabs.name = "tabs"; menu.add_child(tabs)
	inv = InvStub.new(); inv.name = "inventory"; tabs.add_child(inv)
	var p3 = Panel.new(); p3.name = "Panel3"; inv.add_child(p3)
	var hdr = RichTextLabel.new(); hdr.name = "header"; p3.add_child(hdr)
	player.hud = hud
	hs = Slot.new()
	root.add_child(hud)
	hud.add_child(hs)

	mod = load("res://mods/InventoryManager/main.gd").new()
	root.add_child(mod)
	yield(create_timer(0.3), "timeout")

	print("== buttons are added to the info panel")
	check(box() != null, "button box exists under Panel3")
	check(box().visible == false, "hidden when there is nothing to do")
	check(mod.inv == inv, "found the inventory screen")

	print("== items that must NOT be deletable")
	reset_inventory()
	var rod = item("fishing_rod_simple")
	var fish = item("fish_lake_salmon")
	var chest = item("treasure_chest")
	var scratch = item("scratch_off")
	for r in [rod, fish, scratch]:
		hover(r)
		yield(create_timer(0.25), "timeout")
		check(buttons()[0].visible == false, "no Delete for " + str(r))
	hover(chest)
	yield(create_timer(0.25), "timeout")
	check(buttons()[0].visible == false, "no Delete for a treasure chest (can't be bought)")
	check(buttons()[2].visible == true, "but Open all chests is offered")
	mod.delete_item(chest, false)
	mod.delete_item(rod, true)
	mod.delete_item(fish, false)
	check(PD.inventory.size() == 4, "delete_item refuses non-deletable items even when called directly")

	print("== a single ring box (not stacked)")
	reset_inventory()
	var rb = item("ringbox")
	PD.hotbar[2] = rb
	hover(rb)
	yield(create_timer(0.25), "timeout")
	check(buttons()[0].visible and buttons()[0].text == "Delete", "button says Delete")
	check(buttons()[1].visible == false, "no Delete all for a single item")
	click(0)
	yield(create_timer(0.25), "timeout")
	check(PD.inventory.size() == 1, "first click does not delete")
	check(buttons()[0].text == "Click again", "button asks for a second click")
	click(0)
	yield(create_timer(0.25), "timeout")
	check(PD.inventory.size() == 0, "second click deletes it")
	check(PD.hotbar[2] == 0, "its hotbar slot was cleared by the game")
	check(player.unequipped.has(rb), "game told the player (unequips if held)")
	check(PD.notifications.size() == 1 and PD.notifications[0][0] == "deleted ring box", "one notification: " + str(PD.notifications))
	check(box().visible == false, "box hides again")

	print("== two separate ring boxes (no stacking mod): deletes one at a time")
	reset_inventory()
	var r1 = item("ringbox")
	var r2 = item("ringbox")
	hover(r1)
	yield(create_timer(0.25), "timeout")
	click(0); click(0)
	yield(create_timer(0.25), "timeout")
	check(PD.inventory.size() == 1 and PD.inventory[0]["ref"] == r2, "only the hovered one is gone")

	print("== a stack of drinks (stacking mod / game stacking)")
	reset_inventory()
	var cola = item("potion_catch", 12)
	hover(cola)
	yield(create_timer(0.25), "timeout")
	check(buttons()[0].text == "Delete 1", "first button says Delete 1")
	check(buttons()[1].visible and buttons()[1].text == "Delete all (x12)", "second button says Delete all (x12)")
	click(0); click(0)
	yield(create_timer(0.25), "timeout")
	check(PD.inventory.size() == 1 and PD.inventory[0]["count"] == 11, "Delete 1 takes one: x11 left")
	check(buttons()[1].text == "Delete all (x11)", "label follows the count")
	click(1)
	yield(create_timer(0.25), "timeout")
	check(PD.inventory.size() == 1, "Delete all needs two clicks too")
	click(1)
	yield(create_timer(0.25), "timeout")
	check(PD.inventory.size() == 0, "the whole stack is gone")
	check(PD.notifications.back()[0] == "deleted catcher's cola (x11)", "notification: " + str(PD.notifications.back()))

	print("== a stack of 2 -> one click each way; stack of 1 with count key behaves as single")
	reset_inventory()
	var two = item("potion_wine", 2)
	var one = item("potion_catch", 1)
	hover(one)
	yield(create_timer(0.25), "timeout")
	check(buttons()[0].text == "Delete" and buttons()[1].visible == false, "count 1 acts like a single item")
	hover(two)
	yield(create_timer(0.25), "timeout")
	check(buttons()[1].visible and buttons()[1].text == "Delete all (x2)", "count 2 offers Delete all")

	print("== second click must come in time and for the same item")
	reset_inventory()
	var da = item("potion_catch", 5)
	var db = item("potion_wine", 5)
	hover(da)
	yield(create_timer(0.25), "timeout")
	click(1)
	hover(db)
	yield(create_timer(0.25), "timeout")
	click(1)
	check(PD.inventory.size() == 2, "arming one item then clicking on another does not delete anything")
	mod._disarm()
	hover(da)
	yield(create_timer(0.25), "timeout")
	click(1)
	mod.armed_until = mod.clock - 0.1
	click(1)
	check(PD.inventory.size() == 2, "a second click after the time ran out only arms again")
	yield(create_timer(0.25), "timeout")
	check(buttons()[1].text == "Click again", "and asks again")
	mod._disarm()
	yield(create_timer(0.25), "timeout")
	check(buttons()[1].text == "Delete all (x5)", "label goes back after disarming")

	print("== favorited items are protected")
	reset_inventory()
	var fav = item("potion_catch", 4)
	PD._lock_item(fav)
	hover(fav)
	yield(create_timer(0.25), "timeout")
	check(buttons()[0].disabled and buttons()[0].text == "Unfavorite to delete", "button disabled with a hint")
	check(buttons()[1].visible == false, "no Delete all")
	click(0); click(0)
	mod.delete_item(fav, true)
	check(PD.inventory.size() == 1 and PD.inventory[0]["count"] == 4, "nothing was deleted, even calling it directly")

	print("== the target follows the mouse and survives leaving the slot")
	reset_inventory()
	var t1 = item("potion_catch", 3)
	hover(t1)
	yield(create_timer(0.25), "timeout")
	inv.hovered_slot = null   # mouse moved to the buttons
	yield(create_timer(0.25), "timeout")
	check(mod.target_ref == t1 and buttons()[0].visible, "item stays selected after the mouse leaves its slot")
	var gone = item("potion_wine", 1)
	hover(gone)
	yield(create_timer(0.25), "timeout")
	PD._remove_item(gone)
	inv.hovered_slot = null
	yield(create_timer(0.25), "timeout")
	check(mod.target_ref == 0, "target resets when the item disappears")

	print("== hidden when the inventory screen is closed")
	reset_inventory()
	var vis = item("ringbox")
	hover(vis)
	yield(create_timer(0.25), "timeout")
	mod.armed_what = "one"; mod.armed_ref = vis; mod.armed_until = mod.clock + 10
	inv.visible = false
	yield(create_timer(0.25), "timeout")
	check(mod.armed_what == "", "arming is dropped when the screen closes")
	inv.visible = true

	print("== open all chests")
	reset_inventory()
	PD.money = 50
	var cs = item("treasure_chest", 5)
	var cu = item("treasure_chest")
	var cf = item("treasure_chest", 2)
	PD._lock_item(cf)
	PD.hotbar[0] = cu
	var keep = item("ringbox")
	PD.notifications.clear()   # the favorite popup above is the game's, not the mod's
	yield(create_timer(0.25), "timeout")
	check(buttons()[2].visible and buttons()[2].text == "Open all chests (6)", "counts stacks + singles, skips the favorited one: " + buttons()[2].text)
	click(2)
	yield(create_timer(0.25), "timeout")
	check(PD.money == 50, "first click opens nothing")
	check(buttons()[2].text == "Click again to open 6", "asks again")
	click(2)
	yield(create_timer(0.25), "timeout")
	check(PD.cosmetics_unlocked.size() == 3, "3 chest cosmetics unlocked (not the shop-only one): " + str(PD.cosmetics_unlocked))
	check(not PD.cosmetics_unlocked.has("d_shop_only"), "shop-only cosmetic never given")
	check(PD.money == 50 + 300, "the other 3 chests paid $100 each: " + str(PD.money))
	check(PD.new_cosmetics.size() == 3, "all 3 are marked new")
	var left = []
	for it in PD.inventory:
		left.append(it["id"])
	check(left.size() == 2 and left.has("ringbox") and left.has("treasure_chest"), "only the ring box and the favorited chests are left: " + str(left))
	check(PD.hotbar[0] == 0, "hotbar slot of the opened chest cleared")
	check(player.unequipped.has(cu), "player told about the removed chest")
	check(PD.notifications.size() == 1, "exactly one popup, not one per chest: " + str(PD.notifications))
	print("   notification: ", PD.notifications[0][0])
	check(PD.cosmetic_reset_lock == false, "silent-unlock flag put back")
	check(buttons()[2].visible == false, "button gone once only the favorited chest is left")

	print("== chests with every cosmetic already owned -> $100 each, singular text")
	reset_inventory()
	PD.money = 0
	PD.cosmetics_unlocked = ["a_hat", "b_hat", "c_hat"]
	item("treasure_chest")
	yield(create_timer(0.25), "timeout")
	click(2); click(2)
	check(PD.money == 100, "got $100")
	check(PD.notifications[0][0] == "opened 1 chest: $100", "text: " + PD.notifications[0][0])

	print("== many chests, many cosmetics -> count not names")
	reset_inventory()
	PD.cosmetics_unlocked = []
	for i in 10:
		var c = Cosm.new()
		c.name = "Extra " + str(i)
		GL.cosmetic_data["x" + str(i)] = {"file": c}
	item("treasure_chest", 6)
	yield(create_timer(0.25), "timeout")
	click(2); click(2)
	check(PD.notifications[0][0] == "opened 6 chests: 6 new cosmetics", "text: " + PD.notifications[0][0])

	print("== the HUD is rebuilt (new player / scene change): buttons come back, no duplicates")
	var old_box = box()
	hud.remove_child(main)
	var main2 = Control.new(); main2.name = "main"; hud.add_child(main2)
	var menu2 = Control.new(); menu2.name = "menu"; main2.add_child(menu2)
	var tabs2 = Control.new(); tabs2.name = "tabs"; menu2.add_child(tabs2)
	var inv2 = InvStub.new(); inv2.name = "inventory"; tabs2.add_child(inv2)
	var p32 = Panel.new(); p32.name = "Panel3"; inv2.add_child(p32)
	main.queue_free()
	inv = inv2
	yield(create_timer(0.4), "timeout")
	check(mod.inv == inv2, "mod follows the new inventory screen")
	check(inv2.get_node_or_null("Panel3/InventoryManagerButtons") != null, "buttons added to the new screen")
	check(inv2.get_node("Panel3").get_child_count() == 1, "exactly one button box")

	print("")
	print("FAILURES: ", fails)
	quit(1 if fails > 0 else 0)
