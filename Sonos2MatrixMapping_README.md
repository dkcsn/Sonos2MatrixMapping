# Matrix Button Configuration

Version: 1.2.0

## Formål

Denne QuickApp mapper Logic Group Matrix knapper til andre QuickApps uden at bruge HC3 scenes.

I denne version understøttes Sonos handlinger, og Yahue installationer bliver detekteret som forberedelse til Hue/Yahue mapping.

Flowet er:

1. QuickApp finder Sonos Manager child devices.
2. QuickApp finder Yahue QA og Yahue child devices.
3. QuickApp finder Logic Group Matrix devices.
4. Du vælger Sonos, Matrix og knap-profiler i GUI.
5. QuickApp lytter selv på HC3 `refreshStates`.
6. Matrix `centralSceneEvent` sendes videre til Sonos Managerens eksisterende `switchAction`.

Selve Sonos action-logikken ligger stadig i Sonos Manager QA'en. Denne QA bygger mappingen og sender events videre.

## Sonos Data

Sonos-enheder hentes fra den eksisterende Sonos Manager QA.

Denne QA leder efter Sonos Manager child devices ved at finde devices som enten:

- har type `com.fibaro.sonosSpeaker`
- eller har QuickApp variables som `sonosIp`
- eller har QuickApp variables som `sonosPort`

Når en Matrix-trigger skal udføres, finder denne QA Sonos child device og bruger child device `parentId` som Sonos Manager QA id.

Kaldet udføres som:

```lua
fibaro.call(sonosManagerId, "switchAction", data)
```

## Yahue Data

Yahue-enheder hentes fra den eksisterende Yahue QA af Jan Gabrielsson.

Denne QA leder efter Yahue ved at finde devices som enten:

- har QuickApp variable `Hue_IP`
- eller har QuickApp variable `Hue_User`
- eller har Yahue QuickApp UUID `UPD896846032517896`
- eller har `Yahue` i device-navnet

Når Yahue QA'en er fundet, bruges dens child devices også som Yahue devices via `parentId`.

Kendte Yahue child classes tæller blandt andet:

- `RoomZoneQA`
- `ColorLight`
- `TempLight`
- `DimLight`
- `BinarySwitch`
- `MotionSensor`
- `TemperatureSensor`
- `LuxSensor`

Yahue-detektion er kun et discovery-lag i version 1.2.0. Sonos action-flowet er uændret.

## Matrix Data

Matrix-enheder findes via HC3 devices med Logic Group productInfo:

```lua
productInfo:match("^2,52")
```

Understøttede profiler:

| Model | ProductInfo | Beskrivelse |
| --- | --- | --- |
| ZBA7140 | `2,52,0,3,1,36` | Batteri vægcontroller, scene/button controller |
| ZDB5100 | `2,52,0,3,1,33` | 230V Matrix dimmer |
| ZRB5120 | `2,52,0,3,1,37` | 230V Matrix dual relay |
| ZRB5120 | `2,52,0,3,1,41` | 230V Matrix dual relay/demo variant |

Profilregler:

- ZBA7140 behandles som scene/button controller.
- ZDB5100 endpoint 5 er dimmer output, ikke knap.
- ZRB5120 endpoint 5 og 6 er relay outputs, ikke knapper.
- Central Scene triggers kommer fra root/lifeline for ZDB/ZRB.
- Knap-position må ikke udledes af child device rækkefølge alene.

## QuickApp Variables

| Variable | Brug |
| --- | --- |
| `mapping` | Gemmer alle Sonos -> Matrix mappings. Rediger normalt ikke manuelt. |
| `useViewLayout` | `false` som standard. `true` kan bruges til HTML/viewLayout visning. |
| `matrixScope` | `room` eller `all`. Styrer om Matrix-listen viser samme rum eller alle Matrix. |
| `sourceList` | Standard source liste til `nextSource` og `prevSource`, fx `[1,2,3,11,12,13]`. |
| `profile_next` | Knap-profil der vises som `Next` i GUI. |
| `profile_prev` | Knap-profil der vises som `Prev` i GUI. |

## Knap Profiler

Alle QuickApp variables der starter med `profile_` bliver indlæst som knap-profiler.

Navnet efter `profile_` bliver profilens id.

Eksempel:

```text
profile_next
```

giver profil-id:

```text
next
```

Variablen skal indeholde JSON.

Eksempel:

```json
{
  "label": "Next",
  "keyMap": {
    "HeldDown": ["toggleVolumeChange"],
    "Released": ["stopVolumeChange"],
    "Pressed": ["toggle"],
    "Pressed2": ["next"],
    "Pressed3": ["nextSource", "SOURCE_LIST"]
  }
}
```

`label` er teksten der vises i GUI.

`SOURCE_LIST` bliver automatisk erstattet med værdien fra QuickApp variablen `sourceList`.

Eksempel på Prev:

```json
{
  "label": "Prev",
  "keyMap": {
    "HeldDown": ["toggleVolumeChange"],
    "Released": ["stopVolumeChange"],
    "Pressed": ["toggle"],
    "Pressed2": ["prev"],
    "Pressed3": ["prevSource", "SOURCE_LIST"]
  }
}
```

## Mapping

Fra version 1.1.9 kan samme Sonos have flere mappings.

Intern mapping key er:

```text
sonosId::matrixIds
```

Eksempler:

```text
2623::97
2623::436
2623::97,436
```

Det betyder at samme Sonos kan bruges med flere forskellige Matrix-konfigurationer uden at overskrive tidligere linjer.

## Trigger Engine

Denne QA bruger ikke HC3 scenes.

Trigger engine bruger:

```text
http://127.0.0.1:11111/api/refreshStates
```

Det er den interne HC3 runtime URL fra QuickApp'en.

Når du tester i browser fra en computer, skal du bruge HC3 IP:

```text
http://192.168.201.243/api/refreshStates
```

## Debug

Brug knappen `Dump mapping` i GUI.

Den skriver:

- gemt mapping
- fundne Sonos child devices
- fundne Yahue apps
- fundne Yahue child devices
- fundne Matrix devices
- event aliases og profiler

Trigger status vises også i GUI:

- `Trigger engine: lytter`
- `Seneste trigger: ...`

Hvis der står `ingen mapping`, er triggeren modtaget, men Matrix id/knap id matcher ikke en gemt mapping.
