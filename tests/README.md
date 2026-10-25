# Tests

`./tests/run.sh` runs `e_inv.gd` headless: stand-ins for the game's inventory screen, player and data, but the item
functions are the game's own (generated from the decompiled game by `make_stubs.sh`, nothing from the game is stored here).
It checks which items can be deleted, the two-click confirm, stacks, favorites, opening chests and rebuilding after a new HUD.

`v_inv.gd` renders the buttons on a mock of the inventory screen (needs the windowed Godot build and `xvfb-run`, set `OUT=<folder>`).
The mock uses the HUD's real anchors and margins, but approximate colors and the default font.
The game's base size is 1920x1080 with 2D stretch, so judge the layout at 1920x1080.
