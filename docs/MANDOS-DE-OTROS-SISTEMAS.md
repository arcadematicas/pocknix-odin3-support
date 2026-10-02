# Mandos y configs de emulador de otros sistemas

**Fecha**: 2026-10-03
**Autor**: subagente de cosecha (fransis)
**Objetivo**: traer al Pocknix/DeckStation los perfiles de mando por emulador
standalone y las configs de emulador que ya están probadas en la AYN Odin 3
(SM8750) o en hardware equivalente de otros sistemas.

Todo lo cosechado vive en
`packages/deckstation-arm/configs/_externos/<repo>/<emulador>/…`
(101 ficheros, 764 KB) y **no** se despliega automáticamente: `deploy-manifest.txt`
no menciona ninguna ruta `_externos/`.

---

## 1. Resumen: qué nos sirve de verdad

Cinco cosas, por orden de valor:

1. **La cruceta no llega como hat en la Odin, sino como botones 11–14.**
   Medido: `SDL_JoystickNumHats() == 0` con 16 botones. Y los tres repos ajenos
   coinciden: Batocera, ROCKNIX (`retroarch/gamepads/AYN_Odin2_Gamepad.cfg`,
   `up_btn = 11`) y Armada (`Vendor_2020_Product_3001.kl`, `544 DPAD_UP`) la
   codifican **todos** como botones 11/12/13/14, nunca como hat.
   Consecuencia directa sobre nosotros: **la cruceta no puede funcionar con
   nuestra config de Azahar**, que la mapea como `axis:0`/`axis:1` (hat
   convertido a ejes). Tampoco con la de DuckStation, que usa `DPadUp`. Es la
   causa más probable de "el emulador no ve el mando".
2. **El perfil de Azahar de Armada es casi trasplantable tal cual.** Escribe
   los botones con los mismos índices que usa la Odin (`a=1, b=0, x=3, y=2,
   l=9, r=10, select=4, start=6, home=5, dpad 11–14, gatillos `axis:4`/`axis:5`).
   Solo hay que cambiar el GUID y la etiqueta `name:`. En cambio el de ROCKNIX
   (pensado para un DualSense Edge) usa otro layout (`l=4, r=5, home=10,
   select=8, start=9`, dpad por `hat:0`) y **no** sirve sin rehacerlo.
3. **El perfil de DuckStation de ROCKNIX usa el mismo layout que la Odin**
   (`Button11..14`, `Button9/10`, `+Axis4/+Axis5`, `Axis0..3`), pero lo escribe
   con nomenclatura **numérica** (`Button11`) donde el nuestro usa la nominal
   (`DPadUp`, `LeftShoulder`). Las de ROCKNIX son trasladables tal cual; las
   nuestras no, sin más.
4. **Los `.gptk` (Gamepad Translation Kit) de ROCKNIX** son perfiles de
   traducción de mando *genéricos*, independientes del emulador, que definen
   hotkeys (quickload / quicksave / cambio de layout) y traducción de stick a
   ratón. Es exactamente la pieza que nos falta para Dolphin/Azahar/Flycast.
5. **Nuestro RetroArch usa `input_driver = "x"` (XInput) y el de ROCKNIX para
   SM8750 usa `"udev"`.** Una línea con impacto real: con `"x"` RetroArch solo
   ve lo que el kernel dé como XInput; con `"udev"` ve cualquier `/dev/input/js*`.
   No lo he cambiado (fuera del encargo), pero hay que decidirlo.

⚠️ **Advertencia sobre el punto 1**: los perfiles ajenos que "confirman" los
botones 11–14 no son cuatro descripciones independientes del hardware. Casi
todos usan la **numeración estándar de un X-Box 360** porque apuntan al
gamepad virtual que genera InputPlumber, no al joystick físico. Ver §5.2 — es
una distinción importante y no la da ni el upstream ni Batocera.

---

## 2. Método

- API de GitHub con el `GITHUB_PERSONAL_ACCESS_TOKEN` de
  `~/.config/opencode/opencode.jsonc`.
- Árboles enumerados con `/repos/<repo>/git/trees/HEAD?recursive=1`
  (ROCKNIX 6799 entradas, Batocera 7530, Armada 1104, deckstation-x86_64 2674,
  deckstation-arm 2914), filtrados por nombre y luego bajados **uno a uno** por
  la contents API (base64). **No** se ha clonado ningún repo entero.
- La Odin (`ssh odin`, usuario `deck`) se ha usado **solo en lectura** para
  medir GUIDs, ejes, botones y hats. No se ha instalado ni cambiado nada.

### Repos y ramas

| Repo | Rama por defecto | Entradas del árbol |
|---|---|---|
| `ROCKNIX/distribution` | `next` | 6799 |
| `batocera-linux/batocera.linux` | (master) | 7530 |
| `armada-os/armada` | (master) | 1104 |
| `stshunz/deckstation-x86_64` | (master) | 2674 |
| `stshunz/deckstation-arm` | (master) | 2914 |

> Ojo: `ROCKNIX/distribution` **no** acepta `?ref=<sha>` en la contents API
> (404) aunque el sha sea válido; hay que usar `ref=HEAD` o el nombre de rama.

---

## 3. Oro: ficheros que hablan de la Odin con su VID/PID real

| Fichero | Repo | Qué dice |
|---|---|---|
| `batocera/udev/99-ayn-odin3.rules` | Batocera | `ATTRS{name}=="AYN Odin3 Gamepad"` + `MODE=0666` + `ID_INPUT_JOYSTICK=1` + **`ID_INPUT_MOUSE=0`** |
| `batocera/hotkeygen/AYN_Odin3_Gamepad-2020-3001.mapping` | Batocera | El **nombre del fichero es el vendor/product literal**: `2020-3001` |
| `armada/input/Vendor_2020_Product_3001.kl` | Armada | Layout del gamepad `2020:3001`: código de kernel → botón (ver §5.2) |
| `rocknix/retroarch/gamepads/AYN_Odin2_Gamepad.cfg` | ROCKNIX | Perfil RetroArch **del gamepad AYN**, con `input_device = "AYN Odin2 Gamepad"` |
| `rocknix/inputplumber-SM8750/{01-ayn-controller.yaml,ayn_mcu.yaml}` | ROCKNIX | Perfiles InputPlumber del Odin 3 |
| `batocera/sistema/batocera.conf.AYN_Odin_3` | Batocera | `display.rotate.DSI=1`, `DSI-1=3`, `system.suspendmode=fake` |
| `batocera/hotkeygen/AYN_Odin2_Gamepad-2020-3001.mapping` | Batocera | Igual que el de Odin 3: `{"BTN_BACK": "controlcenter"}` |

**Ningún fichero de ningún repo trae el GUID SDL completo de la Odin**
(`0300bb95202000000130000001000000`, medido en la máquina). Traen el
vendor `2020` y el producto `3001` en forma de **nombre** o de **cadena**, no de
GUID. Y verificado: `grep -r 0300bb95202000000130000001000000` en nuestro repo
**no devuelve nada**, es decir que **ninguna** de nuestras configs de emulador
tiene hoy un perfil para el mando de la Odin.

---

## 4. Inventario

Columna **Utilidad**: `tal cual` = copiar y funciona; `adaptar` = la idea vale
pero hay que cambiar GUID/rutas/nombres; `referencia` = no se despliega, sirve
para decidir; `ya` = lo teníamos ya.

### 4.1 ROCKNIX — perfiles de mando por emulador standalone

Rutas de origen: `projects/ROCKNIX/packages/emulators/standalone/<emu>-sa/config/…`.
Los ficheros dentro de `config/<SoC>/` son **symlinks**; el contenido real vive
en `config/InputPlumber/` o `config/controllers/`. Se ha bajado el destino real.

| Fichero cosechado | Emulador | GUID / `input_device` que usa | Utilidad |
|---|---|---|---|
| `rocknix/azahar/qt-config.ini` | Azahar (3DS) | `0300fd574c050000e60c000011810000` (DualSense Edge, **17** perfiles de juego) | referencia — es el layout de **otro hardware**: dpad `hat:0`, `l=4`, `r=5`, `select=8`, `start=9`, `home=10`, `zl=axis:2`. Sirve para ver la sintaxis y los 17 perfiles por juego, **no** para trasplantar el mapeo |
| `rocknix/cemu/settings.xml` | Cemu (WiiU) | — | referencia — ajustes generales, no de mando |
| `rocknix/cemu/wii_u_gamepad.xml` | Cemu | `0_0300f5a35e040000120b000001000000` (`display_name=InputPlumber GameController`) | **adaptar** — dpad como botones 11–14, rumble 0.15, deadzone 0.25, mapeo botón↔mando WiiU |
| `rocknix/cemu/wii_u_pro_controller.xml` | Cemu | idem | **adaptar** — lo mismo en formato Pro Controller |
| `rocknix/dolphin/Dolphin.ini` | Dolphin | — | referencia — config general SM8750 |
| `rocknix/dolphin/GFX.ini` | Dolphin | — | referencia — vídeo SM8750 |
| `rocknix/dolphin/Hotkeys.ini` | Dolphin | `Device = SDL/0/@SDL_DEVICE@` | **tal cual** — Guide+Start salir, Guide+E captura, Guide+R/L save/load, Guide+Pad N/S ranura, Guide+Trigger R/L velocidad. Ojo: `@SDL_DEVICE@` es un token que **ROCKNIX sustituye en runtime**; en Pocknix hay que dejarlo fijo |
| `rocknix/dolphin/controllers/Hotkeys.ini` | Dolphin | idem | **tal cual** (igual que el anterior) |
| `rocknix/dolphin/controllers/GamecubeControllerProfiles/GCPadNew.ini.{east,south}.{inline,stacked}` | Dolphin | n/a | referencia — 4 variantes de posición de la cruceta (al norte/al sur, inline/stacked), útil para decidir el estilo de mando |
| `rocknix/dolphin/controllers/WiiControllerProfiles/{classic,nunchuck,hremote,vremote}.ini` | Dolphin | n/a | referencia — perfiles Nunchuk/Classic/Remote (Wii) |
| `rocknix/duckstation/settings.ini` | DuckStation | `SDL-0/…` | **tal cual** — **el fichero más útil del lote**: dpad como `Button11..Button14`, shoulders `Button9/10`, gatillos `+Axis4/+Axis5`, sticks `Axis0..Axis3`, L3/R3 `Button7/8`, y `[Hotkeys]` con `SDL-0/Guide & …` |
| `rocknix/flycast/emu.cfg` | Flycast | — | referencia |
| `rocknix/flycast/SDL_DualSense.cfg`, `SDL_DualSense_Edge.cfg`, `SDL_Keyboard.cfg`, `SDL_H700_Gamepad.cfg` | Flycast | — | **tal cual** — formato `[analog] bindN = eje±:acción`, `[digital] bindN = botón:acción`, dpad **13/14/15/16**, triggers **4/5**, menu 8, start 9. Nota: aquí la dpad es 13–16, **no** 11–14 → depende de cómo la exponga el backend SDL de Flycast |
| `rocknix/melonds/melonDS.ini` | melonDS | — | referencia |
| `rocknix/mupen64plus/mupen64plus.cfg` | Mupen64Plus / RMG | — | referencia |
| `rocknix/mupen64plus/input-sdl-default.ini` | Mupen64Plus | — | **tal cual** — perfil SDL de stick |
| `rocknix/mupen64plus/input-sdl-zlswap.ini` | Mupen64Plus | — | **tal cual** — variante con ZL/ZR intercambiados (útil si la Odin los entrega al revés) |
| `rocknix/ppsspp/ppsspp.ini` | PPSSPP | — | referencia |
| `rocknix/ppsspp/controls-InputPlumber.ini` | PPSSPP | joystick `10-…` (gamepad 1) | **tal cual** — fichero `joystick=10` (= gamepad 1) con índices shifted: `Up=10-19, Down=10-20, Left=10-21, Right=10-22, Circle=10-190, Cross=10-189, Square=10-191, Triangle=10-188, Start=10-197, Select=10-196, L=10-193, R=10-192`; cruceta analógica en el rango `4000+` (`An.Up=10-4003`, `An.Left=10-4001`…); stick derecho `4004+`; combos con `Pause=10-198`: `Save State`, `Load State`, `Fast-forward=10-198:10-4010`, `Exit App=10-198:10-197`. **Ojo: aquí la dpad es 19/20/21/22, no 11–14** (PPSSPP numera distinto o el perfil es de otro device) |
| `rocknix/rpcs3/{config.yml,CurrentSettings.ini,active_input_configurations.yml,Default.yml}` | RPCS3 | `Device: DualSense Wireless Controller 1`, `Handler: SDL` | **adaptar** — `Default.yml` es la plantilla completa de los 7 jugadores con TODAS las acciones; solo el `Player 1` está rellenado |
| `rocknix/vita3k/config.yml` | Vita3K | — | referencia |
| `rocknix/xemu/xemu.toml` | xemu (Xbox) | `port1 = '0000f353526574726f696420506f6300'` | **tal cual** — ese es el **SDL GUID del GameCube original**, literal |
| `rocknix/supermodel/Supermodel.ini` | Supermodel (Model 3) | — | referencia |
| `rocknix/ares/settings.bml` | ares | — | referencia |
| `rocknix/gopher64/config.json` | gopher64 (N64) | `input_profiles.default.keys` (IDs de botón) | referencia |
| `rocknix/gzdoom/gzdoom.ini` | GZDoom | — | referencia |
| `rocknix/scummvm/scummvm.ini` | ScummVM | — | referencia |
| `rocknix/dsperate/dsperate.ini` | DSPerate | — | referencia |
| `rocknix/aethersx2/PCSX2.ini`, `rocknix/armsx2/PCSX2.ini` | AetherSX2 / ARM SX2 | — | referencia — deriva de PCSX2 |
| `rocknix/nanoboyadvance/keymap.toml` | NanoBoyAdvance | — | referencia — solo teclado |
| `rocknix/drastic/drastic-SM4450.cfg` | Drastic | — | referencia — perfil de teclado como mando |
| `rocknix/hatarisa/Atari-ST-default.cfg` | Hatari | `[Joystick0] kFire = Right Ctrl` | referencia — perfil de joystick |
| `rocknix/vice/sdl-vicerc` | VICE (C64) | `JoyDevice1=4`, `JoyMenuControl=1` | referencia — perfil de joystick |
| `rocknix/yabasanshiro/keymapv2_rg_arc_joypad.json` | Yaba Sanshiro (Dreamcast) | JSON indexado por GUID de joystick | **adaptar** — formato `{"<guid>": {"a": {"id":1,"type":"button","value":1}, "analogx": {"id":0,…}}}`. Godot. Interesante porque el perfil va indexado **por GUID** |

### 4.2 ROCKNIX — perfiles de traducción de mando (`.gptk`)

`projects/ROCKNIX/packages/emulators/standalone/*/config/*.gptk` y
`packages/compat/fex-emu/config/gptk/fexconfig.gptk`.
Son del Gamepad Translation Kit de ROCKNIX: **no son configs del emulador, son
capas de traducción entre el joystick SDL y los eventos que la app ve**, con
hotkeys (`*_hk`) y traducción de stick → ratón. **Es la pieza que a nosotros
más nos interesa y no tenemos.**

| Fichero | Qué define |
|---|---|
| `rocknix/gptk/azahar.gptk` | L1+hotkey → quickload (Alt+L), R1+hotkey → quicksave (Alt+S), L2+hotkey → F10 (cambio de layout), R2+hotkey → F9 (cambio de pantalla) |
| `rocknix/gptk/azahar_mouse_addon.gptk` | `r3 = mouse_left`, stick derecho → ratón, `mouse_scale = 6128` (addon aparte, se suma al anterior) |
| `rocknix/gptk/melonDS.gptk` | L1/R1/L2/R2 + hotkey, `r3 = mouse_left`, stick derecho → ratón, `deadzone_triggers = 3000`, `mouse_scale = 6128`, `mouse_delay = 16` |
| `rocknix/gptk/flycast.gptk` | L1+hotkey = l, R1+hotkey = s, R2+hotkey = f |
| `rocknix/gptk/drastic.gptk` | Traducción completa a **teclado**: `back=e, a=d, b=c, x=z, y=v, l1=q, l2=n, r1=o, r2=p` + hotkeys |
| `rocknix/gptk/fexconfig.gptk` | Traducción a teclado + ratón para FEXEmu |

### 4.3 ROCKNIX — RetroArch

| Fichero | Utilidad |
|---|---|
| `rocknix/retroarch/retroarch-SM8750.cfg` | **adaptar** — 894 líneas de RetroArch ya configurado para SM8750: `input_driver = "udev"`, `input_joypad_driver = "udev"`, `input_autodetect_enable = true`, `input_max_users = 5`, `audio_driver` y `microphone_enable` para AYN |
| `rocknix/retroarch/gamepads/AYN_Odin2_Gamepad.cfg` | **tal cual (cambiando el nombre)** — perfil del gamepad AYN: botones 0–15, `l2_axis=+4`, `r2_axis=+5`, `l_x=+0/-0`, `l_y=+1/-1`, `r_x=+2/-2`, `r_y=+3/-3`, hotkey `5` (Guide), exit `6` (Start), save `10`, load `9`, rewind `+4`, fast-forward `+5` |
| `rocknix/retroarch/gamepads/Xbox_360_Controller.cfg` | **tal cual** — el mismo layout con `input_vendor_id = "1118"` / `input_product_id = "654"` y `input_menu_toggle_gamepad_combo = nul` |
| `rocknix/retroarch/gamepads/DualSense.cfg`, `DualSense_Edge.cfg` | referencia — los mismos números de botón/eje, para gamepad DS |

> **Hallazgo de diferencia con lo nuestro**: nuestro `configs/retroarch/retroarch.cfg`
> tiene `input_driver = "x"` (XInput). El de ROCKNIX para SM8750 usa `"udev"`.
> Con `"x"` RetroArch solo ve lo que el kernel exponga como XInput; con `"udev"`
> ve cualquier `/dev/input/js*`. Es una diferencia de una línea con impacto real.

### 4.4 ROCKNIX — InputPlumber, udev y quirks de AYN

| Fichero | Utilidad |
|---|---|
| `rocknix/inputplumber-SM8750/01-ayn-controller.yaml` | **adaptar** — el perfil de device del Odin 3. Usa `target_devices: [ds5, keyboard]` y **no** lleva `passthrough: true`. El nuestro usa `deck` + `passthrough: true` |
| `rocknix/inputplumber-SM8750/ayn_mcu.yaml` | **tal cual** — capability map del MCU (el "custom controller" de AYN) |
| `rocknix/inputplumber-SM8550/02-ayn-controller.yaml`, `ayn_mcu.yaml` | referencia — variantes SM8550 (Odin 2 / Thor) |
| `rocknix/wireplumber-ayn-thor-lite.conf` | referencia — config de WirePlumber para AYN |
| `rocknix/quirks/AYN_Odin3/050-game-configs` | referencia — **nada de mando**: desactiva el micro de RetroArch y pone `audio_driver = "pulse"` |
| `rocknix/quirks/AYN_Odin2/009-commander-cfg`, `AYN_Thor/009-commander-cfg` | referencia — escribe `commander.cfg` con `disp_ppu_x=4 / disp_ppu_y=4` |
| `rocknix/SUPPORTED_EMULATORS_SM8750.md` | referencia — qué emuladores declara ROCKNIX soportar en SM8750 |

### 4.5 Batocera

| Fichero | Emulador / capa | Utilidad |
|---|---|---|
| `batocera/udev/99-ayn-odin3.rules` | udev, gamepad Odin 3 | **tal cual** — `SUBSYSTEM=="input", ATTRS{name}=="AYN Odin3 Gamepad", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1", ENV{ID_INPUT_MOUSE}="0"` |
| `batocera/hotkeygen/AYN_Odin3_Gamepad-2020-3001.mapping` | hotkeygen | **tal cual** — `{"BTN_BACK": "controlcenter"}`. Minimalista: **solo** el botón BACK abre el centro de control. Ni Start, ni shoulders, ni gatillos |
| `batocera/hotkeygen/AYN_Odin2_Gamepad-2020-3001.mapping` | hotkeygen | idem (idéntico) |
| `batocera/hotkeygen/hotkey-default_mapping.conf` | hotkeygen | **tal cual** — el mapa botón→acción de Batocera: BACK→exit, MENU→menu, PAUSE→pause, RESTART→reset, FILE→files, SAVE→save_state, SEND→restore_state, NEXT/PREVIOUS→slot, REWIND→rewind, FASTFORWARD, SYSRQ→screenshot, VOL±, BRIGHTNESS_CYCLE→controlcenter, SUBTITLE→translation, FRONT→bezels, CAMERA_FOCUS→swap_screen, PRESENTATION→screen_layout, CONTEXT_MENU→controlcenter, ATTENDANT→onscreen-keyboard / recording |
| `batocera/hotkeygen/hotkey-default_mapping-sm8250.conf` | hotkeygen | referencia — variante SoC anterior |
| `batocera/hotkeygen/hotkey-default_context.conf`, `hotkey-common_context.conf` | hotkeygen | referencia — acción→comando shell (volume, brillo, centre de control) |
| `batocera/hotkeygen/hotkey-{AYN_Odin2_Gamepad,GO-Ultra_Gamepad,Steam_Deck}.mapping` | hotkeygen | referencia — **todos son triviales, igual que el de la Odin**: 35–46 bytes y **una sola entrada**. El de GO-Ultra es `{"BTN_TRIGGER_HAPPY4": "controlcenter"}`. Los de Steam Deck y Odin 2 son idénticos al de Odin 3. **No hay un "mapa completo de hotkeys" en ningún `.mapping` de Batocera**: eso es `hotkey-default_mapping.conf`, que va aparte |
| `batocera/perfiles/azahar-3ds.keys` | Azahar | **tal cual** — traduce `joystick2` a ratón (stylus) y `r3` a `BTN_LEFT`. **Justo lo que necesita la pantalla táctil de la Odin para el stylus de 3DS** |
| `batocera/perfiles/rpcs3-namco3xx.keys` | RPCS3 | referencia — dpad → `KEY_W/A/S/D` (mover cámara) |
| `batocera/sistema/batocera.conf.AYN_Odin_3` | sistema | referencia — `display.rotate.DSI=1`, `DSI-1=3`, `system.suspendmode=fake` |

> El `board/batocera/qualcomm/sm8750/` de Batocera **no tiene ninguna config de
> mando por emulador**: solo udev, conf de sistema, patches de alsa/mesa/gcc e
> init scripts. Batocera no se apoya en perfiles por emulador, usa su generador
> de hotkeys y un sistema de eventos genérico. Por eso lo útil de Batocera son
> los `.mapping` y los `.keys`, no los `.ini`.

### 4.6 Armada

| Fichero | Emulador / capa | Utilidad |
|---|---|---|
| `armada/azahar/qt-config.ini` | Azahar | **el más trasplantable del lote** — 23 perfiles con GUID `030079f6de280000ff11000001000000`, que es justo el gamepad virtual `28de:11ff` de nuestra Odin. Sintaxis **nueva** `api:controller,…,maptype:guid+port,name:…`. Botones en layout X-Box 360 **idéntico al de la Odin**, dpad como botones 11–14, `zl=axis:4`, `zr=axis:5`, deadzone **0.05**, y define `motion_device` y `touch_device`. Para usarlo solo hay que cambiar el GUID y las etiquetas `name:` |
| `armada/azahar-store/qt-config.ini` | Azahar (plantilla del Decky) | referencia — misma plantilla que la anterior, con los perfiles completos |
| `armada/melonds/melonDS.toml` | melonDS (TOML, no INI) | referencia |
| `armada/input/Vendor_2020_Product_3001.kl` | capa de entrada | **referencia** — layout de teclado del gamepad AYN. Es el **código de botón real del kernel**: `304=BUTTON_A, 305=BUTTON_B, 307=BUTTON_X, 308=BUTTON_Y, 310=BUTTON_L1, 311=BUTTON_R1, 314=BUTTON_SELECT, 315=BUTTON_START, 316=BUTTON_MODE, 317/318=BUTTON_THUMBL, 544=DPAD_UP, 545=DPAD_DOWN, 546=DPAD_LEFT, 547=DPAD_RIGHT`, ejes `0x00=X, 0x01=Y, 0x02=LTRIGGER, 0x03=Z, 0x04=RZ, 0x05=RTRIGGER` |
| `armada/input/70-armada-inputplumber.rules` | udev | referencia — `hidraw` del `28DE:12F0` a `GROUP=input MODE=0660` (para Steam) + tags de haptics |
| `armada/input/inputplumber-intercept` | busctl | **tal cual** — script de 20 líneas: cambia `InterceptMode` de `org.shadowblip.InputPlumber` entre `overlay (2)`, `gamepad (3)` y `reset (0)`. Interesantísimo: es la forma de **desactivar el/gamepad virtual de InputPlumber** y dejar pasar el físico |
| `armada/input/controller-type.py` | InputPlumber | **adaptar** — 200 líneas. Aplica `controller_type` ∈ {`deck-uhid`, `xbox-series`, `xb360`, `ds5`} vía `busctl SetTargetDevices` sobre todos los `CompositeDeviceN`, leyendo los targets actuales para conservar `keyboard`/`mouse`. Es exactamente lo que hace nuestro `01-ayn-controller.yaml` pero **en runtime y con opción de cambiar** |
| `armada/input/armada-controller-type.service` | systemd | referencia — `oneshot`, `After`/`Requires=inputplumber.service`, `Before=display-manager.service` |
| `armada/input/controller-profile-test.sh`, `odin3-hdr-session-test.sh` | tests | referencia — tests de la capa de entrada y de sesión |
| `armada/steamos-manager-sm8750.toml` | sistema | referencia |
| `armada/sistema/ayn-odin-3.conf` | sistema | referencia |

### 4.7 stshunz/deckstation-*

| Repo | Fichero | Utilidad |
|---|---|---|
| `deckstation-x86_64` | `dolphin/Deck.ini` | **tal cual** — perfil Dolphin **completo** para `evdev/0/Microsoft X-Box 360 pad 0`: nunchuk, classic, IR pointer, calibración de sticks, deadzones. Es el fichero de mando más completo de todo el lote |
| `deckstation-x86_64` | `dolphin/Dolphin.ini`, `dolphin/G2MP01.ini` | referencia / `G2MP01.ini` es perfil de GameID 2 (Maniac Mansion), no de mando |
| `deckstation-x86_64` | `azahar/qt-config.ini` | referencia — mezcla de `0300f6b6c82d00000b31000014010000` (8BitDo Ultimate 2C, **el mismo que ya usaba nuestra config**) y `00300f6b6…` (con ceros de más, GUID corrupto) |
| `deckstation-x86_64` | `azahar/00040000000A8600.ini`, `000400000011C500.ini` | referencia — perfiles por GameID de 3DS |
| `deckstation-x86_64` | `citron/{config.ini,GameUserSettings.ini}`, `bigpemu/BigPEmuConfig.bigpcfg` | referencia |
| `deckstation-arm` | — | **nada**: sus `configs/` ya son copia literal de lo que hay en nuestro `configs/` (mismos nombres: `azahar/qt-config.ini`, `citron/custom/*.ini`, `dolphin/dolphin.ini`…) |

---

---

## 5. Lecturas de la Odin (solo lectura) que respaldan lo anterior

### 5.1 Dispositivos de entrada

| /dev/input | Nombre | Bus/Vendor/Product/Version | PHYS |
|---|---|---|---|
| event6 | **`AYN Odin3 Gamepad`** | 3 / **2020** / **3001** / 1 | `rsinput-gamepad/input0` |
| event7 | `InputPlumber Keyboard` | — | — |
| event8, event9 | `InputPlumber Generic Steam Controller` | 3 / 28de / 12f0 / 110 | `vhci/usb1/1-1` |
| event11 | **`Microsoft X-Box 360 pad 0`** | 3 / 28de / 11ff / 1 | `/devices/virtual/input/input12` |
| event10 | jack | | |

`js0` = `AYN Odin3 Gamepad`, `js1` = `Microsoft X-Box 360 pad 0`.

SDL (vía `libSDL2-2.0.so.0` con ctypes) ve **un solo joystick**:

- `AYN Odin3 Gamepad`, GUID **`0300bb95202000000130000001000000`**
- **6 ejes, 16 botones, 0 hats**

Implicaciones:

1. **`SDL_JoystickNumHats() == 0`** → la cruzeta no llega como hat. Llega como
   botones **11–14**. Cualquier perfil que pida `hat:0` **no puede funcionar**.
2. SDL **solo lista 1 joystick** aunque hay 4 dispositivos de entrada: los
   virtuales de InputPlumber (`deck`, `xb360`) **no aparecen** en
   `SDL_NumJoysticks()`. Es la causa más probable del "el emulador no ve el
   mando" en las apps SDL.
3. `libSDL2` **no enlaza `libudev`** (`ldd` solo muestra `libc`), así que no
   puede descubrir dispositivos por udev; solo hace su escaneo inicial. Por eso
   los uinput virtuales que aparecen *después* no los ve.

### 5.2 Los dos layouts que conviven (y por qué importa)

Hay que distinguir **dos** cosas que se parecen pero no son lo mismo:

**(a) El joystick físico de la Odin** (`AYN Odin3 Gamepad`, vendor `2020`,
product `3001`, driver `rsinput`). El `.kl` de Armada
(`Vendor_2020_Product_3001.kl`) traduce sus códigos de **kernel estándar**:

```
304 BTN_SOUTH  305 BTN_EAST  306 (sin mapear)  307 BTN_NORTH  308 BTN_WEST
309 (sin mapear)  310 BTN_TL  311 BTN_TR  312/313 (sin mapear)
314 BTN_SELECT  315 BTN_START  316 BTN_MODE  317 BTN_THUMBL  318 BTN_THUMBR
544 DPAD_UP  545 DPAD_DOWN  546 DPAD_LEFT  547 DPAD_RIGHT
ejes: 0x00 X  0x01 Y  0x02 LTRIGGER  0x03 Z  0x04 RZ  0x05 RTRIGGER
```

Ojo: **306, 309, 312 y 313 no aparecen** en el `.kl` (son `BTN_C`, `BTN_Z`,
`BTN_TL2`, `BTN_TR2`). O el `.kl` está incompleto, o los gatillos no llegan como
botones (solo como ejes), que es lo esperable.

**(b) El gamepad virtual que produce InputPlumber**, que es lo que ven las
apps. Y aquí está lo importante: **todos** los perfiles cosechados
(`retroarch/gamepads/AYN_Odin2`, `retroarch/gamepads/Xbox_360_Controller`,
`duckstation/settings.ini`, `armada/azahar/qt-config.ini`, `ppsspp/controls-*`)
usan **exactamente la numeración estándar de un X-Box 360**:

```
0=A(circle) 1=B(cross) 2=X(square) 3=Y(triangle) 4=Select 5=Guide 6=Start
7=L3 8=R3 9=L1 10=R1  11=Up 12=Down 13=Left 14=Right
ejes: 0=LX 1=LY 2=RX 3=RY 4=L2 5=R2
```

Esa es la razón por la que encajan tan bien entre sí: no son cuatro
descripciones independientes del hardware, son cuatro copias del **mismo**
perfil estándar, porque todas apuntan al mismo gamepad virtual.

**Lo que esto significa para nosotros**: el layout que hay que escribir en las
configs de los emuladores es el de **X-Box 360** (o sea, el del virtual de
InputPlumber), no el del joystick crudo. El cambio de dpad a botones 11–14
sigue siendo válido porque el virtual tampoco expone hats.

⚠️ **Lo que NO está verificado**: la numeración real de botones y ejes que SDL
ve en el joystick **físico** (`AYN Odin3 Gamepad`). Lo medido es el conteo
(6 ejes, 16 botones, 0 hats) y el GUID; el índice exacto de cada botón no se ha
confirmado. Si algún emulador acabara usando el joystick físico en vez del
virtual, sus perfiles no valdrían. **No dar por buena la tabla de abajo para el
físico.**

## 6. El layout que hay que escribir en las configs

Es el **X-Box 360 estándar** (ver §5.2), que es lo que ve cualquier emulador SDL
a través del gamepad virtual de InputPlumber:

| SDL | Botón | Eje | Nota |
|---|---|---|---|
| 0 | A (circle) | 0 | stick izq. X (`-0` / `+0`) |
| 1 | B (cross) | 1 | stick izq. Y (`-1` / `+1`) |
| 2 | X (square) | 2 | stick der. X (`-2` / `+2`) |
| 3 | Y (triangle) | 3 | stick der. Y (`-3` / `+3`) |
| 4 | Select / Back | 4 | gatillo L (`+4`) — también *rewind* en RetroArch |
| 5 | Guide / Home | 5 | **botón de hotkey** en RetroArch; home en Azahar |
| 6 | Start | 5 | **salir del emulador** en RetroArch |
| 7 | L3 | | |
| 8 | R3 | | también "click izquierdo" del ratón en los `.gptk` de Azahar/melonDS |
| 9 | L1 | | *load state* en RetroArch |
| 10 | R1 | | *save state* en RetroArch |
| 11 | ▲ | | |
| 12 | ▼ | | |
| 13 | ◀ | | |
| 14 | ▶ | | |
| | | 5 | gatillo R (`+5`) — también *fast-forward* en RetroArch |

⚠️ Excepción sin explicar: los perfiles de **Flycast** de ROCKNIX numeran la
dpad como **13/14/15/16** y los triggers como botones **4/5**, no como ejes.
No sé si es el backend SDL de Flycast desplazando el índice o un perfil escrito
para otra versión. **Ojo con copiar los `.cfg` de Flycast tal cual.**

⚠️ El perfil de Azahar de **ROCKNIX** (pensado para un DualSense Edge) usa
`l=4, r=5, home=10, select=8, start=9` y la dpad por `hat:0`: es otro hardware.
**No confundir con el de Armada**, que sí está en layout X-Box 360.

## 7. Diferencias con nuestras configs actuales

Medido sobre nuestros ficheros reales, no de memoria:

| Tema | Nosotros | Ajenos |
|---|---|---|
| **Azahar, dpad** | `button_up="axis:1,direction:-"` etc. → **la dpad como hat convertido a ejes del stick** | **botones 11/12/13/14** |
| **Azahar, shoulders** | `select=6`, `start=7`, `home=8`, `l=4`, `r=5` (desplazados +2) | `select=4`, `start=6`, `home=5`, `l=9`, `r=10` |
| **Azahar, gatillos** | `zl="axis:2,+"` | `zl="axis:4,+"` (Armada) / `axis:2` (ROCKNIX) |
| **Azahar, GUID** | `0300f6b6c82d00000b31000014010000` (8BitDo Ultimate 2C, `2dc8:310b`) y `03000000de28…` (con ceros de más) | `030079f6de280000ff11000001000000` (X-Box 360 de InputPlumber, `28de:11ff`), `0300fd574c05…` (DualSense Edge), `0300f5a35e04…` (InputPlumber GameController) |
| **Azahar, número de perfiles** | 30 ocurrencias del GUID 8BitDo | 23 (Armada) / 17 (ROCKNIX) |
| **DuckStation, nomenclatura** | `Up = SDL-0/DPadUp`, `L2 = SDL-0/+LeftTrigger` (nominal) | `ButtonUp = Controller0/Button11`, `ButtonL2 = Controller0/+Axis4` (numérica) |
| **DuckStation, backend** | `SDL = true`, `XInput = false`, `RawInput = false` | `SDL-0/…` |
| **RetroArch, driver** | `input_driver = "x"` | `input_driver = "udev"` |
| **RetroArch, hotkey** | `enable_hotkey_btn = 6` (Start), load `4`, save `5` | `enable_hotkey_btn = 5` (Guide), load `9` (L1), save `10` (R1), exit `6` |
| **RetroArch, usuarios** | `input_max_users = 8` | `5` |
| **InputPlumber** | target `deck` + `passthrough: true` | target `ds5` + `keyboard`, **sin** `passthrough` |
| **InputPlumber, F1** | → QuickAccess | → "F1 Key" |
| **Paddle derecho** | → KeyF13 (MangoHud) | → RightPaddle2 |
| **deadzone Azahar** | el que hay en el fichero | 0.05 (Armada) / 0.1 (ROCKNIX) |

**El caso de Azahar es el más grave**, y por dos motivos encadenados:

1. **El GUID no aparece.** Nuestro perfil declara `2dc8:310b` (8BitDo).
   El joystick que ve SDL en la Odin es el **físico**, GUID `2020…`. Un perfil
   cuyo GUID no coincide con ningún joystick presente **no se aplica**: todos los
   botones caen al perfil por defecto de Azahar.
2. **Ni siquiera tiene botones 11–14.** La dpad está mapeada como
   `axis:0, direction:±` / `axis:1, direction:±`, que es como Azahar expresa un
   **hat**. El joystick físico de la Odin tiene `0 hats` (medido) → esa
   cruceta no tiene de dónde salir.

⚠️ Y hay una segunda capa: los perfiles cosechados de Armada (los más
trasplantables) usan el GUID del **virtual** `28de:11ff`, que en nuestra Odin
**tampoco ve SDL** (`SDL_NumJoysticks() == 1`). Es decir, tal cual, **ninguno de
los dosGUIDs posibles encaja hoy**. Hay que elegir: usar el GUID del físico y
adaptar el layout, o arreglar por qué SDL no ve el virtual. Ver §10.2.

Los dos perfiles cosechados, enfrentados (extraído de los ficheros, perfil 1):

| | ROCKNIX (DualSense Edge) | Armada (X-Box 360 de InputPlumber) |
|---|---|---|
| sintaxis | `button:N,engine:sdl,guid:…,port:0` | `api:controller,button:N,engine:sdl,guid:…,maptype:guid+port,name:…,port:0` |
| a / b | `1` / `0` | `1` / `0` |
| x / y | `2` / `3` | `3` / `2` (¡X e Y intercambiados frente a Xbox!) |
| select / start / home | `8` / `9` / `10` | `4` / `6` / `5` |
| l / r | `4` / `5` | `9` / `10` |
| dpad | `direction:up,hat:0` … | `button:11` … `button:14` |
| zl / zr | `axis:2` / `axis:5` | `axis:4` / `axis:5` |
| circle_pad / c_stick | axis 0,1 / 3,4 | axis 0,1 / **2,3** |
| deadzone | 0.1 | 0.05 |

⚠️ Ojo al detalle de Armada: pone `x=3` e `y=2`, al revés de la convención
Xbox/DS de Valve. O es intencionado (Azahar usa los nombres Nintendo: X =
arriba, Y = izquierda, y el mapeo A/B ya está cruzado a propósito: `a=1`=B,
`b=0`=A), o es un descuido. **No lo he verificado en la Odin.**

## 8. Descartes (y por qué)

| Descartado | Motivo |
|---|---|
| Todo `firmware/`, `*.mbn`, `*.tplg`, `adsp.dtb`, `adspr.jsn`… | Binarios con copyright; además es firmware Qualcomm, no nos sirve |
| `ppsspp-sa/config/PSP/Cheats/*.ini` (39 ficheros) | Cheats, no perfiles de mando |
| `*.glshadercache`, `search_paths.bin`, `user_settings.bin` | Binarios |
| `batocera/dolphin-GHAE6E.ini`, `dolphin-GJAP6E.ini` | **Parecían perfiles de mando y son cheats** de Dolphin (GameID). Se bajaron, se vieron y se descartaron |
| `mednafen/config/common/mednafen.template` | 402 KB de plantilla de config global; mednafen no es prioritario y no es un perfil de mando |
| `batocera/triggerhappy/conf/sm8550/multimedia_keys_AYNThor.conf` | 404, no existe en el repo |
| `dolphin-sa/config/<SoC>/GamecubeControllerProfiles` y `WiiControllerProfiles`, `mupen64plus-sa/input-sdl`, `flycast-sa/mappings`, `cemu-sa/controllerProfiles`, `rpcs3-sa/input_configs`, `ppsspp-sa/controls.ini` | Son **symlinks**, no ficheros: la contents API devuelve el *destino* del enlace como si fuera el contenido. Se bajó el destino real (`config/InputPlumber/…`, `config/controllers/…`) |
| Patches de kernel/dts/alsa de Batocera y ROCKNIX | Fuera del objetivo (ya hay `reference/` propio con patches) |
| `rpkg`, `.dsi`, scripts de build, `Config.in`, `*.mk` | Build del sistema, nada que ver con mandos |
| `dsperate-sa/config/RK33xx/*.oga` etc. | Variantes por SoC de la RK3326, irrelevantes |
| Escribir en la Odin | Prohibido: es solo lectura |

---

## 9. Lo NO hecho

- **No he adaptado ningún perfil al GUID de la Odin.** Se han dejado tal cual.
  El trabajo de traducirlos (GUID `0300bb95202000000130000001000000`, dpad a
  botones 11–14) es el siguiente paso natural y hay que decidir antes si se
  quiere el perfil del joystick **físico** (`AYN Odin3 Gamepad`) o el **virtual**
  (`Microsoft X-Box 360 pad 0` de InputPlumber) — son GUID distintos.
- **No he tocado `deploy-manifest.txt`.** Nada de `_externos/` se despliega.
- **No he tocado ninguna config nuestra.** Ni Azahar, ni Dolphin, ni DuckStation,
  ni RetroArch, ni los `.yaml` de InputPlumber.
- **No he instalado GPTK.** Es un paquete de ROCKNIX; habría que decidir si
  compilarlo o reimplementar la traducción con `uinput`/AntiMicroX.
- **No he probado ninguno de estos perfiles en la Odin.** La Odin se ha usado
  solo para leer GUIDs y capacidades. Probar un perfil exige escribir en su
  `~/.config`, que es justo lo que no se ha hecho.
- **No he fijado las versiones exactas** de Azahar/Dolphin/etc. que usaría
  DeckStation, así que no puedo afirmar que el formato de los perfiles sea
  idéntico; Dolphin 5 vs el Dolphin del master de ROCKNIX, por ejemplo, pueden
  diferir.

---

## 10. Dudas / cosas que hay que verificar

1. **Flycast numera la dpad 13–16 y DuckStation 11–14.** ¿Depende del backend
   SDL de cada emulador o de la versión? Si nuestra dpad llega como 11–14, el
   perfil de Flycast de ROCKNIX **no** se puede copiar tal cual.
2. `InputPlumber` en nuestra Odin genera el "Gamepad virtual" como **USB HID**
   (`vhci/usb1`), no como XInput USB. SDL sin udev no lo ve. ¿Habría que
   cambiar el target de `deck` a `xb360`, o forzar que InputPlumber emule un
   dispositivo XInput de kernel (`xpad`) en lugar de un uinput HID? Es
   probablemente **la** solución al problema de fondo, y `armada/input/controller-type.py`
   + `inputplumber-intercept` son justo las herramientas para ello.
3. **El joystick virtual `Microsoft X-Box 360 pad 0` (event11) no está
   medido**: no sé si expone la cruceta como hat, como botones 11–14, o de las
   dos formas. Solo he medido el físico (0 hats). Y no sé qué ve realmente cada
   emulador, porque **ninguno de los dos GUIDs disponibles coincide hoy con lo
   que SDL enumera**.
4. Los `.gptk` de ROCKNIX asoman en `azahar`, `melonDS`, `flycast`, `drastic`,
   `fex-emu`, `installer`… pero **no** en Dolphin, DuckStation, PPSSPP, RPCS3,
   Vita3K, Cemu. O esos emuladores no lo necesitan, o la integración no existe
   todavía. **No lo sé.**
5. El `AYN Odin2 Gamepad.cfg` de RetroArch usa `input_device = "AYN Odin2 Gamepad"`.
   En la Odin 3 el nombre es `AYN Odin3 Gamepad`. Cambiar el nombre es
   trivial, pero **no está verificado** que los índices de botón/eje sean
   idénticos entre el mando del Odin 2 y el del 3.
6. Batocera para la Odin 3 **solo** mapea `BTN_BACK → controlcenter`. No es un
   trabajo acabado; no lo tomes como referencia de "qué hotkeys hay que poner".

---

## 11. Aviso pendiente para Fransis

En la Odin sigue instalado un **test temporal de un subagente**:

```
/etc/udev/rules.d/60-input-id2-odin3-gamepad.rules
```

Añade `ENV{ID_INPUT_JOYSTICK}=1` al `AYN Odin3 Gamepad`. Su propio comentario
dice `remove with: sudo rm …`. Si quieres el comportamiento limpio de Batocera
(es decir, `ID_INPUT_JOYSTICK=1` **y** `ID_INPUT_MOUSE=0`, ver
`batocera/udev/99-ayn-odin3.rules`), lo correcto es borrar ese temporal y
copiar el de Batocera, no parchearlo.