-- MatrixProfiles.lua
-- Logic Group Matrix model detection and key/endpoint helpers.
--
-- ProductInfo matches are authoritative. Fallbacks only apply when HC3 exposes
-- incomplete model metadata for older Matrix/ZBA style controllers.

local function matrixLower(value)
  return string.lower(tostring(value or ""))
end

local function matrixClassNameOf(device)
  local props = (device or {}).properties or {}
  return tostring(device.className or props.className or props.quickAppClassName or "")
end

local function matrixRoomIdOf(device)
  return device.roomID or device.roomId or ((device.properties or {}).roomID) or 0
end

function matrixModelOf(device, children)
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

  local function textOf(item)
    local itemProps = ((item or {}).properties or {})
    return matrixLower(table.concat({
      itemProps.productInfo or "",
      itemProps.model or "",
      itemProps.manufacturer or "",
      itemProps.userDescription or "",
      (item or {}).model or "",
      (item or {}).name or "",
      (item or {}).type or "",
      matrixClassNameOf(item),
    }, " "))
  end

  local function modelFromText(text)
    if text:find("zba7140", 1, true) or text:find("zba", 1, true) then return "ZBA7140" end
    if text:find("zdb5100", 1, true) or text:find("zdb", 1, true) then return "ZDB5100" end
    if text:find("zrb5120", 1, true) or text:find("zrb", 1, true) then return "ZRB5120" end
    return nil
  end

  local model = modelFromText(textOf(device))
  if model ~= nil then return model end

  local endpointMap = {}
  for _, child in ipairs(children or {}) do
    local childProductInfo = ((child or {}).properties or {}).productInfo or ""
    if type(childProductInfo) == "string" then
      for _, product in ipairs(products) do
        if childProductInfo:sub(1, #product.productInfo) == product.productInfo then return product.model end
      end
    end

    model = modelFromText(textOf(child))
    if model ~= nil then return model end

    local childProps = (child or {}).properties or {}
    local endpoint = childProps.endpoint or childProps.endPoint or childProps.endpointId or childProps.nodeEndpoint or childProps.nodeEndpointId or (child or {}).endpoint
    if type(endpoint) == "string" then endpoint = endpoint:match("(%d+)$") or endpoint:match("(%d+)") end
    endpoint = tonumber(endpoint)
    if endpoint ~= nil then endpointMap[endpoint] = child end
  end

  if endpointMap[6] ~= nil then return "ZRB5120" end
  if endpointMap[5] ~= nil then return "ZDB5100" end
  if productInfo:match("^2,52") then return "ZBA7140" end

  return nil
end

function matrixProfileOf(device, children)
  local model = matrixModelOf(device, children)
  return model, model and MATRIX_DEVICE_PROFILES and MATRIX_DEVICE_PROFILES[model] or nil
end

function getMatrixType(device, children)
  local model, profile = matrixProfileOf(device, children)
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

function endpointOf(device)
  local props = (device or {}).properties or {}
  local endpoint = props.endpoint or props.endPoint or props.endpointId or props.nodeEndpoint or props.nodeEndpointId or (device or {}).endpoint
  if type(endpoint) == "string" then endpoint = endpoint:match("(%d+)$") or endpoint:match("(%d+)") end
  return tonumber(endpoint)
end

function childByEndpoint(children, endpoint)
  for _, child in ipairs(children or {}) do
    if endpointOf(child) == endpoint then return child end
  end
  return nil
end

function profileButtonKeyDevices(profile, sceneId, children)
  local keys = { ul = 0, ur = 0, ll = 0, lr = 0 }
  if profile == nil or profile.buttonEndpoints == nil then
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

function profileOutputDevices(profile, children)
  local outputs = {}
  for endpoint, role in pairs((profile or {}).outputEndpoints or {}) do
    local child = childByEndpoint(children, endpoint)
    if child ~= nil then outputs[tostring(role)] = child.id end
  end
  return outputs
end

function isLogicMatrix(device)
  local productInfo = ((device or {}).properties or {}).productInfo
  local parentId = device.parentId or device.parentID

  if parentId == 1 and type(productInfo) == "string" and productInfo:match("^2,52") then
    return getMatrixType(device) ~= ""
  end

  return false
end

function findMatrixSceneId(rootId, children)
  local best = nil
  for _, child in ipairs(children or {}) do
    local name = matrixLower(child.name)
    if name:find("scene", 1, true) then
      if best == nil or child.id < best then best = child.id end
    end
  end
  return best or rootId
end

function findMatrixRelays(sceneId, children)
  local relays = {}
  for _, child in ipairs(children or {}) do
    local name = matrixLower(child.name)
    if name:find("relae", 1, true) or name:find("relay", 1, true) then
      relays[#relays + 1] = child.id
    end
  end
  table.sort(relays)
  if #relays >= 2 then return { r1 = relays[1], r2 = relays[2] } end
  return { r1 = sceneId + 10, r2 = sceneId + 11 }
end

function matrixRoomId(rootDevice, sceneId, children)
  for _, child in ipairs(children or {}) do
    if tostring(child.id) == tostring(sceneId) and tonumber(matrixRoomIdOf(child)) ~= 0 then
      return matrixRoomIdOf(child)
    end
  end
  for _, child in ipairs(children or {}) do
    local name = matrixLower(child.name)
    if name:find("scene", 1, true) and tonumber(matrixRoomIdOf(child)) ~= 0 then
      return matrixRoomIdOf(child)
    end
  end
  for _, child in ipairs(children or {}) do
    if tonumber(matrixRoomIdOf(child)) ~= 0 then
      return matrixRoomIdOf(child)
    end
  end
  return matrixRoomIdOf(rootDevice)
end
