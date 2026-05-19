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

  self:debug("Calling switchAction for matrixId=" .. tostring(payload.sceneId) .. ", keyId=" .. keyId)
  fibaro.call(payload.sonosManagerId, "switchAction", payload.data)
  self:updateLastTrigger("Seneste trigger: Matrix " .. tostring(payload.sceneId) .. " K" .. keyId .. " " .. keyAttribute .. " -> sendt")
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
      local sonos = self:findSonos(item.sonosId)
      if sonos == nil then
        self:loadDevices()
        sonos = self:findSonos(item.sonosId)
      end

      local sonosManagerId = tonumber((sonos or {}).parentId)
      if sonosManagerId == nil or sonosManagerId == 0 then
        self:debug("No Sonos Manager parent found for sonosId=" .. tostring(item.sonosId))
        return nil
      end

      local forwardedTrigger = {
        type = sourceTrigger.type,
        id = tonumber(sceneId) or sceneId,
        property = sourceTrigger.property,
        value = sourceTrigger.value,
      }

      return {
        sonosManagerId = sonosManagerId,
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

function QuickApp:updateTriggerStatus(text)
  pcall(function() self:updateView("triggerStatus", "text", text) end)
end

function QuickApp:updateLastTrigger(text)
  pcall(function() self:updateView("lastTrigger", "text", text) end)
end
