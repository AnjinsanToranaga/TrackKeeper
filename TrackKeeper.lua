-- TrackKeeper: remembers the minimap tracking you chose (Find Herbs, Find Minerals,
-- Track Humanoids, ...) and turns it back on when the game drops it
-- (death, login, zoning, shapeshifting).
--
-- How "your choice" is detected:
--   * you pick a tracking from the minimap menu  -> C_Minimap.SetTracking hook
--   * you cast a tracking spell (spellbook/bar)  -> UNIT_SPELLCAST_SUCCEEDED
-- Anything else that turns tracking off is treated as the game dropping it.

local ADDON = ...
local DB
local restoring = false
local retryPending = false

local function msg(text)
  print("|cff33ff99TrackKeeper|r: " .. text)
end

local function trackingList()
  local list = {}
  if not (C_Minimap and C_Minimap.GetNumTrackingTypes) then return list end
  for i = 1, C_Minimap.GetNumTrackingTypes() do
    local info = C_Minimap.GetTrackingInfo(i)
    if type(info) == "table" and info.spellID then
      list[#list + 1] = { index = i, name = info.name, active = info.active, spellID = info.spellID }
    end
  end
  return list
end

local function findTracking(spellID)
  for _, t in ipairs(trackingList()) do
    if t.spellID == spellID then return t end
  end
end

local function remember(spellID, on)
  if on then
    DB.wanted[spellID] = time() -- newest choice wins if two trackings conflict
  else
    DB.wanted[spellID] = nil
  end
end

local function restore()
  if not DB.enabled then return end
  if InCombatLockdown() or UnitIsDeadOrGhost("player") then retryPending = true; return end
  retryPending = false

  local missing = {}
  for _, t in ipairs(trackingList()) do
    if DB.wanted[t.spellID] and not t.active then missing[#missing + 1] = t end
  end
  if #missing == 0 then return end

  restoring = true
  for _, t in ipairs(missing) do C_Minimap.SetTracking(t.index, true) end
  restoring = false

  -- Some game versions allow only one gathering tracking at a time. If turning one
  -- on switched another off, keep only the most recent choice so we never flip-flop.
  C_Timer.After(1, function()
    local newest, newestTime
    for spellID, chosenAt in pairs(DB.wanted) do
      if not newestTime or chosenAt > newestTime then newest, newestTime = spellID, chosenAt end
    end
    for spellID in pairs(DB.wanted) do
      local t = findTracking(spellID)
      if spellID ~= newest and t and not t.active then DB.wanted[spellID] = nil end
    end
  end)
end

local function scheduleRestore()
  C_Timer.After(1, restore)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    TrackKeeperDB = TrackKeeperDB or {}
    DB = TrackKeeperDB
    if DB.enabled == nil then DB.enabled = true end
    DB.wanted = DB.wanted or {}

    hooksecurefunc(C_Minimap, "SetTracking", function(index, on)
      if restoring then return end
      local info = C_Minimap.GetTrackingInfo(index)
      if type(info) == "table" and info.spellID then remember(info.spellID, on) end
    end)

    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_ALIVE")
    f:RegisterEvent("PLAYER_UNGHOST")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("MINIMAP_UPDATE_TRACKING")
    f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    -- First run: adopt whatever is already on as the player's choice.
    if next(DB.wanted) == nil then
      C_Timer.After(3, function()
        for _, t in ipairs(trackingList()) do
          if t.active then remember(t.spellID, true) end
        end
      end)
    end
    scheduleRestore()
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local spellID = select(3, ...)
    if findTracking(spellID) then
      C_Timer.After(0.5, function()
        local t = findTracking(spellID)
        if t then remember(spellID, t.active) end
      end)
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if retryPending then scheduleRestore() end
  else
    scheduleRestore()
  end
end)

SLASH_TRACKKEEPER1 = "/trackkeeper"
SLASH_TRACKKEEPER2 = "/tk"
SlashCmdList.TRACKKEEPER = function(arg)
  arg = (arg or ""):lower()
  if arg == "on" or arg == "off" then
    DB.enabled = (arg == "on")
    msg(DB.enabled and "enabled" or "disabled")
    restore()
  elseif arg == "reset" then
    wipe(DB.wanted)
    msg("forgot remembered tracking. Pick a tracking again to remember it.")
  else
    local names = {}
    for _, t in ipairs(trackingList()) do
      if DB.wanted[t.spellID] then names[#names + 1] = t.name end
    end
    msg((DB.enabled and "enabled" or "disabled") .. ". Keeping: " .. (#names > 0 and table.concat(names, ", ") or "nothing yet"))
    msg("commands: /tk on, /tk off, /tk reset")
  end
end
