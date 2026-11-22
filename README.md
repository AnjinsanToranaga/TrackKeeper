# TrackKeeper

Never lose your minimap tracking again.

TrackKeeper remembers your gathering tracking (Find Herbs, Find Minerals,
Find Treasure, Find Fish) and turns it back on whenever the game drops it:
after dying, logging in, zoning or shapeshifting.

## How it works
- It remembers the last gathering tracking it saw turned on: Find Herbs, Find Minerals,
  Find Treasure or Find Fish. Switch to another one and that becomes the one kept.
- When no tracking is active at all, it turns the remembered one back on
  (after combat, once you are alive, and after you leave a shapeshift form).
- While another tracking such as Track Humanoids is on (e.g. in Cat Form), it does not
  interfere; your gathering tracking comes back once that one is off.
- Want tracking to stay off? Use `/tk off`.

No setup, no options window. Settings are saved per character.

## Minimap addon menu
TrackKeeper appears in the minimap addon menu (the addon compartment).
- Left-click: enable or disable.
- Right-click: menu with the remembered tracking, Enable/Disable and Reset remembered tracking.

## Commands
- `/tk` show status
- `/tk on` / `/tk off` enable or disable
- `/tk reset` forget remembered tracking
- `/tk debug` toggle the debug log (saved in `TrackKeeperDB.log`)
