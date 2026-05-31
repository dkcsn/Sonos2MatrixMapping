-- Matrix Button Configuration Quick App
-- Finds Sonos Manager children, Yahue devices and Logic Group Matrix devices.

local APP_NAME = "Matrix Button Configuration"
local APP_VERSION = "1.2.11"
local DEFAULT_SOURCE_LIST = { 1, 2, 3, 11, 12, 13 }
local MAX_MAPPING_ROWS = 12
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

local function matrixModelOf(device)
  local props = ((device or {}).properties or {})
  local productInfo = props.productInfo or ""
  if type(productInfo) ~= "string" then productInfo = "" end

  local products = {
    { model = "ZBA7140", productInfo = "2,52,0,3,1,36" },
    { model = "ZDB5100", productInfo = "2,52,0,3,1,33" },
    { model = "ZRB5120", productInfo = "2,52,0,3,1,37" },
    { model = "ZRB5120", productInfo = "2,52,0,3,1,41" },
  }

  for _, product in ipairs(products) do
    if productInfo:sub(1, #product.productInfo) == product.productInfo then return product.model end
  end

  local model = lower(props.model or (device or {}).model or (device or {}).name or "")
  if model:find("zba7140", 1, true) then return "ZBA7140" end
  if model:find("zdb5100", 1, true) then return "ZDB5100" end
  if model:find("zrb5120", 1, true) then return "ZRB5120" end

  return nil
end

local function matrixProfileOf(device)
  local model = matrixModelOf(device)
  return model, model and MATRIX_DEVICE_PROFILES and MATRIX_DEVICE_PROFILES[model] or nil
end

local function getMatrixType(device)
  local model, profile = matrixProfileOf(device)
  if model == "ZBA7140" then return "Matrix ZBA7140" end
  if model == "ZDB5100" then return "Matrix ZDB5100" end
  if model == "ZRB5120" then return "Matrix ZRB5120" end
  if profile ~= nil then return "Matrix " .. tostring(model) end

  local props = ((device or {}).properties or {})
  local productInfo = props.productInfo or ""
  if type(productInfo) ~= "string" then productInfo = "" end

  if productInfo:match("^2,52") then
    local model = props.model or (device or {}).model or (device or {}).name or ""
    if tostring(model):lower():find("zlb5180", 1, true) then return "Matrix ZLB5180" end
    if tostring(model):lower():find("matrix", 1, true) then return tostring(model) end
    return "Matrix"
  end
  return ""
end

local function endpointOf(device)
  local props = (device or {}).properties or {}
  local endpoint = props.endpoint or props.endPoint or props.endpointId or props.nodeEndpoint or props.nodeEndpointId or (device or {}).endpoint
  if type(endpoint) == "string" then endpoint = endpoint:match("(%d+)$") or endpoint:match("(%d+)") end
  return tonumber(endpoint)
end

local function childByEndpoint(children, endpoint)
  for _, child in ipairs(children or {}) do
    if endpointOf(child) == endpoint then return child end
  end
  return nil
end

local function profileButtonKeyDevices(profile, sceneId, children)
  local keys = { ul = 0, ur = 0, ll = 0, lr = 0 }
  if profile == nil then
    return {
      ul = sceneId + 3,
      ur = sceneId + 5,
      ll = sceneId + 7,
      lr = sceneId + 9,
    }
  end

  local positions = { [1] = "ul", [2] = "ur", [3] = "ll", [4] = "lr" }
  for endpoint, _ in pairs(profile.buttonEndpoints or {}) do
    local child = childByEndpoint(children, endpoint)
    if child ~= nil and positions[endpoint] ~= nil then keys[positions[endpoint]] = child.id end
  end
  return keys
end

local function profileOutputDevices(profile, children)
  local outputs = {}
  for endpoint, role in pairs((profile or {}).outputEndpoints or {}) do
    local child = childByEndpoint(children, endpoint)
    if child ~= nil then outputs[tostring(role)] = child.id end
  end
  return outputs
end

local function isLogicMatrix(device)
  local productInfo = ((device or {}).properties or {}).productInfo
  local parentId = device.parentId or device.parentID

  if parentId == 1 and type(productInfo) == "string" and productInfo:match("^2,52") then
    return getMatrixType(device) ~= ""
  end

  return false
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

local function mappingKey(sonosId, matrixIds, yahueId)
  local ids = sortedMatrixIds(matrixIds)
  local destinationKey = "sonos:" .. tostring(sonosId or "")
  if yahueId ~= nil and tostring(yahueId) ~= "" then
    destinationKey = destinationKey .. "|yahue:" .. tostring(yahueId)
  end
  if #ids == 0 then return destinationKey end
  return destinationKey .. "::" .. table.concat(ids, ",")
end

local function isMappingItem(value)
  return type(value) == "table"
    and type(value.deviceMap) == "table"
    and (value.sonosId ~= nil or value.yahueId ~= nil or type(value.destinations) == "table")
end

local BUTTON_KEY_IDS = { "1", "2", "3", "4" }
local BUTTON_DEV_KEYS = { "ul", "ur", "ll", "lr" }
local DEFAULT_BUTTON_CONFIG = { ["1"] = "none", ["2"] = "none", ["3"] = "next", ["4"] = "prev" }

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

local function findMatrixSceneId(rootId, children)
  local best = nil
  for _, child in ipairs(children or {}) do
    local name = lower(child.name)
    if name:find("scene", 1, true) then
      if best == nil or child.id < best then best = child.id end
    end
  end
  return best or rootId
end

local function findMatrixRelays(sceneId, children)
  local relays = {}
  for _, child in ipairs(children or {}) do
    local name = lower(child.name)
    if name:find("relae", 1, true) or name:find("relay", 1, true) then
      relays[#relays + 1] = child.id
    end
  end
  table.sort(relays)
  if #relays >= 2 then return { r1 = relays[1], r2 = relays[2] } end
  return { r1 = sceneId + 10, r2 = sceneId + 11 }
end

local function matrixRoomId(rootDevice, sceneId, children)
  for _, child in ipairs(children or {}) do
    if tostring(child.id) == tostring(sceneId) and tonumber(roomIdOf(child)) ~= 0 then
      return roomIdOf(child)
    end
  end
  for _, child in ipairs(children or {}) do
    local name = lower(child.name)
    if name:find("scene", 1, true) and tonumber(roomIdOf(child)) ~= 0 then
      return roomIdOf(child)
    end
  end
  for _, child in ipairs(children or {}) do
    if tonumber(roomIdOf(child)) ~= 0 then
      return roomIdOf(child)
    end
  end
  return roomIdOf(rootDevice)
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
  self.matrixDevices = {}
  self.mapping = decodeJson(self:getVariable("mapping"), {})
  self.backupGlobalName = self:getVariable("backupGlobalName") or DEFAULT_BACKUP_GLOBAL_NAME
  self.useViewLayout = asBool(self:getVariable("useViewLayout"), false)
  self.matrixScope = self:getVariable("matrixScope") or "room"
  self.sourceList = decodeJson(self:getVariable("sourceList"), DEFAULT_SOURCE_LIST)
  self.buttonProfiles = self:loadButtonProfiles()
  self.buttonConfig = normalizeButtonConfig(DEFAULT_BUTTON_CONFIG)
  self.selectedSonosId = nil
  self.selectedYahueId = nil
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
  local matrices = {}

  local selectedYahueAppId = nil

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
      elseif isLogicMatrix(device) then
        local matrixType = getMatrixType(device)
        local matrixModel, matrixProfile = matrixProfileOf(device)
        local children = api.get("/devices?parentId=" .. tostring(device.id)) or {}
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
  sortByName(matrices)
  self.sonosDevices = sonos
  self.yahueApps = yahueApps
  self.yahueDevices = yahueDevices
  self.yahueApp = nil
  for _, app in ipairs(yahueApps) do
    if tostring(app.id) == tostring(selectedYahueAppId or "") then self.yahueApp = app end
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
  if current == nil and self.sonosDevices[1] then current = tostring(self.sonosDevices[1].id) end
  if current ~= nil then
    self.selectedSonosId = tostring(current)
    updateSelectedItems(self, "sonosSelect", { self.selectedSonosId })
  end

  local yahueOptions = {}
  for _, device in ipairs(self.yahueDevices or {}) do
    yahueOptions[#yahueOptions + 1] = option(device.name .. " - " .. roomNameOf(device.roomId) .. " [" .. tostring(device.className or device.type or "Hue") .. "] #" .. tostring(device.id), device.id)
  end
  self:updateView("yahueSelect", "options", yahueOptions)

  local currentYahue = self.selectedYahueId
  if currentYahue == nil and self.yahueDevices[1] then currentYahue = tostring(self.yahueDevices[1].id) end
  if currentYahue ~= nil then
    self.selectedYahueId = tostring(currentYahue)
    updateSelectedItems(self, "yahueSelect", { self.selectedYahueId })
  end

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

function QuickApp:updateMatrixOptions()
  local sonos = self:findSonos(self.selectedSonosId)
  local options = {}
  local selected = {}
  local matrices = {}

  if sonos ~= nil then
    matrices = self.matrixScope == "all" and (self.matrixDevices or {}) or self:matricesInRoom(sonos.roomId)
    for _, matrix in ipairs(matrices) do
      options[#options + 1] = option(matrix.name .. " - " .. matrix.type .. " - " .. roomNameOf(matrix.roomId) .. " #" .. tostring(matrix.id), matrix.id)
    end
    local selectedMap = {}
    for _, item in pairs(self.mapping or {}) do
      if isMappingItem(item) and tostring(item.sonosId) == tostring(sonos.id) then
        for _, id in ipairs(item.matrixIds or {}) do selectedMap[tostring(id)] = true end
      end
    end
    for id, _ in pairs(selectedMap) do selected[#selected + 1] = id end
    table.sort(selected, function(a, b) return tostring(a) < tostring(b) end)
  end

  updateSelectedItems(self, "matrixScopeSelect", { self.matrixScope })
  self:updateView("matrixSelect", "text", self.matrixScope == "all" and "Alle Matrix" or "Matrix i samme rum")
  self:updateView("matrixSelect", "options", options)
  updateSelectedItems(self, "matrixSelect", selected)
  self.pendingMatrixIds = selected
  self:loadButtonConfigForSelectedSonos()

  if sonos == nil then
    self:updateView("roomInfo", "text", "Vælg en Sonos højttaler")
  else
    local scopeText = self.matrixScope == "all" and "alle rum" or roomNameOf(sonos.roomId)
    self:updateView("roomInfo", "text", sonos.name .. " er i " .. roomNameOf(sonos.roomId) .. " - " .. tostring(#options) .. " Matrix fundet (" .. scopeText .. ")")
  end
end

function QuickApp:updateButtonProfileOptions()
  local options = { option("Ingen", "none") }
  for _, profile in ipairs(self.buttonProfiles or {}) do
    if profile.id ~= nil and profile.label ~= nil then
      local prefix = tostring(profile.targetType or "sonos") == "yahue" and "Hue: " or "Sonos: "
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
    byId[copy.id] = copy
  end

  for _, variable in ipairs(props.quickAppVariables or {}) do
    local name = tostring(variable.name or "")
    if name:sub(1, 8) == "profile_" then
      local profile = decodeJson(variable.value, nil)
      if type(profile) == "table" then
        profile.id = profile.id or name:sub(9)
        profile.label = profile.label or profile.id
        local defaults = byId[tostring(profile.id)] or {}
        profile.targetType = profile.targetType or defaults.targetType or "sonos"
        profile.keyMap = profile.keyMap or defaults.keyMap
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

function QuickApp:updateSummary()
  local lines = {}
  local rows = {}
  if self.useViewLayout then
    lines[#lines + 1] = "<b>Sonos childs:</b> " .. tostring(#(self.sonosDevices or {}))
    lines[#lines + 1] = "<b>Yahue apps:</b> " .. tostring(#(self.yahueApps or {}))
    lines[#lines + 1] = "<b>Yahue devices:</b> " .. tostring(#(self.yahueDevices or {}))
    lines[#lines + 1] = "<b>Logic Matrix:</b> " .. tostring(#(self.matrixDevices or {}))
  else
    lines[#lines + 1] = "Sonos childs: " .. tostring(#(self.sonosDevices or {}))
    lines[#lines + 1] = "Yahue apps: " .. tostring(#(self.yahueApps or {}))
    lines[#lines + 1] = "Yahue devices: " .. tostring(#(self.yahueDevices or {}))
    lines[#lines + 1] = "Logic Matrix: " .. tostring(#(self.matrixDevices or {}))
  end
  self:updateView("summarySonos", "text", "Sonos childs: " .. tostring(#(self.sonosDevices or {})))
  self:updateView("summaryYahueApps", "text", "Yahue apps: " .. tostring(#(self.yahueApps or {})) .. ((self.yahueApp or {}).id and (" (aktiv: " .. tostring((self.yahueApp or {}).id) .. ")") or ""))
  self:updateView("summaryYahueDevices", "text", "Yahue devices: " .. tostring(#(self.yahueDevices or {})))
  self:updateView("summaryMatrix", "text", "Logic Matrix: " .. tostring(#(self.matrixDevices or {})))

  for key, item in pairs(self.mapping or {}) do
    if isMappingItem(item) then
      local sonos = self:findSonos(item.sonosId) or { id = item.sonosId, name = item.sonosName or tostring(item.sonosId) }
      local yahue = self:findYahueDevice(item.yahueId) or { id = item.yahueId, name = item.yahueName or tostring(item.yahueId or "") }
      local ids = item.matrixIds or {}
      if #ids > 0 then
        local cfg = normalizeButtonConfig(item.buttonConfig or {})
        local profileText = "K1:" .. cfg["1"] .. " K2:" .. cfg["2"] .. " K3:" .. cfg["3"] .. " K4:" .. cfg["4"]
        local targetText = "Sonos: " .. tostring(sonos.name)
        if item.yahueId ~= nil then targetText = targetText .. " / Hue: " .. tostring(yahue.name) end
        local rowText
        if self.useViewLayout then
          rowText = "<font color='darkblue'>" .. targetText .. "</font> -> Matrix " .. table.concat(ids, ", ") ..
            "<br/><font color='grey'>" .. profileText .. "</font>"
        else
          rowText = targetText .. " -> Matrix " .. table.concat(ids, ", ") .. "\n" .. profileText
        end
        rows[#rows + 1] = { mappingKey = tostring(key), sonosId = tostring(sonos.id), text = rowText }
      end
    end
  end

  self.savedMappingRows = rows
  self:updateSavedMappingRows(rows)
  self:updateView("summary", "text", "")
end

function QuickApp:updateSavedMappingRows(rows)
  for index = 1, MAX_MAPPING_ROWS do
    local row = rows[index]
    if row ~= nil then
      self:updateView("mapLine" .. tostring(index), "text", row.text)
      self:updateView("mapLine" .. tostring(index), "visible", true)
      self:updateView("deleteMap" .. tostring(index), "visible", true)
    else
      self:updateView("mapLine" .. tostring(index), "text", "")
      self:updateView("mapLine" .. tostring(index), "visible", false)
      self:updateView("deleteMap" .. tostring(index), "visible", false)
    end
  end
end

function QuickApp:sonosChanged(event)
  local values = eventValues(event)
  self.selectedSonosId = tostring(values[1] or "")
  self:updateMatrixOptions()
end

function QuickApp:yahueChanged(event)
  local values = eventValues(event)
  self.selectedYahueId = tostring(values[1] or "")
end

function QuickApp:matrixChanged(event)
  self.pendingMatrixIds = eventValues(event)
end

function QuickApp:matrixScopeChanged(event)
  local values = eventValues(event)
  self.matrixScope = tostring(values[1] or "room")
  if self.matrixScope ~= "all" then self.matrixScope = "room" end
  self:setVariable("matrixScope", self.matrixScope)
  self:updateMatrixOptions()
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
  if self:buttonConfigUsesTarget("sonos") and sonos == nil then
    self:updateView("info", "text", "Ingen Sonos valgt")
    return
  end
  if self:buttonConfigUsesTarget("yahue") and yahue == nil then
    self:updateView("info", "text", "Ingen Yahue/Hue valgt")
    return
  end

  local matrixIds = self.pendingMatrixIds
  if matrixIds == nil then
    matrixIds = {}
  end
  matrixIds = sortedMatrixIds(matrixIds)

  local sonosId = sonos and sonos.id or nil
  local yahueId = yahue and yahue.id or nil
  local key = mappingKey(sonosId, matrixIds, yahueId)
  self.mapping[key] = {
    mappingKey = key,
    sonosId = sonosId,
    sonosName = sonos and sonos.name or nil,
    yahueId = yahueId,
    yahueName = yahue and yahue.name or nil,
    yahueAppId = (self.yahueApp or {}).id,
    destinations = {
      sonos = sonos and { id = sonos.id, name = sonos.name, managerId = sonos.parentId, roomId = sonos.roomId } or nil,
      yahue = yahue and { id = yahue.id, name = yahue.name, appId = (self.yahueApp or {}).id, roomId = yahue.roomId, className = yahue.className } or nil,
    },
    roomId = sonos and sonos.roomId or (yahue and yahue.roomId or nil),
    roomName = roomNameOf(sonos and sonos.roomId or (yahue and yahue.roomId or 0)),
    sourceList = self.sourceList,
    buttonConfig = normalizeButtonConfig(self.buttonConfig),
    matrixIds = matrixIds,
    matrices = self:matrixDetails(matrixIds),
    deviceMap = self:buildDeviceMap(sonos, yahue, matrixIds),
  }

  self:setVariable("mapping", encodeJson(self.mapping))
  self:updateView("info", "text", "Mapping gemt -> Matrix " .. table.concat(matrixIds, ", "))
  self:updateSummary()
end

function QuickApp:clearMapping()
  local sonos = self:findSonos(self.selectedSonosId)
  if sonos == nil then return end

  for key, item in pairs(self.mapping or {}) do
    if isMappingItem(item) and tostring(item.sonosId) == tostring(sonos.id) then self.mapping[key] = nil end
  end
  self.pendingMatrixIds = {}
  self.buttonConfig = normalizeButtonConfig(DEFAULT_BUTTON_CONFIG)
  self:setVariable("mapping", encodeJson(self.mapping))
  self:updateMatrixOptions()
  self:updateSummary()
  self:updateView("info", "text", "Mapping slettet for " .. sonos.name)
end

function QuickApp:deleteSavedMapping(index)
  local rows = self.savedMappingRows or {}
  local row = rows[tonumber(index) or 0]
  if row == nil then return end

  local item = self.mapping[row.mappingKey]
  self.mapping[row.mappingKey] = nil
  self:setVariable("mapping", encodeJson(self.mapping))
  self:updateView("info", "text", "Mapping slettet for " .. tostring((item or {}).sonosName or row.sonosId))
  self:updateMatrixOptions()
  self:updateSummary()
end

function QuickApp:deleteMap1() self:deleteSavedMapping(1) end
function QuickApp:deleteMap2() self:deleteSavedMapping(2) end
function QuickApp:deleteMap3() self:deleteSavedMapping(3) end
function QuickApp:deleteMap4() self:deleteSavedMapping(4) end
function QuickApp:deleteMap5() self:deleteSavedMapping(5) end
function QuickApp:deleteMap6() self:deleteSavedMapping(6) end
function QuickApp:deleteMap7() self:deleteSavedMapping(7) end
function QuickApp:deleteMap8() self:deleteSavedMapping(8) end
function QuickApp:deleteMap9() self:deleteSavedMapping(9) end
function QuickApp:deleteMap10() self:deleteSavedMapping(10) end
function QuickApp:deleteMap11() self:deleteSavedMapping(11) end
function QuickApp:deleteMap12() self:deleteSavedMapping(12) end

function QuickApp:dumpMapping()
  self.mapping = decodeJson(self:getVariable("mapping"), self.mapping or {})
  self:loadDevices()

  if tableCount(self.mapping) > 0 then
    self:debug(APP_NAME .. " saved mapping: " .. encodeJson(self.mapping))
    self:debug(APP_NAME .. " discovered Sonos devices: " .. encodeJson(self.sonosDevices or {}))
    self:debug(APP_NAME .. " discovered Yahue apps: " .. encodeJson(self.yahueApps or {}))
    self:debug(APP_NAME .. " discovered Yahue devices: " .. encodeJson(self.yahueDevices or {}))
    self:debug(APP_NAME .. " discovered matrices: " .. encodeJson(self.matrixDevices or {}))
    self:updateView("info", "text", "Gemt mapping skrevet i debug-log")
    return
  end

  local sonos = self:findSonos(self.selectedSonosId)
  local yahue = self:findYahueDevice(self.selectedYahueId)
  local matrixIds = self.pendingMatrixIds or {}
  if (sonos ~= nil or yahue ~= nil) and #matrixIds > 0 then
    local draft = {
      sonosId = sonos and sonos.id or nil,
      sonosName = sonos and sonos.name or nil,
      yahueId = yahue and yahue.id or nil,
      yahueName = yahue and yahue.name or nil,
      yahueAppId = (self.yahueApp or {}).id,
      matrixIds = matrixIds,
      buttonConfig = normalizeButtonConfig(self.buttonConfig),
      deviceMap = self:buildDeviceMap(sonos, yahue, matrixIds),
      defaultSource = self.sourceList or DEFAULT_SOURCE_LIST,
    }
    self:debug(APP_NAME .. " draft mapping (ikke gemt): " .. encodeJson(draft))
    self:debug(APP_NAME .. " discovered Sonos devices: " .. encodeJson(self.sonosDevices or {}))
    self:debug(APP_NAME .. " discovered Yahue apps: " .. encodeJson(self.yahueApps or {}))
    self:debug(APP_NAME .. " discovered Yahue devices: " .. encodeJson(self.yahueDevices or {}))
    self:debug(APP_NAME .. " discovered matrices: " .. encodeJson(self.matrixDevices or {}))
    self:updateView("info", "text", "Draft mapping skrevet i debug-log - tryk Gem for at gemme")
    return
  end

  self:debug(APP_NAME .. " mapping: ingen gemt mapping")
  self:debug(APP_NAME .. " discovered Sonos devices: " .. encodeJson(self.sonosDevices or {}))
  self:debug(APP_NAME .. " discovered Yahue apps: " .. encodeJson(self.yahueApps or {}))
  self:debug(APP_NAME .. " discovered Yahue devices: " .. encodeJson(self.yahueDevices or {}))
  self:debug(APP_NAME .. " discovered matrices: " .. encodeJson(self.matrixDevices or {}))
  self:updateView("info", "text", "Ingen gemt mapping endnu")
end

function QuickApp:backupGlobalVariableName()
  local name = self:getVariable("backupGlobalName")
  if name == nil or name == "" then name = self.backupGlobalName or DEFAULT_BACKUP_GLOBAL_NAME end
  return tostring(name)
end

function QuickApp:writeGlobalVariable(name, value)
  local ok = pcall(function() fibaro.setGlobalVariable(name, value) end)
  if ok then return true end

  ok = pcall(function() api.post("/globalVariables", { name = name, value = value }) end)
  if ok then return true end

  ok = pcall(function() api.put("/globalVariables/" .. name, { value = value }) end)
  return ok
end

function QuickApp:readGlobalVariable(name)
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

function QuickApp:buildDeviceMap(sonos, yahue, matrixIds)
  local deviceMap = {}
  local sourceList = self.sourceList or DEFAULT_SOURCE_LIST
  local buttonConfig = normalizeButtonConfig(self.buttonConfig)

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
          if keyMap ~= nil and (targetType ~= "sonos" or sonos ~= nil) and (targetType ~= "yahue" or yahue ~= nil) then
            deviceMap[sceneId][keyId] = {
              devId = matrix.keys[BUTTON_DEV_KEYS[index]],
              targetType = targetType,
              targetId = targetType == "yahue" and yahue.id or sonos.id,
              targetName = targetType == "yahue" and yahue.name or sonos.name,
              sonosId = sonos and sonos.id or nil,
              yahueId = yahue and yahue.id or nil,
              yahueAppId = (self.yahueApp or {}).id,
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
    deviceMap = self:buildDeviceMap(sonos, self:findYahueDevice(self.selectedYahueId), matrixIds),
    defaultSource = self.sourceList or DEFAULT_SOURCE_LIST,
  }
end

function QuickApp:restart()
  plugin.restart()
end
