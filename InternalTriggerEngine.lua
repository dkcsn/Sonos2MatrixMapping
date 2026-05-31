-- Internal trigger engine for Sonos2MatrixMapping.
-- Uses HC3 refreshStates directly from the QuickApp. No scenes, no EventLib.

local INTERNAL_DEFAULT_SOURCE_LIST = { 1, 2, 3, 11, 12, 13 }
local REFRESH_STATES_BASE_URL = "http://127.0.0.1:11111/api/refreshStates"

MATRIX_DEVICE_PROFILES = MATRIX_DEVICE_PROFILES or {
  ZBA7140 = {
    kind = "battery_wall_controller",
    rootEndpoint = 0,
    buttonEndpoints = nil,
    outputEndpoints = {},
    centralScene = {
      source = "root",
      enabledByDefault = true,
      configParameter = 1,
    },
    buttons = {
      [1] = "TOP_LEFT",
      [2] = "TOP_RIGHT",
      [3] = "BOTTOM_LEFT",
      [4] = "BOTTOM_RIGHT",
    },
  },

  ZDB5100 = {
    kind = "dimmer_switch",
    rootEndpoint = 0,
    buttonEndpoints = {
      [1] = "TOP_LEFT",
      [2] = "TOP_RIGHT",
      [3] = "BOTTOM_LEFT",
      [4] = "BOTTOM_RIGHT",
    },
    outputEndpoints = {
      [5] = "DIMMER",
    },
    centralScene = {
      source = "root",
      group = 1,
    },
  },

  ZRB5120 = {
    kind = "dual_relay_switch",
    rootEndpoint = 0,
    buttonEndpoints = {
      [1] = "TOP_LEFT",
      [2] = "TOP_RIGHT",
      [3] = "BOTTOM_LEFT",
      [4] = "BOTTOM_RIGHT",
    },
    outputEndpoints = {
      [5] = "RELAY_1",
      [6] = "RELAY_2",
    },
    centralScene = {
      source = "root",
      group = 1,
    },
  },
}

local function decodeInternalJson(value, fallback)
  if value == nil or value == "" then return fallback end
  local ok, decoded = pcall(json.decode, value)
  if ok and decoded ~= nil then return decoded end
  return fallback
end

function QuickApp:initTriggerEngine()
  self._lastRefresh = 0
  self._subscriptions = {}
  self._refreshLoopRunning = true
  self.http = net.HTTPClient({ timeout = 10000 })
  math.randomseed(os.time())

  self:debug("Trigger engine started")
  self:updateTriggerStatus("Trigger engine: lytter")

  self:subscribeInternalTrigger({
    type = "device",
    property = "centralSceneEvent",
  })

  self:startRefreshLoop()
end

function QuickApp:subscribeInternalTrigger(pattern)
  self._subscriptions[#self._subscriptions + 1] = pattern
end

function QuickApp:startRefreshLoop(delay)
  if self._refreshLoopRunning == false then return end

  fibaro.setTimeout(delay or 0, function()
    if self._refreshLoopRunning == false then return end

    local url = REFRESH_STATES_BASE_URL ..
      "?last=" .. tostring(self._lastRefresh or 0) ..
      "&lang=en&rand=" .. tostring(math.random(2000, 4000)) ..
      "&logs=false"
    self.http:request(url, {
      options = {
        method = "GET",
        headers = {
          ["Accept"] = "application/json",
        },
      },
      success = function(response)
        self:handleRefreshResponse(response)
      end,
      error = function(err)
        self:error("refreshStates HTTP error: " .. tostring(err))
        self:updateTriggerStatus("Trigger engine: HTTP fejl")
        self:startRefreshLoop(2000)
      end,
    })
  end)
end

function QuickApp:handleRefreshResponse(response)
  local status = tonumber((response or {}).status or 0)
  local body = tostring((response or {}).data or "")

  if status ~= 200 then
    self:error("refreshStates HTTP status=" .. tostring(status) .. " body=" .. body:sub(1, 200))
    self:updateTriggerStatus("Trigger engine: HTTP " .. tostring(status))
    self:startRefreshLoop(2000)
    return
  end

  local ok, data = pcall(json.decode, body)

  if not ok or type(data) ~= "table" then
    self:error("Invalid refreshStates JSON body=" .. body:sub(1, 200))
    self:updateTriggerStatus("Trigger engine: ugyldig JSON")
    self:startRefreshLoop(1000)
    return
  end

  self._lastRefresh = data.last or self._lastRefresh
  self:updateTriggerStatus("Trigger engine: lytter")

  for _, event in ipairs(data.events or {}) do
    local trigger = self:convertRefreshEvent(event)
    if trigger ~= nil and self:matchesSubscriptions(trigger) then
      self:sourceTrigger(trigger)
    end
  end

  self:startRefreshLoop(50)
end

function QuickApp:convertRefreshEvent(event)
  if event == nil then return nil end

  if event.type == "DevicePropertyUpdatedEvent" then
    local data = event.data or {}
    return {
      type = "device",
      id = data.id or data.deviceId,
      property = data.property,
      value = data.newValue,
      old = data.oldValue,
    }
  end

  if event.type == "CentralSceneEvent" then
    local data = event.data or {}
    return {
      type = "device",
      id = data.id or data.deviceId,
      property = "centralSceneEvent",
      value = {
        keyId = data.keyId,
        keyAttribute = data.keyAttribute,
      },
    }
  end

  return nil
end

function QuickApp:matchesSubscriptions(trigger)
  for _, subscription in ipairs(self._subscriptions or {}) do
    local match = true
    for key, value in pairs(subscription) do
      if trigger[key] ~= value then
        match = false
        break
      end
    end
    if match then return true end
  end
  return false
end

function QuickApp:sourceTrigger(sourceTrigger)
  self:handleMatrixTrigger(sourceTrigger)
end

function QuickApp:handleMatrixTrigger(sourceTrigger)
  if sourceTrigger == nil or sourceTrigger.property ~= "centralSceneEvent" then return end

  local matrixEvent = self:normalizeMatrixTrigger(sourceTrigger)
  local eventId = tostring(matrixEvent.sourceDeviceId or sourceTrigger.id or "")
  local keyId = tostring(matrixEvent.button or "")
  local keyAttribute = tostring(matrixEvent.sceneKey or "")

  self:debug("centralSceneEvent received: eventId=" .. eventId .. ", matrixId=" .. tostring(matrixEvent.matrixId or "?") .. ", model=" .. tostring(matrixEvent.model or "?") .. ", keyId=" .. keyId .. ", keyAttribute=" .. keyAttribute)
  self:updateLastTrigger("Seneste trigger: event " .. eventId .. " K" .. keyId .. " " .. keyAttribute)

  local payload = self:buildMatrixTriggerPayload(sourceTrigger, matrixEvent)
  if payload == nil then
    self:debug("No mapping for matrixId=" .. eventId .. ", keyId=" .. keyId)
    self:updateLastTrigger("Seneste trigger: event " .. eventId .. " K" .. keyId .. " " .. keyAttribute .. " -> ingen mapping")
    return
  end

  self:dispatchMatrixPayload(payload, keyAttribute)
  self:updateLastTrigger("Seneste trigger: Matrix " .. tostring(payload.sceneId) .. " K" .. keyId .. " " .. keyAttribute .. " -> " .. tostring(payload.targetType or "sonos"))
end

function QuickApp:normalizeMatrixTrigger(sourceTrigger)
  local value = sourceTrigger.value or {}
  local sourceDeviceId = tostring(sourceTrigger.id or "")
  local button = tonumber(value.keyId)

  local matrixEvent = {
    matrixId = sourceDeviceId,
    model = nil,
    sourceDeviceId = sourceDeviceId,
    rootDeviceId = sourceDeviceId,
    endpoint = nil,
    button = button,
    sceneKey = value.keyAttribute,
    rawEvent = sourceTrigger,
  }

  self.mapping = decodeInternalJson(self:getVariable("mapping"), self.mapping or {})

  for _, item in pairs(self.mapping or {}) do
    local deviceMap = item.deviceMap or {}
    local aliases = deviceMap.__eventAliases or {}
    local sceneId = aliases[sourceDeviceId]

    if sceneId ~= nil then
      matrixEvent.matrixId = tostring(sceneId)
      matrixEvent.rootDeviceId = tostring((deviceMap.__matrixRootIds or {})[tostring(sceneId)] or sceneId)
      matrixEvent.model = (deviceMap.__matrixModels or {})[tostring(sceneId)]
      matrixEvent.endpoint = (deviceMap.__eventEndpoints or {})[sourceDeviceId]
      break
    end
  end

  return matrixEvent
end

function QuickApp:buildMatrixTriggerPayload(sourceTrigger, matrixEvent)
  local eventId = tostring((matrixEvent or {}).sourceDeviceId or sourceTrigger.id or "")
  local keyId = tostring((matrixEvent or {}).button or ((sourceTrigger.value or {}).keyId) or "")
  if eventId == "" or keyId == "" then return nil end

  self.mapping = decodeInternalJson(self:getVariable("mapping"), self.mapping or {})

  for _, item in pairs(self.mapping or {}) do
    local deviceMap = item.deviceMap or {}
    local aliases = deviceMap.__eventAliases or {}
    local sceneId = tostring(aliases[eventId] or eventId)

    if deviceMap[sceneId] ~= nil and deviceMap[sceneId][keyId] ~= nil then
      local entry = deviceMap[sceneId][keyId]
      local targetType = tostring(entry.targetType or "sonos")

      local forwardedTrigger = {
        type = sourceTrigger.type,
        id = tonumber(sceneId) or sceneId,
        property = sourceTrigger.property,
        value = sourceTrigger.value,
      }

      return {
        targetType = targetType,
        entry = entry,
        item = item,
        sceneId = sceneId,
        data = {
          sourceTrigger = forwardedTrigger,
          deviceMap = deviceMap,
          defaultSource = item.sourceList or self.sourceList or INTERNAL_DEFAULT_SOURCE_LIST,
        },
      }
    end
  end

  return nil
end

function QuickApp:dispatchMatrixPayload(payload, keyAttribute)
  if payload == nil then return end

  if payload.targetType == "yahue" then
    self:executeYahueAction(payload.entry, keyAttribute)
    return
  end

  local item = payload.item or {}
  local sonos = self:findSonos(item.sonosId)
  if sonos == nil then
    self:loadDevices()
    sonos = self:findSonos(item.sonosId)
  end

  local sonosManagerId = tonumber((sonos or {}).parentId)
  if sonosManagerId == nil or sonosManagerId == 0 then
    self:debug("No Sonos Manager parent found for sonosId=" .. tostring(item.sonosId))
    return
  end

  self:debug("Calling Sonos switchAction for matrixId=" .. tostring(payload.sceneId))
  fibaro.call(sonosManagerId, "switchAction", payload.data)
end

function QuickApp:executeYahueAction(entry, keyAttribute)
  if entry == nil or type(entry.keyMap) ~= "table" then return end

  local action = entry.keyMap[tostring(keyAttribute or "")]
  if type(action) ~= "table" then return end

  local actionName = tostring(action[1] or "")
  local targetId = tonumber(entry.yahueId or entry.targetId)
  if targetId == nil then
    self:debug("Yahue action has no target device")
    return
  end

  self:debug("Calling Yahue action " .. actionName .. " for deviceId=" .. tostring(targetId))

  if actionName == "hueToggle" then
    self:toggleYahueDevice(targetId)
  elseif actionName == "hueOn" then
    fibaro.call(targetId, "turnOn")
  elseif actionName == "hueOff" then
    fibaro.call(targetId, "turnOff")
  elseif actionName == "hueSetValue" then
    fibaro.call(targetId, "setValue", tonumber(action[2]) or 100)
  elseif actionName == "hueDimToggle" then
    self:startYahueToggleDim(targetId, tostring(action[2] or "up"))
  elseif actionName == "hueDimStopToggle" then
    self:stopYahueToggleDim(targetId)
  elseif actionName == "hueDimStart" then
    if tostring(action[2] or "up") == "down" then
      fibaro.call(targetId, "startLevelDecrease")
    else
      fibaro.call(targetId, "startLevelIncrease")
    end
  elseif actionName == "hueDimStop" then
    fibaro.call(targetId, "stopLevelChange")
  elseif actionName == "hueNextScene" then
    self:stepYahueScene(targetId, 1)
  elseif actionName == "huePrevScene" then
    self:stepYahueScene(targetId, -1)
  else
    self:debug("Unknown Yahue action: " .. actionName)
  end
end

function QuickApp:startYahueToggleDim(targetId, defaultDirection)
  local key = tostring(targetId)
  self.yahueDimDirections = self.yahueDimDirections or {}
  self.yahueDimActiveDirections = self.yahueDimActiveDirections or {}
  local direction = self.yahueDimDirections[key] or defaultDirection or "up"
  self.yahueDimActiveDirections[key] = direction

  self:debug("Yahue toggle dim start deviceId=" .. key .. " direction=" .. tostring(direction))
  if tostring(direction) == "down" then
    fibaro.call(targetId, "startLevelDecrease")
  else
    fibaro.call(targetId, "startLevelIncrease")
  end
end

function QuickApp:stopYahueToggleDim(targetId)
  local key = tostring(targetId)
  self.yahueDimDirections = self.yahueDimDirections or {}
  self.yahueDimActiveDirections = self.yahueDimActiveDirections or {}
  local current = self.yahueDimActiveDirections[key] or self.yahueDimDirections[key] or "up"
  self.yahueDimDirections[key] = current == "down" and "up" or "down"
  self.yahueDimActiveDirections[key] = nil

  self:debug("Yahue toggle dim stop deviceId=" .. key .. " nextDirection=" .. tostring(self.yahueDimDirections[key]))
  fibaro.call(targetId, "stopLevelChange")
end

function QuickApp:toggleYahueDevice(targetId)
  local ok, device = pcall(function() return api.get("/devices/" .. tostring(targetId)) end)
  local props = ok and (device or {}).properties or {}
  local value = props.value
  local state = props.state
  local isOn = state == true or value == true or (tonumber(value) ~= nil and tonumber(value) > 0)

  if isOn then
    fibaro.call(targetId, "turnOff")
  else
    fibaro.call(targetId, "turnOn")
  end
end

function QuickApp:yahueSceneOptions(targetId)
  local ok, device = pcall(function() return api.get("/devices/" .. tostring(targetId)) end)
  if not ok or device == nil then return {} end

  local result = {}
  local seen = {}
  local function scan(value)
    if type(value) ~= "table" then return end
    if value.name == "sceneSelect" and type(value.options) == "table" then
      for _, option in ipairs(value.options) do
        if option.value ~= nil and tostring(option.value) ~= "" and not seen[tostring(option.value)] then
          seen[tostring(option.value)] = true
          result[#result + 1] = option.value
        end
      end
    end
    for _, item in pairs(value) do scan(item) end
  end

  scan(device)
  scan((device.properties or {}).uiView)
  scan((device.properties or {}).viewLayout)
  return result
end

function QuickApp:stepYahueScene(targetId, direction)
  local scenes = self:yahueSceneOptions(targetId)
  if #scenes == 0 then
    self:debug("No Yahue scenes found for deviceId=" .. tostring(targetId))
    return
  end

  local key = tostring(targetId)
  local index = tonumber((self.yahueSceneIndexes or {})[key]) or 0
  index = index + (tonumber(direction) or 1)
  if index > #scenes then index = 1 end
  if index < 1 then index = #scenes end
  self.yahueSceneIndexes = self.yahueSceneIndexes or {}
  self.yahueSceneIndexes[key] = index

  fibaro.call(targetId, "sceneChanged", { values = { scenes[index] } })
end

function QuickApp:updateTriggerStatus(text)
  pcall(function() self:updateView("triggerStatus", "text", text) end)
end

function QuickApp:updateLastTrigger(text)
  pcall(function() self:updateView("lastTrigger", "text", text) end)
end
