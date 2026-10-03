# El mando de la AYN Odin 3 en RetroArch (autoconfig `udev`)

Fecha: 2026-10-03 · Console: `pocknix-1` (ODIN 3) · RetroArch 1.22.2 (Git 0558afa6)

## 1. El problema

RetroArch **ve** el joystick de la Odin pero no sabe qué botón es cuál, así que
no le aplica ningún perfil y el mando no hace nada:

```
[INFO] [udev] Pad #0 (/dev/input/event6) supports force feedback.
[INFO] [Autoconf] No se ha configurado AYN Odin3 Gamepad (8224/12289).
[INFO] [udev] Pad #1 (/dev/input/event11) supports force feedback.
[INFO] [Autoconf] Se ha configurado Microsoft X-Box 360 pad 0 en el puerto 2.
[INFO] [Input] Found joypad driver: "udev".
```

Es decir: el joystick **virtual** de InputPlumber (`Microsoft X-Box 360 pad 0`,
`/dev/input/event11`, el del escritorio) sí tiene autoconfig, y el **físico**
(`/dev/input/event6`) no. Con `input_player1_joypad_index = "0"` el jugador 1
coge el índice 0, que es el `Pad #0`, o sea **la Odin**: el problema no es de
"jugador 2", es que el mando del jugador 1 no tiene mapeo.

Ficheros implicados:

- perfil de RetroArch: `configs/retroarch/autoconfig/udev/AYN Odin3 Gamepad.cfg`
- en la consola:
  `/opt/deckstation/Apps/RetroArch/retroarch.AppImage.home/.config/retroarch/autoconfig/udev/AYN Odin3 Gamepad.cfg`

## 2. Los datos del dispositivo (medidos en la Odin)

```
/proc/bus/input/devices
I: Bus=0003 Vendor=2020 Product=3001 Version=0001
N: Name="AYN Odin3 Gamepad"
H: Handlers=js0 event6
B: EV=20000b            # EV_KEY(1) + EV_ABS(3) + EV_FF(0x15)
B: ABS=3f               # ABS_X..ABS_RZ: 6 ejes, sin hats
B: MODALIAS: input:b0003v2020p3001e0001
   k116,130,131,133,134,136,137,13A,13B,13C,13D,13E,220,221,222,223
```

- vendor `0x2020` = **8224**, product `0x3001` = **12289** (los números que
  prints RetroArch en el log).
- GUID de SDL: `0300bb95202000000130000001000000`. RetroArch **no** lo usa
  (el driver `udev` no va por SDL), pero se deja apuntado en el `.cfg`.
- 16 botones y 6 ejes; la cruceta son botones (`0x220..0x223` = `BTN_DPAD_*`),
  no hat.
- `phys = rsinput-gamepad/input0` → driver del kernel
  `drivers/input/joystick/rsinput.c` (el mismo para Odin 2 y 3).
- Rango de los ejes, leído con `EVIOCGABS` (`/sys/.../capabilities/abs` no da
  el detalle, y en este kernel `EVIOCGBIT` devuelve `EINVAL`):

| eje evdev | nombre | min | max | flat | valor en reposo | normalización de RetroArch en reposo |
|---|---|---|---|---|---|---|
| `ABS_X`  (0) | stick izq. X | -256 | 1024 | 0 | 0 | **-19660** |
| `ABS_Y`  (1) | stick izq. Y | -256 | 1024 | 0 | 0 | **-19660** |
| `ABS_Z`  (2) | **gatillo L2** | 0 | 1552 | 30 | 0 | -32767 (→ 0 con `neg_trigger`) |
| `ABS_RX` (3) | stick der. X | -256 | 1024 | 0 | 0 | **-19660** |
| `ABS_RY` (4) | stick der. Y | -256 | 1024 | 0 | 0 | **-19660** |
| `ABS_RZ` (5) | **gatillo R2** | 0 | 1552 | 30 | 0 | -32767 (→ 0 con `neg_trigger`) |

Que `ABS_Z`/`ABS_RZ` sean los gatillos sale de dos fuentes: el rango (0..1552 =
`0x610` = `trigger_left_max`/`trigger_right_max` del driver, `flat=30` de
`input_set_abs_params`) y el *capability map* de InputPlumber de ROCKNIX
(`ayn_mcu.yaml`: `ABS_Z -> LeftTrigger`, `ABS_RZ -> RightTrigger`).

## 3. Cómo numera RetroArch el driver `udev`

De `input/drivers_joypad/udev_joypad.c` (RetroArch 1.22.2, el mismo que usa la
consola):

**Botones.** No son índices "estándar": se asignan correlativamente a los
keycodes que declara el dispositivo, en este orden:

```c
for (i = KEY_UP; i <= KEY_DOWN; i++)        /* 103..108   */ ... buttons++
for (i = BTN_MISC; i < KEY_MAX; i++)         /* 0x100..0x2fe */ ... buttons++
for (i = 0; i < KEY_UP; i++)                /* 0..102     */ ... buttons++
for (i = KEY_DOWN + 1; i < BTN_MISC; i++)   /* 109..255   */ ... buttons++
```

Con los 16 keycodes del AYN sale (calculado con ese mismo algoritmo):

| índice | keycode | botón |
|---|---|---|
| 0 | `0x116` `BTN_TRIGGER_HAPPY1` | sin uso conocido |
| 1 | `0x130` `BTN_SOUTH` | **A** (círculo) |
| 2 | `0x131` `BTN_EAST` | **B** (cruz) |
| 3 | `0x133` `BTN_NORTH` | **Y** (triángulo) |
| 4 | `0x134` `BTN_WEST` | **X** (cuadrado) |
| 5 | `0x136` `BTN_TL` | L1 |
| 6 | `0x137` `BTN_TR` | R1 |
| 7 | `0x13A` `BTN_SELECT` | Select |
| 8 | `0x13B` `BTN_START` | Start |
| 9 | `0x13C` `BTN_MODE` | Guide / botón Odin / Home |
| 10 | `0x13D` `BTN_THUMBL` | L3 |
| 11 | `0x13E` `BTN_THUMBR` | R3 |
| 12 | `0x220` `BTN_DPAD_UP` | ▲ |
| 13 | `0x221` `BTN_DPAD_DOWN` | ▼ |
| 14 | `0x222` `BTN_DPAD_LEFT` | ◀ |
| 15 | `0x223` `BTN_DPAD_RIGHT` | ▶ |

**Ejes.** Correlativos por orden de código ABS, saltándose los hats (aquí no
hay ninguno, luego el driver ni los mira): `ABS_X`→0, `ABS_Y`→1, `ABS_Z`→2,
`ABS_RX`→3, `ABS_RY`→4, `ABS_RZ`→5.

**Signo.** RetroArch normaliza con
`axis = (value - min) * 65535 / (max - min) - 32767`. Los gatillos descansan en
0 con `min = 0`, o sea -32767 al soltar y +32767 al pulsar; el driver detecta
eso (`neg_trigger`) y aplica `val = (val + 0x7fff) / 2`, con lo que quedan en 0
sueltos y positivos pulsados → se mapean con `+`.

## 4. Por qué no se copió tal cual el `.cfg` de la Odin 2 de ROCKNIX

`_externos/rocknix/retroarch/gamepads/AYN_Odin2_Gamepad.cfg` mapea
`a=0,b=1,x=2,y=3` y `l2=+4, r_x=+2, r_y=+3, r2=+5`, es decir numeración **X-Box
360**:

- En ROCKNIX el RetroArch ve el **gamepad virtual** de InputPlumber (el
  `Microsoft X-Box 360 pad 0` de nuestra consola, `28de:11ff`), que ya viene con
  ese layout; el `.cfg` está escrito para el virtual, no para el joystick crudo.
- Además el layout que lleva ese fichero (`axis 2 = stick der. X`) no
  corresponde con ningún `ABS` de la Odin: en el joystick real el eje 2 es
  `ABS_Z` = el gatillo izquierdo (medido).

Del `.kl` de Armada (`Vendor_2020_Product_3001.kl`) **sí** se usa: es la fuente
de los keycodes de botón reales (304, 305, 307, 308, 310, 311, 314, 315, 316,
317, 318 y `DPAD_*`). Lo que **no** se copia de él es la suposición de que la
cruceta viene como hat: en el AYN es un botón más, y así lo declaran las tres
fuentes (`.kl` de Armada, quirk de Batocera, el perfil de InputPlumber).

## 5. El fichero

`configs/retroarch/autoconfig/udev/AYN Odin3 Gamepad.cfg` (idéntico al que se
instala en la consola). Contiene, comentado, de dónde sale cada número.
Resumen:

```
input_device = "AYN Odin3 Gamepad"   input_vendor_id = "8224"   input_product_id = "12289"
a=1  b=2  x=4  y=3  l=5  r=6  select=7  start=8  l3=10  r3=11
up=12  down=13  left=14  right=15        (botones, no hats)
l2=+2  r2=+5                              (ABS_Z / ABS_RZ)
stick izq: +0/-0 (X), +1/-1 (Y)   stick der: +3/-3 (X), +4/-4 (Y)
```

Hotkeys (mismo criterio que el `.cfg` de la Odin 2 de ROCKNIX: el botón
Odin/Home habilita los hotkeys):

| acción | botón |
|---|---|
| habilitar hotkeys | Guide / botón Odin (`9`) |
| salir del emulador | Start (`8`) |
| menú | X (`4`) |
| FPS | Y (`3`) |
| captura | A (`1`) |
| reset | B (`2`) |
| cargar estado | L1 (`5`) |
| guardar estado | R1 (`6`) |
| rebobinar | L2 (`+2`) |
|advance rápido | R2 (`+5`) |

## 6. Cómo se verifica

### 6.1 Que RetroArch carga el perfil

Lanzar un core por SSH (abre ventana en la consola; cerrar al terminar):

```sh
cd /opt/deckstation && DISPLAY=:1 XDG_RUNTIME_DIR=/run/user/1001 setsid \
  ./Apps/RetroArch/lanzar.sh -L \
  ./Apps/RetroArch/retroarch.AppImage.home/.config/retroarch/cores/<core>.so <rom>
```

Luego, en el log:

```sh
grep -E "Autoconf|joypad driver" \
  /opt/deckstation/Apps/RetroArch/retroarch.AppImage.home/.config/retroarch/logs/retroarch.log
```

Lo que tiene que aparecer:

- **Sí**: `[Autoconf] Se ha configurado AYN Odin3 Gamepad en el puerto N.`
  (desaparece el `No se ha configurado AYN Odin3 Gamepad (8224/12289)`).
- **No**: el log dice que se ha configurado pero el mando no hace nada → hay
  binds manuales en `retroarch.cfg` que pisan el autoconfig (en RetroArch el
  bind manual gana al autoconfig). Comprobar con:
  `grep -E "^input_player1_[abxy]_btn" .../retroarch.cfg`; si hay números, o
  se quitan (dejándolos vacíos) o se cambian por los del `.cfg`.

### 6.2 Que cada botón es el que se cree (esto lo hace Fransis)

Con un core que se vea bien (p. ej. el de Suyu, que ya se usó) y el menú de
RetroArch abierto:

1. **Guide** debe abrir/apagar los hotkeys; **Guide+X**, el menú.
2. Menú de RetroArch → *Controles* y comprobar que los nombres que salen
   (`A (círculo)`, `B (cruz)`, …) coinciden con lo que se ve al pulsar.
3. En el menú, probar la cruceta (▲▼◀▶), sticks, gatillos y que L1/R1
   ("cargar/guardar estado"), Start (salir) y el Guide se comporten.
4. Si **A y B están cambiados** (o X/Y): son estas 4 líneas del `.cfg`, y solo
   hay que permutarlas:

   ```cfg
   input_a_btn = "1"   # BTN_SOUTH  (0x130)
   input_b_btn = "2"   # BTN_EAST   (0x131)
   input_y_btn = "3"   # BTN_NORTH  (0x133)
   input_x_btn = "4"   # BTN_WEST   (0x134)
   ```

   Para A/B invertidas: `a=2`, `b=1`. Para X/Y invertidas: `x=3`, `y=4`.

### 6.3 Qué NO se ha podido verificar

- **Los botones no se han pulsado**: no hay forma de hacerlo por SSH. El
  A/B/X/Y está deducido (ver §2/§3 y los comentarios del `.cfg`), no medido.
- **Los sticks analógicos**: el centro sale desplazado, ver §7.
- **La instalación en la consola y el log con el perfil puesto**: la Odin se
  quedó inaccesible por Tailscale justo al empezar (se quedó `offline` y no
  volvió). Está pendiente: copiar el `.cfg` a
  `/opt/deckstation/Apps/RetroArch/retroarch.AppImage.home/.config/retroarch/autoconfig/udev/`
  (con copia del anterior si existiera) y lanzar un core para confirmar que
  desaparece el `No se ha configurado…`.

## 7. Lo que se ha encontrado de paso: el centro de los sticks

El driver del kernel declara los sticks de -256 a 1024 (`axis_leftx_min=-0x100`,
`axis_leftx_max=0x400` en `rsinput.c`), pero **el centro real es 0**. RetroArch
normaliza con `(value-min)*65535/(max-min)-32767`, así que en reposo:

```
(0 - (-256)) * 65535 / 1280 - 32767 = 13107 - 32767 = -19660
```

Es decir, un -0.6 fijo: el stick izquierdo se leería constantemente "izquierda"
y "arriba" para RetroArch, y el derecho igual. En la práctica el stick se
puede usar, pero con la mitad del recorrido muerta y el resto desplazado: no
cuenta como verificado, hace falta moverlo (ver §6.3).

Arreglo de futuro (no está en el kernel que corre ahora): el parche
`reference/sm8750-patches/1300-input-rsinput-ranges.patch` pone los sticks en
-1024..1024 con deadzone 70, que sí es simétrico respecto al 0. Con ese kernel
el centro normalizado sería 0. Está pendiente decidir si se aplica a
`kernel/patches/20-sm8750/`.

## 8. Ficheros

| qué | dónde (repo) |
|---|---|
| perfil | `packages/deckstation-arm/configs/retroarch/autoconfig/udev/AYN Odin3 Gamepad.cfg` |
| este doc | `docs/MANDO-ODIN3-RETROARCH.md` |
| plantilla (no copiada tal cual) | `packages/deckstation-arm/configs/_externos/rocknix/retroarch/gamepads/AYN_Odin2_Gamepad.cfg` |
| keycodes del kernel | `packages/deckstation-arm/configs/_externos/armada/input/Vendor_2020_Product_3001.kl` |
| capability map (confirma gatillos) | `packages/deckstation-arm/configs/_externos/rocknix/inputplumber-SM8750/ayn_mcu.yaml` |
| driver del joystick | `reference/sm8750-patches/0031_input--Add-driver-for-RSInput-Gamepad.patch` |
| rangos de los ejes | `reference/sm8750-patches/1300-input-rsinput-ranges.patch` (no aplicado) |

## 9. Instalar a mano (si hace falta)

```sh
scp 'AYN Odin3 Gamepad.cfg' \
  odin:'/opt/deckstation/Apps/RetroArch/retroarch.AppImage.home/.config/retroarch/autoconfig/udev/AYN Odin3 Gamepad.cfg'
```

Si ya hubiera un fichero con ese nombre, copiarlo antes a
`…/AYN Odin3 Gamepad.cfg.bak-$(date +%F)`.