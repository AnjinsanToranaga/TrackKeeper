# Changelog

## 1.1.0
- Minimap addon menu (addon compartment) support: left-click enables/disables,
  right-click opens a menu (remembered tracking, Enable/Disable, Reset remembered tracking).
- Tooltip in the addon menu shows the current status.

## 1.0.1
- Only gathering trackings are remembered: Find Herbs, Find Minerals, Find Treasure, Find Fish.
- The remembered tracking is the last gathering tracking seen active; nothing is forgotten
  when the game or another tracking switches it off.
- Turns it back on only when no tracking is active, so Track Humanoids and similar
  trackings are never overridden.
- Tracking now comes back after leaving a shapeshift form (e.g. Track Humanoids in Cat Form).
- Removed the conflict cleanup that could forget Find Herbs.
- Fixed: the game resets tracking at login, which made earlier versions forget your choice.
- `/tk` shows the remembered tracking by name; new `/tk debug` log.

## 1.0.0
- First release: remembers chosen minimap tracking per character and restores it after death, login, zoning and shapeshifting.
