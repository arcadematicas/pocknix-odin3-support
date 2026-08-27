# IDEAS — Cosas a implementar / probar en Pocknix Odin 3

> Cuaderno de ideas para el proyecto. Cada entrada anota una fuente externa
> (repo/distro), qué hace, qué nos puede aportar y cómo aplicarlo.
> Cuando una idea madure, se mueve a una tarea concreta en el repo.

Formato de estado:
- 🟢 **Lista para probar** — se puede implementar ya
- 🟡 **Requiere investigación** — hay que estudiar cómo adaptarlo
- 🔴 **Descartada / en espera** — no aplica por ahora

---

## 1. Decky Loader / Batocera Control (`darkplace/decky-bcc`)

**Fuente:** https://github.com/darkplace/decky-bcc
**Qué es:** Plugin de Decky Loader para Batocera en handhelds ARM/x86 (incluye
Odin 3). Derivado de Armada Control (armada-os). GPL-2.0.

| Idea | Qué hace | Estado |
|---|---|---|
| **Rear paddles M1/M2 vía sysfs** | Descubre los paddles traseros del Odin 3 desde las capacidades del gamepad AYN `rsinput` (sin tocar GPIO). Usa python-evdev, observa sin "grabar", reconecta tras resume. Coexiste con Steam/ES/emuladores. | 🟡 Investigar — nosotros usamos InputPlumber; el descubrimiento por sysfs es portable |
| **Power profiles (eco/balanced/performance)** | CPU governor + `qcom-fan` (Silent/Auto/Aggressive/Manual/Off). Editable por perfil. | 🟢 Aplicable directamente — el Odin 3 tiene `qcom-fan` |
| **Fan curve editor** | Edita curvas de ventilador en `/userdata/system/configs/qcom-fan-curves.conf` (portado de Armada PR #260 por Xtreme976). | 🟢 Aplicable — mismo daemon `qcom-fan` |
| **OLED care / pixel refresher** | En paneles OLED detectados, ejecuta el refrescador de píxeles tras timeout de inactividad en Steam GamepadUI. Claves `display.oledcare*`. | 🟢 Muy útil — el Odin 3 tiene panel AMOLED |
| **Sleep mode (s2idle/deep)** | Selecciona modo de suspensión cuando el kernel anuncia más de una opción en `/sys/power/mem_sleep`. | 🟡 Nosotros lo deshabilitamos; útil para el futuro |
| **MangoHud toggle** | `mangohudctl toggle no_display` para mostrar/ocultar overlay sin cambiar el preset del QAM. | 🟢 Ya usamos MangoHud en gamescope |
| **LSFG (Lossless Scaling)** | Integra LSFG-VK para Steam (requiere DLL comercial). | 🔴 Requiere DLL de pago — en espera |
| **Emulation settings por juego** | Expone emulador/core/opciones `es_features.cfg` por ROM (Batocera). | 🟡 Solo Batocera — adaptar si hacemos capa de emulación |

**Nota:** El repo también referencia `batocera.pocket` (imágenes Batocera para
handhelds) y los drivers `qcom-fan`, `batocera-brightness`, `batocera-cpu-limit`.

---

## 2. Handheld Daemon (`hhd-dev/hhd`)

**Fuente:** https://github.com/hhd-dev/hhd (+ `hhd-ui`, `hhd-decky`)
**Qué es:** "Handheld Daemon" — reemplazo de la interfaz del vendor (equivalente
a Armoury Crate) para handhelds en Linux. Overlay de gamescope + app de
escritorio. LGPL-2.1. Soporta Ayn Loki (x86) — el Odin 3 (ARM) aún no.

| Idea | Qué hace | Estado |
|---|---|---|
| **Control de TDP** | Ajuste de TDP por perfil, integrado con el hardware. | 🟡 Investigar — el Odin 3 es ARM (SM8750); hhd está orientado a x86 pero los conceptos aplican |
| **Fan curves** | Curvas de ventilador configurables. | 🟢 Concepto aplicable (ya lo tenemos en qcom-fan) |
| **Gyro / emulación de controlador** | Emula controlador con giroscopio, botones traseros, atajos SteamOS. | 🟡 El Odin 3 tiene IMU (sensors); ver si hhd puede usar los IIO devices |
| **RGB remapping** | Remapeo de LEDs/RGB. | 🔴 El Odin 3 no tiene RGB destacable — en espera |
| **Overlay gamescope** | Overlay accesible con doble toque del botón lateral. | 🟢 Concepto interesante para nuestro QAM |
| **Drivers kernel** | Usa `ayn-platform` (ShadowBlip), `oxp-sensors`, `bmi260`, `gpdfan`. | 🟡 Revisar `ayn-platform` para el Odin 3 |

**Nota:** hhd recomienda la distro **Anatase** (anatase-org/anatase) que lleva la
versión más probada. Tiene integración con Decky (`hhd-decky`) y Bazzite
(`hhd-bazzite`).

---

## 3. Armada (`armada-os/armada`)

**Fuente:** https://github.com/armada-os/armada (+ `armada-packages`, `armadaos.dev`)
**Qué es:** Distro SteamOS-like para handhelds ARM64. Basada en **Fedora bootc**,
soporte de dispositivos derivado de **ROCKNIX**. GPL-2.0. Steam + FEX + Proton +
KDE Plasma. Es la base de la que salió Armada Control (→ decky-bcc).

| Idea | Qué hace | Estado |
|---|---|---|
| **Controles handheld integrados** | Power, fan, controller y calibración específicos de handheld. | 🟢 Referencia para nuestro panel de control |
| **Per-game compatibility settings** | Ajustes de compatibilidad por juego (Armada Control). | 🟢 Concepto a replicar en Pocknix |
| **OTA updates (bootc)** | Sistema de actualizaciones por imagen (Fedora bootc). | 🟡 Pocknix usa pacman; bootc es otra filosofía — estudiar |
| **Gaming Mode + Desktop Mode** | Doble sesión Steam/Plasma (como SteamOS). | 🟢 Ya lo tenemos en Pocknix (gamescope + Plasma) |
| **SD boot + instalación interna** | Arranque por SD con opción de instalar en almacenamiento interno. | 🟢 Ya lo tenemos (imagen SD + install.sh) |

---

## 4. ROCKNIX (`ROCKNIX/distribution`)

**Fuente:** https://github.com/ROCKNIX/distribution (+ repos de la org)
**Qué es:** La base de pocknix (kernel, ABL, firmware). Ya la usamos, pero hay
repos de la org con ideas:

| Idea | Qué hace | Estado |
|---|---|---|
| **rocknix-joypad** | Mapeo de gamepads específico de ROCKNIX. | 🟡 Comparar con nuestro InputPlumber |
| **ImageBurner** | Herramienta para grabar imágenes en SD/USB. | 🟢 Útil para que los compañeros flasheen la imagen |
| **abl** | Bootloader ABL customizado. | 🟡 Ya usamos el ABL de ROCKNIX en la imagen |
| **distribution-nightly** | Builds nocturnos. | 🟡 Referencia de CI/CD |

---

## 5. Otras ideas pendientes (del proyecto)

| Idea | Estado |
|---|---|
| **Sensores IIO** — verificar en dispositivo que aparecen (`ls /sys/bus/iio/devices/`) | 🟢 Probar en el próximo boot |
| **KScreen no enumera el panel** en Plasma Mobile (issue abierto) | 🟡 Investigar fix upstream |
| **Pantalla negra** — hard power cycle pendiente (hardware) | 🔴 Bloqueado por hardware |
| **hhd / gyro** — usar la IMU del Odin 3 (sensors pakala) para giroscopio en juegos | 🟡 Investigar |

---

## Cómo añadir una idea

1. Añade una entrada con: **fuente** (URL), **qué hace**, **qué nos aporta**,
   **cómo aplicarlo**, **estado** (🟢/🟡/🔴).
2. Si la idea madura, créala como issue en este repo o como tarea.
3. Cuando se implemente, muévela a la sección "Implementado" (o bórrala).