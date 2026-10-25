# Rebuilds package/InventoryManager/InventoryManager.pck from source/ with the Godot 3.5 engine's own packer.
# Run from this folder with:  godot --no-window -s pack.gd
# (PCK_OUT and PCK_SRC_DIR can be set to absolute paths; PCK_SRC_DIR must be source/mods/InventoryManager.)
extends SceneTree

const FILES = ["main.gd"]

func _init():
	var out = OS.get_environment("PCK_OUT")
	if out == "":
		out = "package/InventoryManager/InventoryManager.pck"
	var src = OS.get_environment("PCK_SRC_DIR")
	if src == "":
		src = "source/mods/InventoryManager"
	var packer = PCKPacker.new()
	packer.pck_start(out, 32)
	for name in FILES:
		packer.add_file("res://mods/InventoryManager/" + name, src.plus_file(name))
	print("pack result: ", packer.flush(true))
	quit()
