# Investigación: distros ARM / proyectos handheld — ideas para Pocknix Odin 3

> Fecha: 07/09/2026. Barrido de ArmadaOS, ROCKNIX, mainline Qualcomm SM8750,
> hhd y decky-bcc. Cosas potencialmente útiles para seguir mejorando Pocknix
> en el Odin 3 (SM8750 / Adreno 830).

---

## 1. MangoHud con parches Qualcomm/SM8750 (¡RELEVANTE al problema actual!)

ROCKNIX y ArmadaOS aplican **parches a MangoHud** para que funcione bien en
Qualcomm. Nuestro `mangohud 0.8.3` (paquete genérico de Arch) NO los tiene.
Fuente: `ROCKNIX/distribution` → `projects/ROCKNIX/packages/apps/mangohud/patches/`
(también espejados en `armada-os/armada-packages/mangohud/patches/`).

Parches existentes:
- `0001-Qualcomm-GPU-support.patch` — soporte GPU Qualcomm (leer contadores de
  uso de la Adreno vía sysfs/debugfs del kernel).
- `0002-GPU-monitoring.patch` — (original de Armada) monitoreo de GPU.
- `0003-Battery-name.patch` — reconoce el nombre de batería Qualcomm.
- `0004-Qualcomm-battery-power_now.patch` — lectura de potencia instantánea de
  batería en Qualcomm.
- `0005-RAM-name.patch` — nombre de RAM.
- `0006-SM8750-Battery.patch` — batería específica SM8750 (¡nuestra plataforma!).

**Por qué importa**: aunque el overlay "no salga" es otro problema (integración
Steam/mangoapp), cuando funcione, sin estos parches las métricas de GPU/batería
de la Adreno 830 saldrán vacías o erróneas. Pendiente: recompilar mangohud con
estos parches o conseguir el paquete de ROCKNIX.

---

## 2. ArmadaOS — servicios y paquetes reutilizables

Repo: `armada-os/armada` + `armada-os/armada-packages`.

| Funcionalidad | Qué hace | Utilidad para nosotros |
|---|---|---|
| `armada-steamos-manager` (systemd service) | Implementa la API D-Bus `com.steampowered.SteamOSManager1` | **Muy interesante**: permite que la UI de Steam (Game Mode) controle suspensión, brillo, TDP como en una Steam Deck real. Sin esto, Steam no sabe "gestionar" el hardware. |
| `armada-powerd` (service) | Daemon D-Bus central de políticas de energía / TDP / fan | Referencia de arquitectura para centralizar nuestros power profiles / fan. |
| `armada-steamapps` (service) | Monta la carpeta de Steam como subvolumen **Btrfs nodatacow** | Evita fragmentación/desgaste en SD/UFS → mejora I/O y vida del almacenamiento. |
| `powerdevil` (con parches) | Mantiene la pantalla interna visible durante suspensión | Evita "pantalla negra" al despertar. |
| `networkmanager` (con parches) | Mantiene dispositivos activos durante suspensión | Que no se corten descargas de Steam al suspender. |

---

## 3. ROCKNIX — sistema de "quirks" por plataforma

Repo: `ROCKNIX/distribution` → `projects/ROCKNIX/packages/hardware/quirks/platforms/SM8750/`

Ya existe estructura SM8750 (¡la nuestra!) con scripts numerados que se aplican
en orden:
- `020-fan_control` — control dinámico de ventilador por temperatura.
- `002-turbo-mode_config` — perfiles de rendimiento/TDP.
- `005-thermal_path` — rutas de sensores térmicos del kernel.
- `030-suspend_mode` + `sleep.d/` — hooks pre-suspend / post-resume.
- `091-ui_shader`, `095-force_zink` — forzar Zink (GL sobre Vulkan).
- `090-ui_service` — watchdog que reinicia la UI si se cuelga.

**Acción sugerida**: auditar qué tenemos ya de esto en Pocknix y qué nos falta
(especialmente fan_control con thermal_path y el watchdog de UI).

---

## 4. Mainline / bring-up SM8750 (kernel y GPU)

La plataforma SM8750 está en fase de *bring-up* comunitario. Recursos:
- `renhiyama/pagani-linux` — kernel bring-up SM8750 (OnePlus 13s/13T): panel
  DSC 1.2, touchscreen, ath12k.
- `FixItFoundry/linux-glymur-a16` — kernel SM8750 (ASUS Zenbook A16): batería
  (soccp_glink), DT de pruebas.
- `p33k-a-b00/mesa-turnip-a830` — driver **Turnip (Vulkan Adreno) con GMEM**
  para Adreno 830. Referencia para optimizar el stack gráfico.

No hay soporte "llave en mano" en postmarketOS/Droidian para SM8750 aún.
Odin 3: sin soporte Linux público previo (OdinTools es solo Android/Odin 2).

---

## 5. hhd y decky-bcc — arquitectura y toggles

- **hhd** (`hhd-dev/hhd`): daemon modular Python (drivers por dispositivo).
  Lección: envolver control de hardware en API uniforme; para TDP en Qualcomm no
  hay estándar x86 — hay que exponer nodos propios vía driver.
- **decky-bcc** (decky plugin para handhelds ARM): TDP, fan curves, **MangoHud
  toggle**, **sleep mode**, OLED care.
  - MangoHud toggle: manipular `~/.config/MangoHud/MangoHud.conf` en caliente +
    recargar (o `MANGOHUD=1` en el entorno del juego).
  - Sleep mode: "fake suspend" integrado (pausar juego, apagar pantalla,
    silenciar audio) — mismo concepto que nuestro `pocknix-fake-suspend`.

---

## Resumen de acciones candidatas (a priorizar con Fransis)

1. **MangoHud**: (a) resolver por qué el overlay no responde al panel de Steam
   (integración mangoapp/gamescope), y (b) recompilar con los parches
   Qualcomm/SM8750 de ROCKNIX para métricas reales de Adreno 830 y batería.
2. **`armada-steamos-manager`**: implementar la API `SteamOSManager1` para que
   Steam controle hardware (brillo/TDP/suspensión) desde su UI.
3. **Btrfs nodatacow** para la carpeta de Steam (tipo `armada-steamapps`).
4. **Auditar quirks SM8750 de ROCKNIX** (fan control + thermal + watchdog UI)
   contra lo que ya tenemos en Pocknix.
5. Estar atentos a `pagani-linux` / `mesa-turnip-a830` para mejoras de kernel y
   Vulkan en el futuro.
