const fs = require("fs");
const path = require("path");

const cwd = process.cwd();
const lua = fs.readFileSync(path.join(cwd, "Sonos2MatrixMapping.lua"), "utf8");
const internalTriggerEngineLua = fs.readFileSync(path.join(cwd, "InternalTriggerEngine.lua"), "utf8");
const appVersion = (lua.match(/local APP_VERSION = "([^"]+)"/) || [null, "dev"])[1];
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
    HeldDown: ["hueDimStart", "up"],
    Released: ["hueDimStop"],
    Pressed: ["hueToggle"],
    Pressed2: ["hueSetValue", 100],
    Pressed3: ["hueNextScene"],
  },
};
const defaultProfileHuePrev = {
  label: "Hue Prev",
  targetType: "yahue",
  keyMap: {
    HeldDown: ["hueDimStart", "down"],
    Released: ["hueDimStop"],
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
  type: "com.fibaro.deviceController",
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
