-- Matrix Button Configuration Quick App
-- Finds Sonos Manager children, Yahue devices and Logic Group Matrix devices.

local APP_NAME = "Matrix Button Configuration"
local APP_VERSION = "1.2.36"
local DEFAULT_SOURCE_LIST = { 1, 2, 3, 11, 12, 13 }
local DEFAULT_BACKUP_GLOBAL_NAME = "MatrixButtonConfigurationBackup"
local DEFAULT_BUTTON_PROFILES = {
  {
    id = "next",
    label = "Next",
    targetType = "sonos",
    keyMap = {
      HeldDown = { "toggleVolumeChange" },
      Released = { "stopVolumeChange" },
      Pressed = { "toggle" },
      Pressed2 = { "next" },
      Pressed3 = { "nextSource", "SOURCE_LIST" },
    },
  },
  {
    id = "prev",
    label = "Prev",
    targetType = "sonos",
    keyMap = {
      HeldDown = { "toggleVolumeChange" },
      Released = { "stopVolumeChange" },
      Pressed = { "toggle" },
      Pressed2 = { "prev" },
      Pressed3 = { "prevSource", "SOURCE_LIST" },
    },
  },
  {
    id = "hue_next",
    label = "Hue Next",
    targetType = "yahue",
    keyMap = {
      HeldDown = { "hueDimToggle", "up" },
      Released = { "hueDimStopToggle" },
      Pressed = { "hueToggle" },
      Pressed2 = { "hueSetValue", 100 },
      Pressed3 = { "hueNextScene" },
    },
  },
  {
    id = "hue_prev",
    label = "Hue Prev",
    targetType = "yahue",
    keyMap = {
      HeldDown = { "hueDimToggle", "down" },
      Released = { "hueDimStopToggle" },
      Pressed = { "hueToggle" },
      Pressed2 = { "hueSetValue", 100 },
      Pressed3 = { "huePrevScene" },
    },
  },
  {
    id = "tahoma_toggle",
    label = "Tahoma Toggle",
    targetType = "tahoma",
    keyMap = {
      HeldDown = { "toggle" },
      Released = { "stop" },
      Pressed = { "toggle" },
      Pressed2 = { "favorit" },
      Pressed3 = { "nextSource" },
    },
  },
  {
    id = "tahoma_open",
    label = "Tahoma Open",
    targetType = "tahoma",
    keyMap = {
      HeldDown = { "open" },
      Released = { "stop" },
      Pressed = { "open" },
      Pressed2 = { "favorit" },
      Pressed3 = { "nextSource" },
    },
  },
  {
    id = "tahoma_close",
    label = "Tahoma Close",
    targetType = "tahoma",
    keyMap = {
      HeldDown = { "close" },
      Released = { "stop" },
      Pressed = { "close" },
      Pressed2 = { "favorit" },
      Pressed3 = { "prevSource" },
    },
  },
}

local function decodeJson(value, fallback)
  if value == nil or value == "" then return fallback end
  local ok, data = pcall(function() return json.decode(value) end)
  if ok and data ~= nil then return data end
  return fallback
end

local function asBool(value, fallback)
  if value == nil or value == "" then return fallback end
  if type(value) == "boolean" then return value end
  value = string.lower(tostring(value or ""))
  if value == "true" or value == "1" or value == "yes" or value == "ja" then return true end
  if value == "false" or value == "0" or value == "no" or value == "nej" then return false end
  return fallback
end

local function encodeJson(value)
  local ok, data = pcall(function() return json.encode(value) end)
  if ok then return data end
  return "{}"
end

local function getVar(vars, name)
  for _, v in ipairs(vars or {}) do
    if v.name == name then return v.value end
  end
  return nil
end

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function contains(value, needle)
  return lower(value):find(lower(needle), 1, true) ~= nil
end

local function roomIdOf(device)
  return device.roomID or device.roomId or ((device.properties or {}).roomID) or 0
end

local function roomNameOf(roomId)
  if roomId == nil or tonumber(roomId) == nil or tonumber(roomId) == 0 then
    return "Intet rum"
  end
  local ok, room = pcall(function() return api.get("/rooms/" .. tostring(roomId)) end)
  if ok and room and room.name then return room.name end
  return "Rum " .. tostring(roomId)
end

local function isDead(device)
  return ((device.properties or {}).dead == true) or device.enabled == false
end

local function isSonosChild(device)
  local props = device.properties or {}
  local vars = props.quickAppVariables or {}
  return device.type == "com.fibaro.sonosSpeaker"
    or getVar(vars, "sonosIp") ~= nil
    or getVar(vars, "sonosPort") ~= nil
end

local YAHUE_QA_UUID = "UPD896846032517896"
local YAHUE_CHILD_CLASSES = {
  BinarySensor = true,
  BinarySwitch = true,
  Button = true,
  ColorLight = true,
  DeviceQA = true,
  DimLight = true,
  DoorSensor = true,
  LuxSensor = true,
  MotionAreaSensor = true,
  MotionSensor = true,
  MultilevelSensor = true,
  RoomZoneQA = true,
  TempLight = true,
  TemperatureSensor = true,
}

local function parentIdOf(device)
  return device.parentId or device.parentID or ((device.properties or {}).parentId) or ((device.properties or {}).parentID) or 0
end

local function quickAppUuidOf(device)
  local props = device.properties or {}
  return tostring(device.quickAppUuid or props.quickAppUuid or props.quickAppUUID or "")
end

local function classNameOf(device)
  local props = device.properties or {}
  return tostring(device.className or props.className or props.quickAppClassName or "")
end

local function isYahueApp(device)
  local props = device.properties or {}
  local vars = props.quickAppVariables or {}
  return getVar(vars, "Hue_IP") ~= nil
    or getVar(vars, "Hue_User") ~= nil
    or quickAppUuidOf(device) == YAHUE_QA_UUID
    or contains(device.name, "Yahue")
end

local function isYahueChild(device, yahueParentIds)
  local parentId = tostring(parentIdOf(device))
  if yahueParentIds[parentId] then return true end
  return YAHUE_CHILD_CLASSES[classNameOf(device)] == true
end

local function isTahomaApp(device)
  local props = device.properties or {}
  local vars = props.quickAppVariables or {}
  local appInfo = decodeJson(getVar(vars, "APPINFO:"), {})
  local appName = tostring(appInfo._APPNAME or "")
  return appName == "LogicTahomaSwitch"
    or contains(device.name, "LogicTahomaSwitch")
    or contains(props.userDescription or "", "Tahoma")
end

local function isTahomaChild(device, tahomaParentIds)
  local parentId = tostring(parentIdOf(device))
  if not tahomaParentIds[parentId] then return false end
  return not isTahomaApp(device)
end

local function sortByName(list)
  table.sort(list, function(a, b)
    local an = lower(a.name)
    local bn = lower(b.name)
    if an == bn then return tonumber(a.id) < tonumber(b.id) end
    return an < bn
  end)
end

local function option(text, value)
  return { type = "option", text = text, value = tostring(value) }
end

local function tableCount(value)
  local count = 0
  for _ in pairs(value or {}) do count = count + 1 end
  return count
end

local function collectProfileVariables(qaId)
  local result = {}
  local props = (api.get("/devices/" .. tostring(qaId or 0)) or {}).properties or {}
  for _, variable in ipairs(props.quickAppVariables or {}) do
    local name = tostring(variable.name or "")
    if name:sub(1, 8) == "profile_" then result[name] = variable.value end
  end
  return result
end

local function cloneArray(list)
  local result = {}
  for _, value in ipairs(list or {}) do result[#result + 1] = value end
  return result
end

local function sortedMatrixIds(matrixIds)
  local ids = cloneArray(matrixIds or {})
  table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
  return ids
end

local function sortedIds(ids)
  local result = {}
  if type(ids) == "table" then
    for _, id in ipairs(ids) do
      if id ~= nil and tostring(id) ~= "" then result[#result + 1] = tostring(id) end
    end
  elseif ids ~= nil and tostring(ids) ~= "" then
    result[#result + 1] = tostring(ids)
  end
  table.sort(result, function(a, b) return tostring(a) < tostring(b) end)
  return result
end

local function mappingKey(sonosId, matrixIds, yahueId, tahomaId)
  local ids = sortedMatrixIds(matrixIds)
  local destinationKey = "sonos:" .. tostring(sonosId or "")
  if yahueId ~= nil and tostring(yahueId) ~= "" then
    destinationKey = destinationKey .. "|yahue:" .. tostring(yahueId)
  end
  local tahomaIds = sortedIds(tahomaId)
  if #tahomaIds > 0 then
    destinationKey = destinationKey .. "|tahoma:" .. table.concat(tahomaIds, ",")
  end
  if #ids == 0 then return destinationKey end
  return destinationKey .. "::" .. table.concat(ids, ",")
end

local function isMappingItem(value)
  return type(value) == "table"
    and type(value.deviceMap) == "table"
    and (value.sonosId ~= nil or value.yahueId ~= nil or value.tahomaId ~= nil or type(value.destinations) == "table")
end

local BUTTON_KEY_IDS = { "1", "2", "3", "4" }
local BUTTON_DEV_KEYS = { "ul", "ur", "ll", "lr" }
local DEFAULT_BUTTON_CONFIG = { ["1"] = "none", ["2"] = "none", ["3"] = "none", ["4"] = "none" }

local function normalizeButtonConfig(config)
  local result = {}
  for _, keyId in ipairs(BUTTON_KEY_IDS) do
    result[keyId] = tostring((config or {})[keyId] or DEFAULT_BUTTON_CONFIG[keyId] or "none")
  end
  return result
end

local function resolveSourceList(value, sourceList)
  if value == "SOURCE_LIST" then return cloneArray(sourceList) end
  if type(value) ~= "table" then return value end

  local result = {}
  for key, item in pairs(value) do
    result[key] = resolveSourceList(item, sourceList)
  end
  return result
end

local function normalizeActionAliases(value)
  if type(value) ~= "table" then return false end

  local changed = false
  if value[1] == "openAll" then
    value[1] = "open"
    changed = true
  elseif value[1] == "closeAll" then
    value[1] = "close"
    changed = true
  end

  for _, item in pairs(value) do
    if normalizeActionAliases(item) then changed = true end
  end

  return changed
end

local function eventValues(event)
  local values = (event or {}).values or (event or {}).value or (event or {}).selectedItems or {}
  if type(values) ~= "table" then return { tostring(values) } end

  if type(values[1]) == "table" and values[1].value == nil then values = values[1] end

  local result = {}
  for _, value in ipairs(values) do
    if type(value) == "table" then
      value = value.value or value.id or value.name or value.text
    end
    if value ~= nil and tostring(value) ~= "" then
      result[#result + 1] = tostring(value)
    end
  end

  if #result == 0 then
    for key, value in pairs(values) do
      if value == true or value == "true" or value == 1 or value == "1" then
        result[#result + 1] = tostring(key)
      elseif type(value) == "table" and value.value ~= nil then
        result[#result + 1] = tostring(value.value)
      end
    end
  end

  return result
end

local function updateSelectedItems(self, elementName, values)
  values = values or {}
  self:updateView(elementName, "selectedItems", values)
  self:updateView(elementName, "values", values)
end

function QuickApp:onInit()
  self:debug("==================================================")
  self:debug(APP_NAME .. " v" .. APP_VERSION .. " starting")
  self:debug("QA id=" .. tostring(self.id) .. " type=" .. tostring(self.type or "?"))
  self:debug("HC3 time=" .. os.date("%Y-%m-%d %H:%M:%S"))
  self:debug("==================================================")

  if self.installIcons then self:installIcons({ "matrix_config" }, true) end

  self.sonosDevices = {}
  self.yahueApps = {}
  self.yahueDevices = {}
  self.yahueApp = nil
  self.tahomaApps = {}
  self.tahomaDevices = {}
  self.tahomaApp = nil
  self.matrixDevices = {}
  self.mapping = decodeJson(self:getVariable("mapping"), {})
  self.backupGlobalName = self:getVariable("backupGlobalName") or DEFAULT_BACKUP_GLOBAL_NAME
  self.useViewLayout = asBool(self:getVariable("useViewLayout"), false)
  self.matrixScope = self:getVariable("matrixScope") or "room"
  self.sourceList = decodeJson(self:getVariable("sourceList"), DEFAULT_SOURCE_LIST)
  self.pendingMatrixIds = sortedMatrixIds(decodeJson(self:getVariable("selectedMatrixIds"), {}))
  self.buttonProfiles = self:loadButtonProfiles()
  self.buttonConfig = normalizeButtonConfig(DEFAULT_BUTTON_CONFIG)
  self.selectedSonosId = nil
  self.selectedYahueId = nil
  self.selectedTahomaId = nil
  self.selectedTahomaIds = {}
  self.yahueSceneIndexes = {}
  self.yahueDimDirections = {}
  self.yahueDimStates = {}

  self:applyViewMode()
  self:updateView("info", "text", APP_NAME .. " v" .. APP_VERSION)
  self:updateButtonProfileOptions()
  self:refresh()
  self:initTriggerEngine()
end

function QuickApp:applyViewMode()
  local props = (api.get("/devices/" .. tostring(self.id)) or {}).properties or {}
  local wantedUseUiView = not self.useViewLayout
  if props.useUiView ~= wantedUseUiView then
    api.put("/devices/" .. tostring(self.id), { properties = { useUiView = wantedUseUiView } })
    self:updateView("info", "text", "Skifter visning - genstarter")
    fibaro.setTimeout(1000, function() plugin.restart() end)
  end
end

function QuickApp:loadDevices()
  local devices = api.get("/devices") or {}
  local sonos = {}
  local yahueApps = {}
  local yahueDevices = {}
  local yahueParentIds = {}
  local tahomaApps = {}
  local tahomaDevices = {}
  local tahomaParentIds = {}
  local matrices = {}

  local selectedYahueAppId = nil
  local selectedTahomaAppId = nil

  for _, device in ipairs(devices) do
    if not isDead(device) and isYahueApp(device) then
      yahueParentIds[tostring(device.id)] = true
      if selectedYahueAppId == nil or tonumber(device.id) > tonumber(selectedYahueAppId) then
        selectedYahueAppId = device.id
      end
      yahueApps[#yahueApps + 1] = {
        id = device.id,
        name = device.name or ("Yahue " .. tostring(device.id)),
        roomId = roomIdOf(device),
        uuid = quickAppUuidOf(device),
      }
    elseif not isDead(device) and isTahomaApp(device) then
      tahomaParentIds[tostring(device.id)] = true
      if selectedTahomaAppId == nil or tonumber(device.id) > tonumber(selectedTahomaAppId) then
        selectedTahomaAppId = device.id
      end
      tahomaApps[#tahomaApps + 1] = {
        id = device.id,
        name = device.name or ("LogicTahomaSwitch " .. tostring(device.id)),
        roomId = roomIdOf(device),
      }
    end
  end

  for _, device in ipairs(devices) do
    if not isDead(device) then
      if isSonosChild(device) then
        local props = device.properties or {}
        local vars = props.quickAppVariables or {}
        sonos[#sonos + 1] = {
          id = device.id,
          name = device.name or ("Sonos " .. tostring(device.id)),
          roomId = roomIdOf(device),
          ip = getVar(vars, "sonosIp") or "",
          parentId = parentIdOf(device),
        }
      elseif tostring(parentIdOf(device)) == tostring(selectedYahueAppId or "") and isYahueChild(device, yahueParentIds) and not isYahueApp(device) then
        yahueDevices[#yahueDevices + 1] = {
          id = device.id,
          name = device.name or ("Hue " .. tostring(device.id)),
          roomId = roomIdOf(device),
          parentId = parentIdOf(device),
          className = classNameOf(device),
          type = device.type or "",
        }
      elseif tostring(parentIdOf(device)) == tostring(selectedTahomaAppId or "") and isTahomaChild(device, tahomaParentIds) then
        tahomaDevices[#tahomaDevices + 1] = {
          id = device.id,
          thId = tostring(device.id),
          name = device.name or ("Tahoma " .. tostring(device.id)),
          roomId = roomIdOf(device),
          parentId = parentIdOf(device),
          className = classNameOf(device),
          type = device.type or "",
        }
      elseif isLogicMatrix(device) then
        local children = api.get("/devices?parentId=" .. tostring(device.id)) or {}
        local matrixType = getMatrixType(device, children)
        local matrixModel, matrixProfile = matrixProfileOf(device, children)
        local sceneId = findMatrixSceneId(device.id, children)
        local relay = nil
        if matrixModel == "ZRB5120" then relay = findMatrixRelays(sceneId, children) end

        matrices[#matrices + 1] = {
          id = device.id,
          name = device.name or ("Matrix " .. tostring(device.id)),
          roomId = matrixRoomId(device, sceneId, children),
          rootRoomId = roomIdOf(device),
          type = matrixType,
          model = matrixModel or "UNKNOWN",
          profileKind = (matrixProfile or {}).kind,
          sceneId = sceneId,
          eventIds = self:matrixEventIds(device.id, sceneId, children, matrixProfile),
          eventEndpoints = self:matrixEventEndpoints(device.id, sceneId, children, matrixProfile),
          keys = profileButtonKeyDevices(matrixProfile, sceneId, children),
          outputs = profileOutputDevices(matrixProfile, children),
          relay = relay,
        }
      end
    end
  end

  sortByName(sonos)
  sortByName(yahueApps)
  sortByName(yahueDevices)
  sortByName(tahomaApps)
  sortByName(tahomaDevices)
  sortByName(matrices)
  self.sonosDevices = sonos
  self.yahueApps = yahueApps
  self.yahueDevices = yahueDevices
  self.tahomaApps = tahomaApps
  self.tahomaDevices = tahomaDevices
  self.yahueApp = nil
  for _, app in ipairs(yahueApps) do
    if tostring(app.id) == tostring(selectedYahueAppId or "") then self.yahueApp = app end
  end
  self.tahomaApp = nil
  for _, app in ipairs(tahomaApps) do
    if tostring(app.id) == tostring(selectedTahomaAppId or "") then self.tahomaApp = app end
  end
  self.matrixDevices = matrices
end

function QuickApp:refresh()
  self:loadDevices()

  local sonosOptions = {}
  for _, sonos in ipairs(self.sonosDevices) do
    local suffix = sonos.ip ~= "" and (" [" .. sonos.ip .. "]") or (" #" .. tostring(sonos.id))
    sonosOptions[#sonosOptions + 1] = option(sonos.name .. " - " .. roomNameOf(sonos.roomId) .. suffix, sonos.id)
  end

  self:updateView("sonosSelect", "options", sonosOptions)

  local current = self.selectedSonosId
  if current ~= nil and self:findSonos(current) ~= nil then
    self.selectedSonosId = tostring(current)
    updateSelectedItems(self, "sonosSelect", { self.selectedSonosId })
  else
    self.selectedSonosId = nil
    updateSelectedItems(self, "sonosSelect", {})
  end

  local yahueOptions = {}
  for _, device in ipairs(self.yahueDevices or {}) do
    yahueOptions[#yahueOptions + 1] = option(device.name .. " - " .. roomNameOf(device.roomId) .. " [" .. tostring(device.className or device.type or "Hue") .. "] #" .. tostring(device.id), device.id)
  end
  self:updateView("yahueSelect", "options", yahueOptions)

  local currentYahue = self.selectedYahueId
  if currentYahue ~= nil and self:findYahueDevice(currentYahue) ~= nil then
    self.selectedYahueId = tostring(currentYahue)
    updateSelectedItems(self, "yahueSelect", { self.selectedYahueId })
  else
    self.selectedYahueId = nil
    updateSelectedItems(self, "yahueSelect", {})
  end

  local tahomaOptions = {}
  for _, device in ipairs(self.tahomaDevices or {}) do
    tahomaOptions[#tahomaOptions + 1] = option(device.name .. " - " .. roomNameOf(device.roomId) .. " [" .. tostring(device.className or device.type or "Tahoma") .. "] #" .. tostring(device.id), device.id)
  end
  self:updateView("tahomaSelect", "options", tahomaOptions)

  local currentTahomaIds = self.selectedTahomaIds or {}
  if #currentTahomaIds == 0 and self.selectedTahomaId ~= nil then currentTahomaIds = { self.selectedTahomaId } end
  local selectedTahomaIds = {}
  for _, id in ipairs(currentTahomaIds or {}) do
    if self:findTahomaDevice(id) ~= nil then selectedTahomaIds[#selectedTahomaIds + 1] = tostring(id) end
  end
  self.selectedTahomaIds = selectedTahomaIds
  self.selectedTahomaId = selectedTahomaIds[1]
  updateSelectedItems(self, "tahomaSelect", selectedTahomaIds)

  self:updateMatrixOptions()
  self:updateSummary()
end

function QuickApp:findSonos(id)
  id = tostring(id or "")
  for _, sonos in ipairs(self.sonosDevices or {}) do
    if tostring(sonos.id) == id then return sonos end
  end
  return nil
end

function QuickApp:findYahueDevice(id)
  id = tostring(id or "")
  for _, device in ipairs(self.yahueDevices or {}) do
    if tostring(device.id) == id then return device end
  end
  return nil
end

function QuickApp:findTahomaDevice(id)
  id = tostring(id or "")
  for _, device in ipairs(self.tahomaDevices or {}) do
    if tostring(device.id) == id or tostring(device.thId) == id or tostring(device.name) == id then return device end
  end
  return nil
end

function QuickApp:findTahomaDevices(ids)
  local result = {}
  for _, id in ipairs(ids or {}) do
    local device = self:findTahomaDevice(id)
    if device ~= nil then result[#result + 1] = device end
  end
  return result
end

function QuickApp:matrixEventIds(rootId, sceneId, children, profile)
  local ids = { tostring(rootId), tostring(sceneId) }

  if profile == nil then
    for _, child in ipairs(children or {}) do ids[#ids + 1] = tostring(child.id) end
    return ids
  end

  local outputEndpoints = profile.outputEndpoints or {}
  local buttonEndpoints = profile.buttonEndpoints or {}
  local hasOutputs = next(outputEndpoints) ~= nil

  for _, child in ipairs(children or {}) do
    local endpoint = endpointOf(child)
    local name = lower(child.name)
    local isSceneChild = tostring(child.id) == tostring(sceneId) or name:find("scene", 1, true) ~= nil
    local isAllowedButton = endpoint ~= nil and buttonEndpoints[endpoint] ~= nil
    local isOutput = endpoint ~= nil and outputEndpoints[endpoint] ~= nil

    if not isOutput and (isSceneChild or isAllowedButton or not hasOutputs) then
      ids[#ids + 1] = tostring(child.id)
    end
  end

  return ids
end

function QuickApp:matrixEventEndpoints(rootId, sceneId, children, profile)
  local endpoints = {
    [tostring(rootId)] = (profile or {}).rootEndpoint or 0,
    [tostring(sceneId)] = (profile or {}).rootEndpoint or 0,
  }

  for _, child in ipairs(children or {}) do
    endpoints[tostring(child.id)] = endpointOf(child)
  end

  return endpoints
end

function QuickApp:matricesInRoom(roomId)
  local result = {}
  for _, matrix in ipairs(self.matrixDevices or {}) do
    if tostring(matrix.roomId) == tostring(roomId) then
      result[#result + 1] = matrix
    end
  end
  return result
end

function QuickApp:updateMatrixScopeControls()
  local scope = self.matrixScope == "all" and "all" or "room"
  self:updateView("matrixScopeRoom", "text", scope == "room" and "Valgt: samme rum" or "Samme rum")
  self:updateView("matrixScopeAll", "text", scope == "all" and "Valgt: alle Matrix" or "Alle Matrix")
end

function QuickApp:updateMatrixOptions()
  local sonos = self:findSonos(self.selectedSonosId)
  local yahue = self:findYahueDevice(self.selectedYahueId)
  local tahoma = (self:findTahomaDevices(self.selectedTahomaIds or {}))[1]
  local roomId = sonos and sonos.roomId or (yahue and yahue.roomId or (tahoma and tahoma.roomId or nil))
  local roomName = roomNameOf(roomId or 0)
  local options = {}
  local selected = {}
  local matrices = self.matrixDevices or {}

  if self.matrixScope ~= "all" and roomId ~= nil and tonumber(roomId) ~= 0 then
    matrices = self:matricesInRoom(roomId)
  end

  for _, matrix in ipairs(matrices) do
    options[#options + 1] = option(matrix.name .. " - " .. matrix.type .. " - " .. roomNameOf(matrix.roomId) .. " #" .. tostring(matrix.id), matrix.id)
  end

  local valid = {}
  for _, matrix in ipairs(matrices) do valid[tostring(matrix.id)] = true end
  for _, id in ipairs(self.pendingMatrixIds or {}) do
    if valid[tostring(id)] then selected[#selected + 1] = tostring(id) end
  end
  table.sort(selected, function(a, b) return tostring(a) < tostring(b) end)

  self:updateMatrixScopeControls()
  self:updateView("matrixSelect", "text", self.matrixScope == "all" and "Alle Matrix" or "Matrix")
  self:updateView("matrixSelect", "options", options)
  updateSelectedItems(self, "matrixSelect", selected)
  self.pendingMatrixIds = selected
  self:setVariable("selectedMatrixIds", encodeJson(selected))

  if self.matrixScope == "all" then
    self:updateView("roomInfo", "text", "Viser alle Matrix - " .. tostring(#options) .. " fundet")
  elseif roomId == nil or tonumber(roomId) == 0 then
    self:updateView("roomInfo", "text", "Vælg destination for samme rum - viser alle Matrix")
  else
    self:updateView("roomInfo", "text", "Viser Matrix i " .. roomName .. " - " .. tostring(#options) .. " fundet")
  end
end

function QuickApp:updateButtonProfileOptions()
  local options = { option("Ingen", "none") }
  for _, profile in ipairs(self.buttonProfiles or {}) do
    if profile.id ~= nil and profile.label ~= nil then
      local targetType = tostring(profile.targetType or "sonos")
      local prefix = "Sonos: "
      if targetType == "yahue" then prefix = "Hue: " end
      if targetType == "tahoma" then prefix = "Tahoma: " end
      options[#options + 1] = option(prefix .. profile.label, profile.id)
    end
  end

  for _, keyId in ipairs(BUTTON_KEY_IDS) do
    self:updateView("button" .. keyId .. "Map", "options", options)
  end
  self:updateButtonProfileSelections()
end

function QuickApp:loadButtonProfiles()
  local profiles = {}
  local byId = {}
  local props = (api.get("/devices/" .. tostring(self.id)) or {}).properties or {}

  for _, profile in ipairs(DEFAULT_BUTTON_PROFILES or {}) do
    local copy = resolveSourceList(profile, self.sourceList or DEFAULT_SOURCE_LIST)
    copy.id = tostring(profile.id)
    normalizeActionAliases(copy.keyMap)
    byId[copy.id] = copy
  end

  for _, variable in ipairs(props.quickAppVariables or {}) do
    local name = tostring(variable.name or "")
    if name:sub(1, 8) == "profile_" then
      local profile = decodeJson(variable.value, nil)
      if type(profile) == "table" then
        local profileChanged = normalizeActionAliases(profile.keyMap)
        profile.id = profile.id or name:sub(9)
        profile.label = profile.label or profile.id
        local defaults = byId[tostring(profile.id)] or {}
        profile.targetType = profile.targetType or defaults.targetType or "sonos"
        profile.keyMap = profile.keyMap or defaults.keyMap
        if normalizeActionAliases(profile.keyMap) then profileChanged = true end
        if profileChanged then self:setVariable(name, encodeJson(profile)) end
        byId[tostring(profile.id)] = profile
      end
    end
  end

  for _, profile in pairs(byId) do profiles[#profiles + 1] = profile end

  table.sort(profiles, function(a, b)
    return tostring(a.label or a.id) < tostring(b.label or b.id)
  end)
  return profiles
end

function QuickApp:profileForId(profileId)
  profileId = tostring(profileId or "")
  for _, profile in ipairs(self.buttonProfiles or {}) do
    if tostring(profile.id or "") == profileId then return profile end
  end
  return nil
end

function QuickApp:profileTargetType(profileId)
  local profile = self:profileForId(profileId)
  return tostring((profile or {}).targetType or "sonos")
end

function QuickApp:buttonConfigUsesTarget(targetType)
  local cfg = normalizeButtonConfig(self.buttonConfig or {})
  for _, keyId in ipairs(BUTTON_KEY_IDS) do
    if cfg[keyId] ~= "none" and self:profileTargetType(cfg[keyId]) == targetType then return true end
  end
  return false
end

function QuickApp:updateButtonProfileSelections()
  self.buttonConfig = normalizeButtonConfig(self.buttonConfig)
  for _, keyId in ipairs(BUTTON_KEY_IDS) do
    updateSelectedItems(self, "button" .. keyId .. "Map", { self.buttonConfig[keyId] })
  end
end

function QuickApp:loadButtonConfigForSelectedSonos()
  local item = {}
  for _, candidate in pairs(self.mapping or {}) do
    if isMappingItem(candidate) and tostring(candidate.sonosId) == tostring(self.selectedSonosId or "") then
      item = candidate
      break
    end
  end
  self.buttonConfig = normalizeButtonConfig(item.buttonConfig or DEFAULT_BUTTON_CONFIG)
  if item.yahueId ~= nil then self.selectedYahueId = tostring(item.yahueId) end
  self:updateButtonProfileSelections()
end

function QuickApp:mappingOptionText(item)
  local sonos = self:findSonos(item.sonosId) or { id = item.sonosId, name = item.sonosName or tostring(item.sonosId or "") }
  local yahue = self:findYahueDevice(item.yahueId) or { id = item.yahueId, name = item.yahueName or tostring(item.yahueId or "") }
  local tahoma = self:findTahomaDevice(item.tahomaId) or { id = item.tahomaId, name = item.tahomaName or tostring(item.tahomaId or "") }
  local tahomaNames = item.tahomaNames or (item.tahomaName and { item.tahomaName } or nil)
  local ids = item.matrixIds or {}
  local cfg = normalizeButtonConfig(item.buttonConfig or {})
  local targets = {}
  if item.sonosId ~= nil then targets[#targets + 1] = "Sonos: " .. tostring(sonos.name) end
  if item.yahueId ~= nil then targets[#targets + 1] = "Hue: " .. tostring(yahue.name) end
  if item.tahomaId ~= nil then targets[#targets + 1] = "Tahoma: " .. table.concat(tahomaNames or { tostring(tahoma.name) }, ", ") end
  local targetText = #targets > 0 and table.concat(targets, " / ") or "Ingen destination"
  return targetText .. " -> Matrix " .. table.concat(ids, ", ") ..
    " | K1:" .. cfg["1"] .. " K2:" .. cfg["2"] .. " K3:" .. cfg["3"] .. " K4:" .. cfg["4"]
end

function QuickApp:updateSummary()
  local lines = {}
  local rows = {}
  local sonosParentIds = {}
  local sonosQaCount = 0
  local activeSonosQaId = nil
  for _, sonos in ipairs(self.sonosDevices or {}) do
    local parentId = tostring(sonos.parentId or "")
    if parentId ~= "" and sonosParentIds[parentId] == nil then
      sonosParentIds[parentId] = true
      sonosQaCount = sonosQaCount + 1
      if activeSonosQaId == nil or tonumber(parentId) > tonumber(activeSonosQaId) then activeSonosQaId = parentId end
    end
  end

  local matrixCounts = { ZBA = 0, ZDB = 0, ZRB = 0, UNKNOWN = 0 }
  for _, matrix in ipairs(self.matrixDevices or {}) do
    local model = tostring(matrix.model or "UNKNOWN")
    if model == "ZBA7140" then
      matrixCounts.ZBA = matrixCounts.ZBA + 1
    elseif model == "ZDB5100" then
      matrixCounts.ZDB = matrixCounts.ZDB + 1
    elseif model == "ZRB5120" then
      matrixCounts.ZRB = matrixCounts.ZRB + 1
    else
      matrixCounts.UNKNOWN = matrixCounts.UNKNOWN + 1
    end
  end

  local function activeText(id)
    return id and (" (aktiv: " .. tostring(id) .. ")") or ""
  end

  local sonosSummary = "Sonos QA: " .. tostring(sonosQaCount) .. activeText(activeSonosQaId) .. " - Sonos childs: " .. tostring(#(self.sonosDevices or {}))
  local yahueSummary = "Yahue QA: " .. tostring(#(self.yahueApps or {})) .. activeText((self.yahueApp or {}).id) .. " - Yahue devices: " .. tostring(#(self.yahueDevices or {}))
  local tahomaSummary = "Tahoma QA: " .. tostring(#(self.tahomaApps or {})) .. activeText((self.tahomaApp or {}).id) .. " - Tahoma devices: " .. tostring(#(self.tahomaDevices or {}))
  local matrixSummary = "Logic Matrix: " .. tostring(#(self.matrixDevices or {})) ..
    " (ZBA: " .. tostring(matrixCounts.ZBA) ..
    ", ZDB: " .. tostring(matrixCounts.ZDB) ..
    ", ZRB: " .. tostring(matrixCounts.ZRB) ..
    (matrixCounts.UNKNOWN > 0 and (", Ukendt: " .. tostring(matrixCounts.UNKNOWN)) or "") ..
    ")"

  if self.useViewLayout then
    lines[#lines + 1] = "<b>" .. sonosSummary .. "</b>"
    lines[#lines + 1] = "<b>" .. yahueSummary .. "</b>"
    lines[#lines + 1] = "<b>" .. tahomaSummary .. "</b>"
    lines[#lines + 1] = "<b>" .. matrixSummary .. "</b>"
  else
    lines[#lines + 1] = sonosSummary
    lines[#lines + 1] = yahueSummary
    lines[#lines + 1] = tahomaSummary
    lines[#lines + 1] = matrixSummary
  end
  self:updateView("summarySonos", "text", sonosSummary)
  self:updateView("summaryYahueApps", "text", yahueSummary)
  self:updateView("summaryTahomaApps", "text", tahomaSummary)
  self:updateView("summaryMatrix", "text", matrixSummary)

  for key, item in pairs(self.mapping or {}) do
    if isMappingItem(item) then
      local sonos = self:findSonos(item.sonosId) or { id = item.sonosId, name = item.sonosName or tostring(item.sonosId) }
      local yahue = self:findYahueDevice(item.yahueId) or { id = item.yahueId, name = item.yahueName or tostring(item.yahueId or "") }
      local tahoma = self:findTahomaDevice(item.tahomaId) or { id = item.tahomaId, name = item.tahomaName or tostring(item.tahomaId or "") }
      local tahomaNames = item.tahomaNames or (item.tahomaName and { item.tahomaName } or nil)
      local ids = item.matrixIds or {}
      if #ids > 0 then
        local cfg = normalizeButtonConfig(item.buttonConfig or {})
        local profileText = "K1:" .. cfg["1"] .. " K2:" .. cfg["2"] .. " K3:" .. cfg["3"] .. " K4:" .. cfg["4"]
        local targetText = "Sonos: " .. tostring(sonos.name)
        if item.sonosId == nil then targetText = "" end
        if item.yahueId ~= nil then
          targetText = targetText ~= "" and (targetText .. " / Hue: " .. tostring(yahue.name)) or ("Hue: " .. tostring(yahue.name))
        end
        if item.tahomaId ~= nil then
          local tahomaText = table.concat(tahomaNames or { tostring(tahoma.name) }, ", ")
          targetText = targetText ~= "" and (targetText .. " / Tahoma: " .. tahomaText) or ("Tahoma: " .. tahomaText)
        end
        local rowText
        if self.useViewLayout then
          rowText = "<font color='darkblue'>" .. targetText .. "</font> -> Matrix " .. table.concat(ids, ", ") ..
            "<br/><font color='grey'>" .. profileText .. "</font>"
        else
          rowText = targetText .. " -> Matrix " .. table.concat(ids, ", ") .. "\n" .. profileText
        end
        rows[#rows + 1] = { mappingKey = tostring(key), sonosId = tostring(sonos.id), text = rowText, optionText = self:mappingOptionText(item) }
      end
    end
  end

  table.sort(rows, function(a, b) return tostring(a.optionText or a.text) < tostring(b.optionText or b.text) end)
  self.savedMappingRows = rows
  self:updateSavedMappingOptions(rows)
  self:updateView("summary", "text", "")
end

function QuickApp:updateSavedMappingOptions(rows)
  local options = {}
  local selectedKey = tostring(self.selectedSavedMappingKey or "")
  local exists = false
  for _, row in ipairs(rows or {}) do
    options[#options + 1] = option(row.optionText or row.text, row.mappingKey)
    if tostring(row.mappingKey) == selectedKey then exists = true end
  end

  if not exists then selectedKey = "" end
  self.selectedSavedMappingKey = selectedKey ~= "" and selectedKey or nil
  local mappingCount = #options
  if mappingCount == 0 then options = { option("Ingen gemte mappings", "") } end
  self:updateView("savedMappingsInfo", "text", "Gemte mappings: " .. tostring(mappingCount))
  self:updateView("savedMappingSelect", "options", options)
  updateSelectedItems(self, "savedMappingSelect", selectedKey ~= "" and { selectedKey } or {})
end

function QuickApp:sonosChanged(event)
  local values = eventValues(event)
  self.selectedSonosId = tostring(values[1] or "")
  self:updateMatrixOptions()
end

function QuickApp:yahueChanged(event)
  local values = eventValues(event)
  self.selectedYahueId = tostring(values[1] or "")
  self:updateMatrixOptions()
end

function QuickApp:tahomaChanged(event)
  local values = eventValues(event)
  self.selectedTahomaIds = values
  self.selectedTahomaId = tostring(values[1] or "")
  if self.selectedTahomaId == "" then self.selectedTahomaId = nil end
  self:updateMatrixOptions()
end

function QuickApp:matrixChanged(event)
  self.pendingMatrixIds = sortedMatrixIds(eventValues(event))
  self:setVariable("selectedMatrixIds", encodeJson(self.pendingMatrixIds))
end

function QuickApp:matrixScopeChanged(event)
  local values = eventValues(event)
  self.matrixScope = tostring(values[1] or "room")
  if self.matrixScope ~= "all" then self.matrixScope = "room" end
  self:setVariable("matrixScope", self.matrixScope)
  self:updateMatrixOptions()
end

function QuickApp:matrixScopeRoom()
  self.matrixScope = "room"
  self:setVariable("matrixScope", self.matrixScope)
  self:updateMatrixOptions()
end

function QuickApp:matrixScopeAll()
  self.matrixScope = "all"
  self:setVariable("matrixScope", self.matrixScope)
  self:updateMatrixOptions()
end

function QuickApp:savedMappingSelected(event)
  local values = eventValues(event)
  self.selectedSavedMappingKey = tostring(values[1] or "")
  if self.selectedSavedMappingKey == "" then self.selectedSavedMappingKey = nil end
end

function QuickApp:button1MapChanged(event) self:setButtonProfile("1", event) end
function QuickApp:button2MapChanged(event) self:setButtonProfile("2", event) end
function QuickApp:button3MapChanged(event) self:setButtonProfile("3", event) end
function QuickApp:button4MapChanged(event) self:setButtonProfile("4", event) end

function QuickApp:setButtonProfile(keyId, event)
  local values = eventValues(event)
  self.buttonConfig = normalizeButtonConfig(self.buttonConfig)
  self.buttonConfig[tostring(keyId)] = tostring(values[1] or "none")
end

function QuickApp:saveMapping()
  local sonos = self:findSonos(self.selectedSonosId)
  local yahue = self:findYahueDevice(self.selectedYahueId)
  local tahomas = self:findTahomaDevices(self.selectedTahomaIds or {})
  local tahoma = tahomas[1]
  local usesSonos = self:buttonConfigUsesTarget("sonos")
  local usesYahue = self:buttonConfigUsesTarget("yahue")
  local usesTahoma = self:buttonConfigUsesTarget("tahoma")
  if usesSonos and sonos == nil then
    self:updateView("info", "text", "Ingen Sonos valgt")
    return
  end
  if usesYahue and yahue == nil then
    self:updateView("info", "text", "Ingen Yahue/Hue valgt")
    return
  end
  if usesTahoma and #tahomas == 0 then
    self:updateView("info", "text", "Ingen Tahoma/Velux valgt")
    return
  end
  if not usesSonos and not usesYahue and not usesTahoma then
    self:updateView("info", "text", "Ingen knap-mapping valgt")
    return
  end

  local matrixIds = self.pendingMatrixIds
  if matrixIds == nil then
    matrixIds = {}
  end
  matrixIds = sortedMatrixIds(matrixIds)
  if #matrixIds == 0 then
    self:updateView("info", "text", "Ingen Matrix valgt")
    return
  end

  local sonosId = usesSonos and sonos and sonos.id or nil
  local yahueId = usesYahue and yahue and yahue.id or nil
  local tahomaIds = {}
  local tahomaNames = {}
  if usesTahoma then
    for _, device in ipairs(tahomas) do
      tahomaIds[#tahomaIds + 1] = tostring(device.id)
      tahomaNames[#tahomaNames + 1] = tostring(device.name)
    end
  end
  local tahomaId = tahomaIds[1]
  local mappedSonos = usesSonos and sonos or nil
  local mappedYahue = usesYahue and yahue or nil
  local mappedTahoma = usesTahoma and tahoma or nil
  local mappedTahomas = usesTahoma and tahomas or {}
  local key = mappingKey(sonosId, matrixIds, yahueId, tahomaIds)
  self.mapping[key] = {
    mappingKey = key,
    sonosId = sonosId,
    sonosName = mappedSonos and mappedSonos.name or nil,
    yahueId = yahueId,
    yahueName = mappedYahue and mappedYahue.name or nil,
    yahueAppId = (self.yahueApp or {}).id,
    tahomaId = tahomaId,
    tahomaIds = tahomaIds,
    tahomaName = mappedTahoma and mappedTahoma.name or nil,
    tahomaNames = tahomaNames,
    tahomaAppId = (self.tahomaApp or {}).id,
    destinations = {
      sonos = mappedSonos and { id = mappedSonos.id, name = mappedSonos.name, managerId = mappedSonos.parentId, roomId = mappedSonos.roomId } or nil,
      yahue = mappedYahue and { id = mappedYahue.id, name = mappedYahue.name, appId = (self.yahueApp or {}).id, roomId = mappedYahue.roomId, className = mappedYahue.className } or nil,
      tahoma = mappedTahoma and { id = mappedTahoma.id, ids = tahomaIds, thId = mappedTahoma.thId, names = tahomaNames, name = mappedTahoma.name, appId = (self.tahomaApp or {}).id, roomId = mappedTahoma.roomId, className = mappedTahoma.className } or nil,
    },
    roomId = mappedSonos and mappedSonos.roomId or (mappedYahue and mappedYahue.roomId or (mappedTahoma and mappedTahoma.roomId or nil)),
    roomName = roomNameOf(mappedSonos and mappedSonos.roomId or (mappedYahue and mappedYahue.roomId or (mappedTahoma and mappedTahoma.roomId or 0))),
    sourceList = self.sourceList,
    buttonConfig = normalizeButtonConfig(self.buttonConfig),
    matrixIds = matrixIds,
    matrices = self:matrixDetails(matrixIds),
    deviceMap = self:buildDeviceMap(mappedSonos, mappedYahue, mappedTahomas, matrixIds),
  }

  self:setVariable("mapping", encodeJson(self.mapping))
  self:updateView("info", "text", "Mapping gemt -> Matrix " .. table.concat(matrixIds, ", "))
  self:clearCurrentSelections()
  self:updateSummary()
end

function QuickApp:clearCurrentSelections()
  self.selectedSonosId = nil
  self.selectedYahueId = nil
  self.selectedTahomaId = nil
  self.selectedTahomaIds = {}
  self.pendingMatrixIds = {}
  self.buttonConfig = normalizeButtonConfig(DEFAULT_BUTTON_CONFIG)
  self:setVariable("selectedMatrixIds", "[]")

  updateSelectedItems(self, "sonosSelect", {})
  updateSelectedItems(self, "yahueSelect", {})
  updateSelectedItems(self, "tahomaSelect", {})
  updateSelectedItems(self, "matrixSelect", {})
  self:updateButtonProfileSelections()
end

function QuickApp:clearMapping()
  local sonos = self:findSonos(self.selectedSonosId)
  local yahue = self:findYahueDevice(self.selectedYahueId)
  local selectedTahomaMap = {}
  for _, id in ipairs(self.selectedTahomaIds or {}) do selectedTahomaMap[tostring(id)] = true end
  if sonos == nil and yahue == nil and next(selectedTahomaMap) == nil then return end

  for key, item in pairs(self.mapping or {}) do
    local hasTahoma = false
    for _, id in ipairs(item.tahomaIds or (item.tahomaId and { item.tahomaId } or {})) do
      if selectedTahomaMap[tostring(id)] then hasTahoma = true end
    end
    if isMappingItem(item) and (
      (sonos ~= nil and tostring(item.sonosId) == tostring(sonos.id)) or
      (yahue ~= nil and tostring(item.yahueId) == tostring(yahue.id)) or
      hasTahoma
    ) then self.mapping[key] = nil end
  end
  self.pendingMatrixIds = {}
  self.buttonConfig = normalizeButtonConfig(DEFAULT_BUTTON_CONFIG)
  self:setVariable("mapping", encodeJson(self.mapping))
  self:updateMatrixOptions()
  self:updateSummary()
  self:updateView("info", "text", "Mapping slettet for valgte destinationer")
end

function QuickApp:loadSelectedSavedMapping()
  local key = tostring(self.selectedSavedMappingKey or "")
  local item = self.mapping and self.mapping[key] or nil
  if not isMappingItem(item) then
    self:updateView("info", "text", "Ingen gemt mapping valgt")
    return
  end

  self.selectedSonosId = item.sonosId ~= nil and tostring(item.sonosId) or nil
  self.selectedYahueId = item.yahueId ~= nil and tostring(item.yahueId) or nil
  self.selectedTahomaId = item.tahomaId ~= nil and tostring(item.tahomaId) or nil
  self.selectedTahomaIds = sortedIds(item.tahomaIds or item.tahomaId)
  self.pendingMatrixIds = sortedMatrixIds(item.matrixIds or {})
  self.buttonConfig = normalizeButtonConfig(item.buttonConfig or DEFAULT_BUTTON_CONFIG)

  local sonos = self:findSonos(self.selectedSonosId)
  local yahue = self:findYahueDevice(self.selectedYahueId)
  local tahoma = (self:findTahomaDevices(self.selectedTahomaIds or {}))[1]
  local roomId = sonos and sonos.roomId or (yahue and yahue.roomId or (tahoma and tahoma.roomId or nil))
  if self.matrixScope ~= "all" and roomId ~= nil and tonumber(roomId) ~= 0 then
    local roomMatrices = {}
    for _, matrix in ipairs(self:matricesInRoom(roomId)) do roomMatrices[tostring(matrix.id)] = true end
    for _, matrixId in ipairs(self.pendingMatrixIds or {}) do
      if not roomMatrices[tostring(matrixId)] then
        self.matrixScope = "all"
        self:setVariable("matrixScope", self.matrixScope)
        break
      end
    end
  end

  updateSelectedItems(self, "sonosSelect", self.selectedSonosId and { self.selectedSonosId } or {})
  updateSelectedItems(self, "yahueSelect", self.selectedYahueId and { self.selectedYahueId } or {})
  updateSelectedItems(self, "tahomaSelect", self.selectedTahomaIds or {})
  self:updateMatrixOptions()
  updateSelectedItems(self, "matrixSelect", self.pendingMatrixIds)
  self:updateButtonProfileSelections()
  self:updateView("info", "text", "Gemt mapping indlæst")
end

function QuickApp:deleteSelectedSavedMapping()
  local key = tostring(self.selectedSavedMappingKey or "")
  local item = self.mapping and self.mapping[key] or nil
  if not isMappingItem(item) then
    self:updateView("info", "text", "Ingen gemt mapping valgt")
    return
  end

  self.mapping[key] = nil
  self.selectedSavedMappingKey = nil
  self:setVariable("mapping", encodeJson(self.mapping))
  self:updateView("info", "text", "Gemt mapping slettet")
  self:updateMatrixOptions()
  self:updateSummary()
end

function QuickApp:dumpMapping()
  self.mapping = decodeJson(self:getVariable("mapping"), self.mapping or {})
  self:loadDevices()

  if tableCount(self.mapping) > 0 then
    self:debug(APP_NAME .. " saved mapping: " .. encodeJson(self.mapping))
    self:debug(APP_NAME .. " discovered Sonos devices: " .. encodeJson(self.sonosDevices or {}))
    self:debug(APP_NAME .. " discovered Yahue apps: " .. encodeJson(self.yahueApps or {}))
    self:debug(APP_NAME .. " discovered Yahue devices: " .. encodeJson(self.yahueDevices or {}))
    self:debug(APP_NAME .. " discovered Tahoma apps: " .. encodeJson(self.tahomaApps or {}))
    self:debug(APP_NAME .. " discovered Tahoma devices: " .. encodeJson(self.tahomaDevices or {}))
    self:debug(APP_NAME .. " discovered matrices: " .. encodeJson(self.matrixDevices or {}))
    self:updateView("info", "text", "Gemt mapping skrevet i debug-log")
    return
  end

  local sonos = self:findSonos(self.selectedSonosId)
  local yahue = self:findYahueDevice(self.selectedYahueId)
  local tahomas = self:findTahomaDevices(self.selectedTahomaIds or {})
  local tahoma = tahomas[1]
  local matrixIds = self.pendingMatrixIds or {}
  if (sonos ~= nil or yahue ~= nil or tahoma ~= nil) and #matrixIds > 0 then
    local draft = {
      sonosId = sonos and sonos.id or nil,
      sonosName = sonos and sonos.name or nil,
      yahueId = yahue and yahue.id or nil,
      yahueName = yahue and yahue.name or nil,
      yahueAppId = (self.yahueApp or {}).id,
      tahomaIds = sortedIds(self.selectedTahomaIds or {}),
      tahomaId = tahoma and tahoma.id or nil,
      tahomaName = tahoma and tahoma.name or nil,
      tahomaAppId = (self.tahomaApp or {}).id,
      matrixIds = matrixIds,
      buttonConfig = normalizeButtonConfig(self.buttonConfig),
      deviceMap = self:buildDeviceMap(sonos, yahue, tahomas, matrixIds),
      defaultSource = self.sourceList or DEFAULT_SOURCE_LIST,
    }
    self:debug(APP_NAME .. " draft mapping (ikke gemt): " .. encodeJson(draft))
    self:debug(APP_NAME .. " discovered Sonos devices: " .. encodeJson(self.sonosDevices or {}))
    self:debug(APP_NAME .. " discovered Yahue apps: " .. encodeJson(self.yahueApps or {}))
    self:debug(APP_NAME .. " discovered Yahue devices: " .. encodeJson(self.yahueDevices or {}))
    self:debug(APP_NAME .. " discovered Tahoma apps: " .. encodeJson(self.tahomaApps or {}))
    self:debug(APP_NAME .. " discovered Tahoma devices: " .. encodeJson(self.tahomaDevices or {}))
    self:debug(APP_NAME .. " discovered matrices: " .. encodeJson(self.matrixDevices or {}))
    self:updateView("info", "text", "Draft mapping skrevet i debug-log - tryk Gem for at gemme")
    return
  end

  self:debug(APP_NAME .. " mapping: ingen gemt mapping")
  self:debug(APP_NAME .. " discovered Sonos devices: " .. encodeJson(self.sonosDevices or {}))
  self:debug(APP_NAME .. " discovered Yahue apps: " .. encodeJson(self.yahueApps or {}))
  self:debug(APP_NAME .. " discovered Yahue devices: " .. encodeJson(self.yahueDevices or {}))
  self:debug(APP_NAME .. " discovered Tahoma apps: " .. encodeJson(self.tahomaApps or {}))
  self:debug(APP_NAME .. " discovered Tahoma devices: " .. encodeJson(self.tahomaDevices or {}))
  self:debug(APP_NAME .. " discovered matrices: " .. encodeJson(self.matrixDevices or {}))
  self:updateView("info", "text", "Ingen gemt mapping endnu")
end

function QuickApp:backupGlobalVariableName()
  local name = self:getVariable("backupGlobalName")
  if name == nil or name == "" then name = self.backupGlobalName or DEFAULT_BACKUP_GLOBAL_NAME end
  return tostring(name)
end

function QuickApp:writeGlobalVariable(name, value)
  local function exists()
    local ok, current = pcall(function()
      if hub and hub.getGlobalVariable then return hub.getGlobalVariable(name) end
      return fibaro.getGlobalVariable(name)
    end)
    return ok and current ~= nil
  end

  if not exists() then
    local createOk, createErr = pcall(function()
      return api.post("/globalVariables/", { name = name })
    end)
    self:debug("Backup global create '" .. name .. "': ok=" .. tostring(createOk) .. " err=" .. tostring(createErr))
  end

  local putOk, putErr = pcall(function()
    return api.put("/globalVariables/" .. name, { value = value })
  end)
  self:debug("Backup global update '" .. name .. "': ok=" .. tostring(putOk) .. " err=" .. tostring(putErr))

  local verify = self:readGlobalVariable(name)
  local verified = verify == value
  self:debug("Backup global verify '" .. name .. "': " .. tostring(verified))
  return putOk and verified
end

function QuickApp:readGlobalVariable(name)
  local ok, value = pcall(function()
    if hub and hub.getGlobalVariable then return hub.getGlobalVariable(name) end
    return nil
  end)
  if ok and value ~= nil and value ~= "" then return value end

  local ok, value = pcall(function() return fibaro.getGlobalVariable(name) end)
  if ok and value ~= nil and value ~= "" then return value end

  ok, value = pcall(function()
    local data = api.get("/globalVariables/" .. name)
    return (data or {}).value
  end)
  if ok then return value end
  return nil
end

function QuickApp:backupMapping()
  self.mapping = decodeJson(self:getVariable("mapping"), self.mapping or {})

  local payload = {
    appName = APP_NAME,
    appVersion = APP_VERSION,
    backupVersion = 1,
    createdAt = os.date("%Y-%m-%d %H:%M:%S"),
    qaId = self.id,
    mapping = self.mapping or {},
    sourceList = self.sourceList or DEFAULT_SOURCE_LIST,
    matrixScope = self.matrixScope or "room",
    profiles = collectProfileVariables(self.id),
  }

  local backupJson = encodeJson(payload)
  local globalName = self:backupGlobalVariableName()
  if self:writeGlobalVariable(globalName, backupJson) then
    self:debug(APP_NAME .. " backup saved to global variable '" .. globalName .. "': " .. backupJson)
    self:updateView("info", "text", "Backup gemt i global variable: " .. globalName)
  else
    self:error("Kunne ikke skrive backup til global variable: " .. globalName)
    self:updateView("info", "text", "Backup fejlede - se log")
  end
end

function QuickApp:restoreMapping()
  local globalName = self:backupGlobalVariableName()
  local backupJson = self:readGlobalVariable(globalName)
  if backupJson == nil or backupJson == "" then
    self:updateView("info", "text", "Ingen backup fundet: " .. globalName)
    return
  end

  local backup = decodeJson(backupJson, nil)
  if type(backup) ~= "table" or type(backup.mapping) ~= "table" then
    self:error("Backup har ugyldigt format i global variable '" .. globalName .. "': " .. tostring(backupJson))
    self:updateView("info", "text", "Backup har ugyldigt format")
    return
  end

  self.mapping = backup.mapping
  self:setVariable("mapping", encodeJson(self.mapping))

  if type(backup.sourceList) == "table" then
    self.sourceList = backup.sourceList
    self:setVariable("sourceList", encodeJson(backup.sourceList))
  end
  if backup.matrixScope ~= nil then
    self.matrixScope = tostring(backup.matrixScope)
    self:setVariable("matrixScope", self.matrixScope)
  end
  if type(backup.profiles) == "table" then
    for name, value in pairs(backup.profiles) do
      if tostring(name):sub(1, 8) == "profile_" then self:setVariable(name, tostring(value or "")) end
    end
  end

  self.buttonProfiles = self:loadButtonProfiles()
  self:updateButtonProfileOptions()
  self:loadDevices()
  self:updateMatrixOptions()
  self:updateSummary()

  self:debug(APP_NAME .. " backup restored from global variable '" .. globalName .. "': " .. backupJson)
  self:updateView("info", "text", "Backup gendannet fra global variable: " .. globalName)
end

function QuickApp:matrixDetails(matrixIds)
  local details = {}
  for _, id in ipairs(matrixIds or {}) do
    for _, matrix in ipairs(self.matrixDevices or {}) do
      if tostring(matrix.id) == tostring(id) then
        details[#details + 1] = {
          id = matrix.id,
          name = matrix.name,
          type = matrix.type,
          model = matrix.model,
          profileKind = matrix.profileKind,
          sceneId = matrix.sceneId,
          eventIds = matrix.eventIds,
          eventEndpoints = matrix.eventEndpoints,
          roomId = matrix.roomId,
          rootRoomId = matrix.rootRoomId,
          keys = matrix.keys,
          outputs = matrix.outputs,
          relay = matrix.relay,
        }
      end
    end
  end
  return details
end

function QuickApp:buildDeviceMap(sonos, yahue, tahomas, matrixIds)
  local deviceMap = {}
  local sourceList = self.sourceList or DEFAULT_SOURCE_LIST
  local buttonConfig = normalizeButtonConfig(self.buttonConfig)
  tahomas = tahomas or {}
  if tahomas.id ~= nil then tahomas = { tahomas } end
  local tahoma = tahomas[1]

  for _, id in ipairs(matrixIds or {}) do
    for _, matrix in ipairs(self.matrixDevices or {}) do
      if tostring(matrix.id) == tostring(id) then
        local sceneId = tostring(matrix.sceneId)
        deviceMap[sceneId] = deviceMap[sceneId] or {}
        deviceMap.__eventAliases = deviceMap.__eventAliases or {}
        deviceMap.__eventEndpoints = deviceMap.__eventEndpoints or {}
        deviceMap.__matrixModels = deviceMap.__matrixModels or {}
        deviceMap.__matrixRootIds = deviceMap.__matrixRootIds or {}
        deviceMap.__matrixKinds = deviceMap.__matrixKinds or {}
        deviceMap.__matrixOutputs = deviceMap.__matrixOutputs or {}
        deviceMap.__matrixModels[sceneId] = matrix.model
        deviceMap.__matrixRootIds[sceneId] = tostring(matrix.id)
        deviceMap.__matrixKinds[sceneId] = matrix.profileKind
        deviceMap.__matrixOutputs[sceneId] = matrix.outputs
        for _, eventId in ipairs(matrix.eventIds or { sceneId }) do
          deviceMap.__eventAliases[tostring(eventId)] = sceneId
          deviceMap.__eventEndpoints[tostring(eventId)] = (matrix.eventEndpoints or {})[tostring(eventId)]
        end
        for index, keyId in ipairs(BUTTON_KEY_IDS) do
          local profile = buttonConfig[keyId]
          local profileDef = self:profileForId(profile) or {}
          local targetType = tostring(profileDef.targetType or "sonos")
          local keyMap = self:keyMapForProfile(profile, sourceList)
          if keyMap ~= nil and (targetType ~= "sonos" or sonos ~= nil) and (targetType ~= "yahue" or yahue ~= nil) and (targetType ~= "tahoma" or tahoma ~= nil) then
            local targetId = sonos and sonos.id or nil
            local targetName = sonos and sonos.name or nil
            local tahomaIds = {}
            local tahomaNames = {}
            local tahomaGroupIds = {}
            if targetType == "yahue" then
              targetId = yahue.id
              targetName = yahue.name
            elseif targetType == "tahoma" then
              targetId = tahoma.id
              targetName = tahoma.name
              for index, device in ipairs(tahomas) do
                tahomaIds[#tahomaIds + 1] = tostring(device.id)
                tahomaNames[#tahomaNames + 1] = tostring(device.name)
                if index > 1 then tahomaGroupIds[#tahomaGroupIds + 1] = tostring(device.thId or device.id) end
              end
            end
            local tahomaGroups = nil
            if targetType == "tahoma" and #tahomaGroupIds > 0 then
              tahomaGroups = { [tostring(tahoma.thId or tahoma.id)] = tahomaGroupIds }
            end
            deviceMap[sceneId][keyId] = {
              devId = matrix.keys[BUTTON_DEV_KEYS[index]],
              targetType = targetType,
              targetId = targetId,
              targetName = targetName,
              sonosId = sonos and sonos.id or nil,
              yahueId = yahue and yahue.id or nil,
              yahueAppId = (self.yahueApp or {}).id,
              tahomaId = tahoma and tahoma.id or nil,
              tahomaName = tahoma and tahoma.name or nil,
              tahomaIds = tahomaIds,
              tahomaNames = tahomaNames,
              tahomaAppId = (self.tahomaApp or {}).id,
              thId = tahoma and (tahoma.thId or tahoma.id) or nil,
              groups = tahomaGroups,
              keyMode = "1Button",
              profile = profile,
              keyMap = keyMap,
            }
          end
        end
      end
    end
  end

  return deviceMap
end

function QuickApp:keyMapForProfile(profileId, sourceList)
  if profileId == nil or profileId == "none" then return nil end

  local profile = self:profileForId(profileId)
  if profile ~= nil and type(profile.keyMap) == "table" then
    return resolveSourceList(profile.keyMap, sourceList or DEFAULT_SOURCE_LIST)
  end

  return nil
end

function QuickApp:buildSwitchActionPayload(sonos, matrixIds)
  return {
    deviceMap = self:buildDeviceMap(sonos, self:findYahueDevice(self.selectedYahueId), self:findTahomaDevices(self.selectedTahomaIds or {}), matrixIds),
    defaultSource = self.sourceList or DEFAULT_SOURCE_LIST,
  }
end

function QuickApp:restart()
  plugin.restart()
end
