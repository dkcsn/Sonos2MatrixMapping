const fs = require("fs");
const path = require("path");

const cwd = process.cwd();
const lua = fs.readFileSync(path.join(cwd, "Sonos2MatrixMapping.lua"), "utf8");
const internalTriggerEngineLua = fs.readFileSync(path.join(cwd, "InternalTriggerEngine.lua"), "utf8");
const appVersion = (lua.match(/local APP_VERSION = "([^"]+)"/) || [null, "dev"])[1];
const documentationUrl = "https://github.com/dkcsn/Sonos2MatrixMapping/blob/master/Sonos2MatrixMapping_README.md";
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

const uiView = [
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      { type: "label", name: "info", style: { weight: "1.0" }, text: "", visible: true },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      { type: "label", name: "roomInfo", style: { weight: "1.0" }, text: "Vælg en Sonos højttaler", visible: true },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      { type: "label", name: "triggerStatus", style: { weight: "1.0" }, text: "Trigger engine: starter", visible: true },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      { type: "label", name: "lastTrigger", style: { weight: "1.0" }, text: "Seneste trigger: ingen", visible: true },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      {
        type: "select",
        name: "sonosSelect",
        text: "SONOS",
        selectionType: "single",
        options: [],
        values: [],
        visible: true,
        style: { weight: "1.0" },
        eventBinding: {
          onToggled: [
            {
              type: "deviceAction",
              params: {
                actionName: "UIAction",
                args: ["onToggled", "sonosSelect", "$event.value"],
              },
            },
          ],
        },
      },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      {
        type: "select",
        name: "yahueSelect",
        text: "YAHUE / HUE",
        selectionType: "single",
        options: [],
        values: [],
        visible: true,
        style: { weight: "1.0" },
        eventBinding: {
          onToggled: [
            {
              type: "deviceAction",
              params: {
                actionName: "UIAction",
                args: ["onToggled", "yahueSelect", "$event.value"],
              },
            },
          ],
        },
      },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      {
        type: "select",
        name: "matrixScopeSelect",
        text: "Matrix visning",
        selectionType: "single",
        options: [
          { type: "option", text: "Samme rum", value: "room" },
          { type: "option", text: "Alle Matrix", value: "all" },
        ],
        values: [],
        visible: true,
        style: { weight: "1.0" },
        eventBinding: {
          onToggled: [
            {
              type: "deviceAction",
              params: {
                actionName: "UIAction",
                args: ["onToggled", "matrixScopeSelect", "$event.value"],
              },
            },
          ],
        },
      },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      {
        type: "select",
        name: "matrixSelect",
        text: "Matrix i samme rum",
        selectionType: "multi",
        options: [],
        values: [],
        visible: true,
        style: { weight: "1.0" },
        eventBinding: {
          onToggled: [
            {
              type: "deviceAction",
              params: {
                actionName: "UIAction",
                args: ["onToggled", "matrixSelect", "$event.value"],
              },
            },
          ],
        },
      },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      { type: "label", name: "buttonMapInfo", style: { weight: "1.0" }, text: "Knap mapping", visible: true },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      {
        type: "select",
        name: "button1Map",
        text: "Knap 1",
        selectionType: "single",
        options: [],
        values: [],
        visible: true,
        style: { weight: "0.5" },
        eventBinding: {
          onToggled: [
            {
              type: "deviceAction",
              params: {
                actionName: "UIAction",
                args: ["onToggled", "button1Map", "$event.value"],
              },
            },
          ],
        },
      },
      {
        type: "select",
        name: "button2Map",
        text: "Knap 2",
        selectionType: "single",
        options: [],
        values: [],
        visible: true,
        style: { weight: "0.5" },
        eventBinding: {
          onToggled: [
            {
              type: "deviceAction",
              params: {
                actionName: "UIAction",
                args: ["onToggled", "button2Map", "$event.value"],
              },
            },
          ],
        },
      },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      {
        type: "select",
        name: "button3Map",
        text: "Knap 3",
        selectionType: "single",
        options: [],
        values: [],
        visible: true,
        style: { weight: "0.5" },
        eventBinding: {
          onToggled: [
            {
              type: "deviceAction",
              params: {
                actionName: "UIAction",
                args: ["onToggled", "button3Map", "$event.value"],
              },
            },
          ],
        },
      },
      {
        type: "select",
        name: "button4Map",
        text: "Knap 4",
        selectionType: "single",
        options: [],
        values: [],
        visible: true,
        style: { weight: "0.5" },
        eventBinding: {
          onToggled: [
            {
              type: "deviceAction",
              params: {
                actionName: "UIAction",
                args: ["onToggled", "button4Map", "$event.value"],
              },
            },
          ],
        },
      },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      {
        type: "button",
        name: "refresh",
        text: "Opdater",
        visible: true,
        style: { weight: "0.33" },
        eventBinding: {
          onReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onReleased", "refresh"] } }],
          onLongPressDown: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressDown", "refresh"] } }],
          onLongPressReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressReleased", "refresh"] } }],
        },
      },
      {
        type: "button",
        name: "saveMapping",
        text: "Gem",
        visible: true,
        style: { weight: "0.33" },
        eventBinding: {
          onReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onReleased", "saveMapping"] } }],
          onLongPressDown: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressDown", "saveMapping"] } }],
          onLongPressReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressReleased", "saveMapping"] } }],
        },
      },
      {
        type: "button",
        name: "clearMapping",
        text: "Slet",
        visible: true,
        style: { weight: "0.33" },
        eventBinding: {
          onReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onReleased", "clearMapping"] } }],
          onLongPressDown: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressDown", "clearMapping"] } }],
          onLongPressReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressReleased", "clearMapping"] } }],
        },
      },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      {
        type: "button",
        name: "dumpMapping",
        text: "Dump mapping",
        visible: true,
        style: { weight: "0.5" },
        eventBinding: {
          onReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onReleased", "dumpMapping"] } }],
          onLongPressDown: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressDown", "dumpMapping"] } }],
          onLongPressReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressReleased", "dumpMapping"] } }],
        },
      },
      {
        type: "button",
        name: "restart",
        text: "Genstart",
        visible: true,
        style: { weight: "0.5" },
        eventBinding: {
          onReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onReleased", "restart"] } }],
          onLongPressDown: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressDown", "restart"] } }],
          onLongPressReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressReleased", "restart"] } }],
        },
      },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      {
        type: "button",
        name: "backupMapping",
        text: "Backup",
        visible: true,
        style: { weight: "0.5" },
        eventBinding: {
          onReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onReleased", "backupMapping"] } }],
          onLongPressDown: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressDown", "backupMapping"] } }],
          onLongPressReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressReleased", "backupMapping"] } }],
        },
      },
      {
        type: "button",
        name: "restoreMapping",
        text: "Restore",
        visible: true,
        style: { weight: "0.5" },
        eventBinding: {
          onReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onReleased", "restoreMapping"] } }],
          onLongPressDown: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressDown", "restoreMapping"] } }],
          onLongPressReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressReleased", "restoreMapping"] } }],
        },
      },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      { type: "label", name: "summary", style: { weight: "1.0" }, text: "", visible: true },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      { type: "label", name: "summarySonos", style: { weight: "1.0" }, text: "", visible: true },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      { type: "label", name: "summaryYahueApps", style: { weight: "1.0" }, text: "", visible: true },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      { type: "label", name: "summaryYahueDevices", style: { weight: "1.0" }, text: "", visible: true },
    ],
  },
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      { type: "label", name: "summaryMatrix", style: { weight: "1.0" }, text: "", visible: true },
    ],
  },
  ...Array.from({ length: 12 }, (_, index) => {
    const number = index + 1;
    return {
      type: "horizontal",
      style: { weight: "1.0" },
      components: [
        {
          type: "label",
          name: `mapLine${number}`,
          style: { weight: "0.75" },
          text: "",
          visible: false,
        },
        {
          type: "button",
          name: `deleteMap${number}`,
          text: "Slet",
          visible: false,
          style: { weight: "0.25" },
          eventBinding: {
            onReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onReleased", `deleteMap${number}`] } }],
            onLongPressDown: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressDown", `deleteMap${number}`] } }],
            onLongPressReleased: [{ type: "deviceAction", params: { actionName: "UIAction", args: ["onLongPressReleased", `deleteMap${number}`] } }],
          },
        },
      ],
    };
  }),
  {
    type: "horizontal",
    style: { weight: "1.0" },
    components: [
      {
        type: "label",
        name: "documentationLink",
        style: { weight: "1.0" },
        text: `<a href="${documentationUrl}">Dokumentation på GitHub</a>`,
        visible: true,
      },
    ],
  },
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
  { name: "matrixScopeSelect", callback: "matrixScopeChanged", eventType: "onToggled" },
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
  { name: "clearMapping", callback: "clearMapping", eventType: "onReleased" },
  { name: "clearMapping", callback: "", eventType: "onLongPressDown" },
  { name: "clearMapping", callback: "", eventType: "onLongPressReleased" },
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
  ...Array.from({ length: 12 }, (_, index) => {
    const number = index + 1;
    return [
      { name: `deleteMap${number}`, callback: `deleteMap${number}`, eventType: "onReleased" },
      { name: `deleteMap${number}`, callback: "", eventType: "onLongPressDown" },
      { name: `deleteMap${number}`, callback: "", eventType: "onLongPressReleased" },
    ];
  }).flat(),
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
