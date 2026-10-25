# Inventory Manager

Two buttons for the inventory screen that the game is missing: **Delete** and **Open all chests**.

*This mod was created with the assistance of AI.*

- Client side only: nothing is sent to other players, and it works on any server.
- No menu and nothing to set up. The buttons appear in the info panel at the bottom right of the inventory screen.
- Every button needs a second click ("Click again") within a few seconds, so nothing happens by accident.

## Delete

Rest the mouse on an item in your inventory for a moment and its Delete button appears under the item's description. The buttons stay on that item while you move the mouse down to them, even if you cross other items on the way (the info panel switches back to the chosen item once you leave the grid).

- **Only items you can buy again can be deleted**: every drink from the vending machine (Catcher's Cola, Speed Slurpo, Shrink Soda, the wine and the rest) and the ring box. Fish, rods, treasure chests and everything else can't be deleted, because you couldn't get them back.
- **Stacks:** if the item is stacked (the game stacks drinks, and some mods stack more), you get **Delete 1** and **Delete all (xN)**. If it isn't stacked, you get a single **Delete** and it removes just that one.
- **Favorited items are never deleted.** Un-favorite the item first (right-click it).
- If you are holding the item, it is put away.

## Open all chests

When you have treasure chests, an **Open all chests (N)** button appears. It opens every chest at once and gives what the game gives for each one: a cosmetic you don't own yet, or $100 once you own them all. You get one message with the result instead of one pop-up per chest. Favorited chests are left closed.

## Works with other inventory mods

The mod never sorts, moves or restacks anything, so it doesn't fight with inventory sorting or stacking mods. It has not been tested together with them yet.

## Building

The mod is plain GDScript packed into `package/InventoryManager/InventoryManager.pck` with the Godot 3.5 engine's own packer:

```
godot --no-window -s pack.gd
./build.sh
```

`build.sh` makes `out/InventoryManager-mod.zip` (drop the folder into `GDWeave/mods`) and `out/InventoryManager-<version>.zip` (the Thunderstore upload).

## License

[MIT](LICENSE): you are free to copy, change and share your own versions of this mod, as long as you keep the copyright notice.
