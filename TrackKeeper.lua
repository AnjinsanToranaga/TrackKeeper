-- TrackKeeper: remembers the gathering tracking you use (Find Herbs, Find Minerals,
-- Find Treasure, Find Fish) and turns it back on when no tracking is active
-- (death, login, zoning, shapeshifting). Other trackings are never touched.
--
-- The choice is observed, not inferred from menu clicks: whenever a gathering
-- tracking is seen active, it becomes the one to keep. Only one tracking can be
-- active at a time, so DB.wanted is a single spellID.

local ADDON = ...
local DB
local retryPending = false

-- Gathering trackings worth keeping, in priority order (IDs missing in-game are ignored).
local GATHERING = { 2383, 2580, 2481, 43308 } -- Herbs, Minerals, Treasure, Fish
local IS_GATHERING = {}
for _, id in ipairs(GATHERING) do IS_GATHERING[id] = true end

local function msg(text)
  print("|cff33ff99TrackKeeper|r: " .. text)
end

-- Debug log: kept in SavedVariables (DB.log), last 200 lines, only while /tk debug is on.
local function log(text)
  if not (DB and DB.debug) then return end
  DB.log = DB.log or {}
  DB.log[#DB.log + 1] = date("%H:%M:%S") .. " " .. text
  while #DB.log > 200 do table.remove(DB.log, 1) end
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

-- One line with every spell tracking and its state, for the log.
local function spellsText()
  local parts = {}
  if C_Minimap and C_Minimap.GetNumTrackingTypes then
    for i = 1, C_Minimap.GetNumTrackingTypes() do
      local info = C_Minimap.GetTrackingInfo(i)
      if type(info) == "table" and info.type == "spell" then
        parts[#parts + 1] = tostring(info.name) .. "(" .. tostring(info.spellID) .. ")=" .. (info.active and "on" or "off")
      end
    end
  end
  return "spells: " .. (#parts > 0 and table.concat(parts, ", ") or "none")
end

-- Remember an active gathering tracking as the one to keep. Never forgets anything.
local function observe(source)
  local old = DB.wanted
  for _, t in ipairs(trackingList()) do
    if t.active and IS_GATHERING[t.spellID] then DB.wanted = t.spellID; break end
  end
  log("observe (" .. source .. "): wanted " .. tostring(old) .. " -> " .. tostring(DB.wanted) .. "; " .. spellsText())
end

local function restore(source)
  observe(source) -- every attempt is also a chance to see the active gathering tracking
  local function done(decision) log("restore (" .. source .. "): " .. decision .. "; " .. spellsText()) end

  if not DB.enabled then return done("exit: disabled") end
  if not DB.wanted then return done("exit: no wanted") end
  if InCombatLockdown() or UnitIsDeadOrGhost("player") then
    retryPending = true
    return done("exit: combat/dead, retry pending")
  end
  retryPending = false

  local target
  for _, t in ipairs(trackingList()) do
    -- Wanted one already on, or the player chose another (e.g. Track Humanoids): leave it.
    if t.active then return done("exit: active " .. tostring(t.name) .. " (" .. t.spellID .. ")") end
    if t.spellID == DB.wanted then target = t end
  end
  if not target then return done("exit: wanted " .. DB.wanted .. " not found") end

  C_Minimap.SetTracking(target.index, true)
  done("SetTracking(" .. target.index .. ", true) for " .. tostring(target.name))
end

local function scheduleRestore(source)
  C_Timer.After(1, function() restore(source) end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    TrackKeeperDB = TrackKeeperDB or {}
    DB = TrackKeeperDB
    if DB.enabled == nil then DB.enabled = true end
    if DB.debug == nil then DB.debug = false end
    if type(DB.wanted) == "table" then -- 1.0.0 kept a table; keep the first gathering ID
      local old = DB.wanted
      DB.wanted = nil
      for _, id in ipairs(GATHERING) do
        if old[id] then DB.wanted = id; break end
      end
    elseif not IS_GATHERING[DB.wanted] then
      DB.wanted = nil
    end
    log("loaded: wanted=" .. tostring(DB.wanted) .. ", enabled=" .. tostring(DB.enabled))

    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("MINIMAP_UPDATE_TRACKING")
    f:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    f:RegisterEvent("PLAYER_ALIVE")
    f:RegisterEvent("PLAYER_UNGHOST")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(3, function()
      observe(event)
      restore(event)
    end)
  elseif event == "MINIMAP_UPDATE_TRACKING" then
    observe(event)
    scheduleRestore(event)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if retryPending then restore(event) end
  else -- UPDATE_SHAPESHIFT_FORM, PLAYER_ALIVE, PLAYER_UNGHOST
    scheduleRestore(event)
  end
end)

SLASH_TRACKKEEPER1 = "/trackkeeper"
SLASH_TRACKKEEPER2 = "/tk"
SlashCmdList.TRACKKEEPER = function(arg)
  arg = (arg or ""):lower()
  if arg == "on" then
    DB.enabled = true
    msg("enabled")
    restore("/tk on")
  elseif arg == "off" then
    DB.enabled = false
    msg("disabled")
  elseif arg == "debug" then
    DB.debug = not DB.debug
    msg("debug " .. (DB.debug and "on (log saved in TrackKeeperDB.log on /reload or logout)" or "off"))
  elseif arg == "reset" then
    DB.wanted = nil
    msg("forgot remembered tracking. Turn on a gathering tracking to remember it.")
  else
    local t = DB.wanted and findTracking(DB.wanted)
    local name = t and t.name or (DB.wanted and ("spell " .. DB.wanted)) or "nothing yet"
    msg((DB.enabled and "enabled" or "disabled") .. ". Keeping: " .. name)
    msg("commands: /tk on, /tk off, /tk reset, /tk debug")
  end
end
