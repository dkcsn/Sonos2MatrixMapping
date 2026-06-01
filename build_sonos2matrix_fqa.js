const fs = require("fs");
const path = require("path");

const cwd = process.cwd();
const lua = fs.readFileSync(path.join(cwd, "Sonos2MatrixMapping.lua"), "utf8");
const internalTriggerEngineLua = fs.readFileSync(path.join(cwd, "InternalTriggerEngine.lua"), "utf8");
const appVersion = (lua.match(/local APP_VERSION = "([^"]+)"/) || [null, "dev"])[1];
const documentationUrl = "github.com/dkcsn/Sonos2MatrixMapping";
const iconPath = path.join(cwd, fs.existsSync(path.join(cwd, "Matrix Config HC3.png")) ? "Matrix Config HC3.png" : "Matrix Config.png");
const matrixIconHex = fs.existsSync(iconPath) ? fs.readFileSync(iconPath).toString("hex").toUpperCase() : "";
const matrixIconBytes = matrixIconHex.length / 2;
const iconLua = `fibaro.ICONS = {
matrix_config =
  [[${matrixIconHex}]],
}

local ICON_STORAGE_KEY = "matrixConfigIconInstalledV6"
local ICON_BYTES = ${matrixIconBytes}

function QuickApp:installIconsClear() self:internalStorageRemove(ICON_STORAGE_KEY) end

function QuickApp:installIcons(iconNames, set, cb, timeout)
  local existingIcon = tonumber((self.properties or {}).deviceIcon or 0) or 0
  if self:internalStorageGet(ICON_STORAGE_KEY) == true and existingIcon > 0 then
    self:debug("Icon already installed: deviceIcon=" .. tostring(existingIcon))
    return
  end

  self:debug("Installing icon(s): " .. table.concat(iconNames or {}, ", ") .. " for type=" .. tostring(self.type or "?") .. " bytes=" .. tostring(ICON_BYTES))

  local iconSet = {}
  for _, name in ipairs(iconNames) do
    local icon, data = {}, fibaro.ICONS[name]
    assert(data, "No such icon:" .. name)
    data = data:gsub("%s+", "")
    _ = data:gsub("(..)", function(d) icon[#icon + 1] = string.char(tonumber(d, 16)) end)
    iconSet[#iconSet + 1] = table.concat(icon)
  end

  local http = net.HTTPClient
  local ok, err = pcall(function()
    function net.HTTPClient(opts) return http({ timeout = timeout or 60000 }) end
    local iconDeviceType = self.deviceIconTypeMapping[self.type] and self.type or "com.fibaro.genericDevice"
    local types = self.deviceIconTypeMapping[iconDeviceType]
    assert(types, "Unsupported device type")
    assert(#types.fileNames == #iconSet, "Expecting " .. tostring(#types.fileNames) .. " icons")
    local data = { files = iconSet, fileNames = types.fileNames, deviceType = iconDeviceType }
    self:uploadIconFiles(data, {}, function(id)
      self:internalStorageSet(ICON_STORAGE_KEY, true)
      if set then self:updateProperty("deviceIcon", id) end
      self:debug("Icon installed: deviceIcon=" .. tostring(id) .. " uploadType=" .. tostring(iconDeviceType))
      if cb then cb(true, id) end
    end, function(err)
      self:error("Icon upload failed: " .. tostring(err))
      if cb then cb(false, err) end
    end)
  end)
  net.HTTPClient = http
  if not ok then
    self:error("Icon install failed: " .. tostring(err))
    if cb then cb(false, err) end
  end
end
`;
const defaultProfileNext = {
  label: "Next",
  targetType: "sonos",
  keyMap: {
    HeldDown: ["toggleVolumeChange"],
    Released: ["stopVolumeChange"],
    Pressed: ["toggle"],
    Pressed2: ["next"],
    Pressed3: ["nextSource", "SOURCE_LIST"],
  },
};
const defaultProfilePrev = {
  label: "Prev",
  targetType: "sonos",
  keyMap: {
    HeldDown: ["toggleVolumeChange"],
    Released: ["stopVolumeChange"],
    Pressed: ["toggle"],
    Pressed2: ["prev"],
    Pressed3: ["prevSource", "SOURCE_LIST"],
  },
};
const defaultProfileHueNext = {
  label: "Hue Next",
  targetType: "yahue",
  keyMap: {
    HeldDown: ["hueDimToggle", "up"],
    Released: ["hueDimStopToggle"],
    Pressed: ["hueToggle"],
    Pressed2: ["hueSetValue", 100],
    Pressed3: ["hueNextScene"],
  },
};
const defaultProfileHuePrev = {
  label: "Hue Prev",
  targetType: "yahue",
  keyMap: {
    HeldDown: ["hueDimToggle", "down"],
    Released: ["hueDimStopToggle"],
    Pressed: ["hueToggle"],
    Pressed2: ["hueSetValue", 100],
    Pressed3: ["huePrevScene"],
  },
};
const defaultProfileTahomaToggle = {
  label: "Tahoma Toggle",
  targetType: "tahoma",
  keyMap: {
    HeldDown: ["toggle"],
    Released: ["stop"],
    Pressed: ["toggle"],
    Pressed2: ["favorit"],
    Pressed3: ["nextSource"],
  },
};
const defaultProfileTahomaOpen = {
  label: "Tahoma Open",
  targetType: "tahoma",
  keyMap: {
    HeldDown: ["open"],
    Released: ["stop"],
    Pressed: ["open"],
    Pressed2: ["favorit"],
    Pressed3: ["nextSource"],
  },
};
const defaultProfileTahomaClose = {
  label: "Tahoma Close",
  targetType: "tahoma",
  keyMap: {
    HeldDown: ["close"],
    Released: ["stop"],
    Pressed: ["close"],
    Pressed2: ["favorit"],
    Pressed3: ["prevSource"],
  },
};

const actionBinding = (eventType, name) => ({
  type: "deviceAction",
  params: { actionName: "UIAction", args: [eventType, name] },
});
const button = (name, text, weight = "0.5") => ({
  type: "button",
  name,
  text,
  visible: true,
  style: { weight },
  eventBinding: {
    onReleased: [actionBinding("onReleased", name)],
    onLongPressDown: [actionBinding("onLongPressDown", name)],
    onLongPressReleased: [actionBinding("onLongPressReleased", name)],
  },
});
const select = (name, text, selectionType = "single", weight = "1.0", options = []) => ({
  type: "select",
  name,
  text,
  selectionType,
  options,
  values: [],
  visible: true,
  style: { weight },
  eventBinding: {
    onToggled: [{
      type: "deviceAction",
      params: { actionName: "UIAction", args: ["onToggled", name, "$event.value"] },
    }],
  },
});
const label = (name, text = "", weight = "1.0") => ({
  type: "label",
  name,
  style: { weight },
  text,
  visible: true,
});
const row = (...components) => ({ type: "horizontal", style: { weight: "1.0" }, components });

const uiView = [
  row(label("info", `Matrix Button Configuration v${appVersion}`)),
  row(label("roomInfo", "Vælg destination og Matrix")),
  row(label("triggerStatus", "Trigger engine: starter")),
  row(label("lastTrigger", "Seneste trigger: ingen")),
  row(label("destinationInfo", "DESTINATIONER")),
  row(select("yahueSelect", "YAHUE / HUE")),
  row(select("tahomaSelect", "TAHOMA / VELUX", "multi")),
  row(select("sonosSelect", "SONOS")),
  row(label("matrixScopeInfo", "MATRIX VISNING")),
  row(button("matrixScopeRoom", "Samme rum", "0.5"), button("matrixScopeAll", "Alle Matrix", "0.5")),
  row(select("matrixSelect", "MATRIX", "multi")),
  row(button("refresh", "Genindlæs enheder", "1.0")),
  row(label("buttonMapInfo", "KNAP MAPPING")),
  row(select("button1Map", "Knap 1")),
  row(select("button2Map", "Knap 2")),
  row(select("button3Map", "Knap 3")),
  row(select("button4Map", "Knap 4")),
  row(button("saveMapping", "Gem", "1.0")),
  row(label("savedMappingsInfo", "Gemte mappings: 0")),
  row(select("savedMappingSelect", "GEMTE MAPPINGS", "single")),
  row(button("deleteSavedMapping", "Slet valgt mapping", "1.0")),
  row(label("summary")),
  row(label("summarySonos")),
  row(label("summaryYahueApps")),
  row(label("summaryTahomaApps")),
  row(label("summaryMatrix")),
  row(label("documentationLink", `Dokumentation: ${documentationUrl}`)),
  row(button("backupMapping", "Backup", "0.5"), button("restoreMapping", "Restore", "0.5")),
  row(button("dumpMapping", "Dump mapping", "0.5"), button("restart", "Genstart", "0.5")),
];

const viewLayout = {
  $jason: {
    head: { title: "quickApp_device_0" },
    body: {
      header: { title: "quickApp_device_0", style: { height: "0" } },
      sections: {
        items: uiView.map((row) => ({
          type: "vertical",
          style: { weight: "1.2" },
          components: [
            ...(row.components.length === 1 ? row.components.map((c) => ({ ...c, style: { weight: "1.2" }, eventBinding: undefined })) : [{ type: "horizontal", style: { weight: "1.2" }, components: row.components.map((c) => ({ ...c, eventBinding: undefined })) }]),
            { type: "space", style: { weight: "0.5" } },
          ],
        })),
      },
    },
  },
};

const callbacks = [
  { name: "sonosSelect", callback: "sonosChanged", eventType: "onToggled" },
  { name: "yahueSelect", callback: "yahueChanged", eventType: "onToggled" },
  { name: "tahomaSelect", callback: "tahomaChanged", eventType: "onToggled" },
  { name: "matrixScopeRoom", callback: "matrixScopeRoom", eventType: "onReleased" },
  { name: "matrixScopeRoom", callback: "", eventType: "onLongPressDown" },
  { name: "matrixScopeRoom", callback: "", eventType: "onLongPressReleased" },
  { name: "matrixScopeAll", callback: "matrixScopeAll", eventType: "onReleased" },
  { name: "matrixScopeAll", callback: "", eventType: "onLongPressDown" },
  { name: "matrixScopeAll", callback: "", eventType: "onLongPressReleased" },
  { name: "matrixSelect", callback: "matrixChanged", eventType: "onToggled" },
  { name: "button1Map", callback: "button1MapChanged", eventType: "onToggled" },
  { name: "button2Map", callback: "button2MapChanged", eventType: "onToggled" },
  { name: "button3Map", callback: "button3MapChanged", eventType: "onToggled" },
  { name: "button4Map", callback: "button4MapChanged", eventType: "onToggled" },
  { name: "refresh", callback: "refresh", eventType: "onReleased" },
  { name: "refresh", callback: "", eventType: "onLongPressDown" },
  { name: "refresh", callback: "", eventType: "onLongPressReleased" },
  { name: "saveMapping", callback: "saveMapping", eventType: "onReleased" },
  { name: "saveMapping", callback: "", eventType: "onLongPressDown" },
  { name: "saveMapping", callback: "", eventType: "onLongPressReleased" },
  { name: "dumpMapping", callback: "dumpMapping", eventType: "onReleased" },
  { name: "dumpMapping", callback: "", eventType: "onLongPressDown" },
  { name: "dumpMapping", callback: "", eventType: "onLongPressReleased" },
  { name: "restart", callback: "restart", eventType: "onReleased" },
  { name: "restart", callback: "", eventType: "onLongPressDown" },
  { name: "restart", callback: "", eventType: "onLongPressReleased" },
  { name: "backupMapping", callback: "backupMapping", eventType: "onReleased" },
  { name: "backupMapping", callback: "", eventType: "onLongPressDown" },
  { name: "backupMapping", callback: "", eventType: "onLongPressReleased" },
  { name: "restoreMapping", callback: "restoreMapping", eventType: "onReleased" },
  { name: "restoreMapping", callback: "", eventType: "onLongPressDown" },
  { name: "restoreMapping", callback: "", eventType: "onLongPressReleased" },
  { name: "savedMappingSelect", callback: "savedMappingSelected", eventType: "onToggled" },
  { name: "deleteSavedMapping", callback: "deleteSelectedSavedMapping", eventType: "onReleased" },
  { name: "deleteSavedMapping", callback: "", eventType: "onLongPressDown" },
  { name: "deleteSavedMapping", callback: "", eventType: "onLongPressReleased" },
];

const fqa = {
  name: "Matrix Button Configuration",
  type: "com.fibaro.genericDevice",
  apiVersion: "1.3",
  initialInterfaces: [],
  initialProperties: {
    apiVersion: "1.3",
    buildNumber: 1,
    deviceRole: "Other",
    supportedDeviceRoles: ["Other"],
    typeTemplateInitialized: true,
    useEmbededView: true,
    useUiView: true,
    userDescription: "",
    quickAppVariables: [
      { name: "mapping", value: "{}" },
      { name: "backupGlobalName", value: "MatrixButtonConfigurationBackup" },
      { name: "useViewLayout", value: "false" },
      { name: "matrixScope", value: "room" },
      { name: "sourceList", value: "[1,2,3,11,12,13]" },
      { name: "profile_next", value: JSON.stringify(defaultProfileNext) },
      { name: "profile_prev", value: JSON.stringify(defaultProfilePrev) },
      { name: "profile_hue_next", value: JSON.stringify(defaultProfileHueNext) },
      { name: "profile_hue_prev", value: JSON.stringify(defaultProfileHuePrev) },
      { name: "profile_tahoma_toggle", value: JSON.stringify(defaultProfileTahomaToggle) },
      { name: "profile_tahoma_open", value: JSON.stringify(defaultProfileTahomaOpen) },
      { name: "profile_tahoma_close", value: JSON.stringify(defaultProfileTahomaClose) },
    ],
    uiCallbacks: callbacks,
    uiView,
    viewLayout,
  },
  files: [
    {
      name: "Icon",
      type: "lua",
      isMain: false,
      isOpen: false,
      content: iconLua,
    },
    {
      name: "InternalTriggerEngine",
      type: "lua",
      isMain: false,
      isOpen: false,
      content: internalTriggerEngineLua,
    },
    {
      name: "main",
      type: "lua",
      isMain: true,
      isOpen: true,
      content: lua,
    },
  ],
};

const outputName = `MatrixButtonConfiguration_v${appVersion}.fqa`;
fs.writeFileSync(path.join(cwd, outputName), JSON.stringify(fqa));
fs.writeFileSync(path.join(cwd, "MatrixButtonConfiguration.fqa"), JSON.stringify(fqa));
fs.writeFileSync(path.join(cwd, "Sonos2MatrixMapping.fqa"), JSON.stringify(fqa));
console.log(path.join(cwd, outputName));
