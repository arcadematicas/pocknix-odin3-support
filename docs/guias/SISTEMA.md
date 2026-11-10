# Sistema — funciones especiales de CalvOS

Guía rápida de lo que hace distinto a CalvOS: energía, HDR, snapshots,
actualizaciones, captura, diagnóstico y mando. Para el detalle técnico, cada
apartado enlaza a su documento.

## Modo juego ↔ escritorio

- **Modo juego**: Steam en gamescope (la experiencia de consola).
- **Escritorio**: KDE Plasma 6 (Wayland + Plasma Mobile).
- Cambio:
  ```sh
  steamos-session-select gamescope   # volver al modo juego
  steamos-session-select plasma      # escritorio
  ```
  También desde el **QAM** de Steam (energía → cambiar a escritorio).

## Energía y TDP — Panel de Control

- El plugin **Panel de Control** (Decky/QAM) gestiona **TDP**, **boost**, curvas de
  ventilador y la frecuencia de pantalla.
- Perfiles del sistema por terminal (si el panel no lleva el control):
  ```sh
  pocknix-power-profile bajo | medio | alto     # get | set
  ```
- ⚠️ **Mientras el Panel de Control tenga el TDP activo, manda él**: los perfiles
  `bajo/medio/alto` no pisan sus topes. En la sesión del 08/11 el TDP estaba en
  **4 W** (CPU ~2,0/2,4 GHz, GPU 660 MHz); subirlo da margen, sobre todo a los
  ports x86_64, a costa de calor y batería.
- El **modo juego** y el **escritorio** pueden usar perfiles distintos; el panel
  los recuerda.

## HDR

- **Apagado por defecto** (así el QAM y MangoHUD no se van detrás).
- Se activa en el **Panel de Control** (gestiona el HDR de gamescope). El cliente
  Steam ARM64 no siempre muestra el toggle en el QAM; si un juego pide HDR, lo
  detecta igualmente.
- Detalle: `../HDR-OFF-POR-DEFECTO-2026-10-11.md` y `../PRUEBAS-MESA.md`.

## Snapshots y rollback

- CalvOS guarda **snapshots automáticos** antes de actualizar (paquetes/kernel).
- Listar y volver a uno:
  ```sh
  sudo pocknix-rollback --list
  sudo pocknix-rollback --to <id> --yes
  ```
- También desde **CalvOS Tools** (menú de snapshots) y desde **CalvOS Control**
  (pestaña de updates/snapshots).
- Rollback del kernel: `pocknix-kernel-guard` + `/flash/KERNEL.bak*` (ver
  `../RED-SEGURIDAD-KERNEL-20261026.md`).

## Actualizaciones

- Usa el **actualizador del QAM / CalvOS** (CalvOS Control → Updates). La base va
  sobre un snapshot congelado: **no hagas `pacman -Syu` a lo bruto** (sube ~260
  paquetes y puede romper la sesión). Para instalar algo suelto:
  ```sh
  sudo pacman -Sy --needed <paquete>
  ```
- El kernel entra **solo por paquete** (`linux-pocknix-sm8750`); nunca copies
  `KERNEL` ni módulos a mano.

## Diagnóstico — `calvos-doctor`

```sh
calvos-doctor                                   # recoge y guarda (NO envía)
calvos-doctor --text "no hay audio al enchufar" # añade contexto
calvos-doctor --send --text "..."               # revisa, confirma y envía
```

Recoge modelo, kernel, versiones, panel, audio, batería, unidades fallidas y logs;
**redacta datos personales** y solo envía si se lo pides. Genera
`~/calvos-report-<fecha>.tar.gz` y un QR con el issue.

## Grabar vídeo y capturadora

```sh
calvos-grabar 60                # 60 s de TODO (juego + QAM), 1080p60, audio del juego
calvos-grabar 60 --x11          # solo la ventana del juego (sin QAM)
calvos-grabar 60 --fps 30 --bitrate 12M --out ~/Videos
dock-check                      # ¿detecta la capturadora HDMI/DP? ¿hay audio?
```

- `calvos-grabar` usa el **encoder H.264 por hardware**; `kms` necesita root,
  `--x11` no.
- El audio por HDMI/DP **no existe** en la Odin: para vídeo con sonido, usa el jack
  3,5 mm. Detalle en `../GRABAR-VIDEO.md`.

## Mando y atajos

- El mando real lo gestiona **InputPlumber**; los juegos ven el mando virtual de
  Steam.
- Atajos de RetroArch/ES-DE y mapeo verificado:
  [`../MANDO-ODIN3-RETROARCH.md`](../MANDO-ODIN3-RETROARCH.md).
- En WProton, el mando se configura dentro del menú (y con el ajuste de Steam
  Input/superposición del script).

## Suspensión

- Botón de encendido → **s2idle real** (~0,37 W). Con un juego abierto también
  funciona tras el kernel 7.2.15.
- Si al despertar la pantalla queda negra: hook `004-display` (ya instalado); si
  pasa, `../SUSPEND-ISSUE.md`.

## Ventilador

- La curva la lleva `pocknix-fancontrol` (quiet por defecto); se cambia al vuelo:
  `pocknix-fan-mode quiet|moderate|performance|off`.
- **Suelo mientras carga**: `pocknix-fan-mode charging 60` mantiene el ventilador
  al menos a esa velocidad (0-255) mientras la batería dice que carga, también
  **dormida** (el kernel lo sostiene en s2idle). `pocknix-fan-mode charging`
  sin número dice el valor actual; `0` lo desactiva (por defecto).
- Volume Up **ya no despierta** la consola: solo el botón de encendido. Era la
  causa de encendidos accidentales en la mochila (kernel 7.2.15, 10/11/2026).

## Almacenamiento y red

- La **SD** se monta en `/opt` (juegos, DeckStation, WProton, ROMs). La **UFS
  interna** tiene `/home`.
- La consola se anuncia por **mDNS** como `pocknix.local` (`calvos-mdns-alias`).
- Carpetas compartidas/SSH: según tu configuración (`/home/deck/Recibidos` y
  `sshd`), no vienen activadas por defecto.

## Comandos de salud rápida

```sh
uname -r                 # kernel (7.2.x)
systemctl --failed       # debe estar vacío
free -m                  # RAM
df -h /opt /home         # espacio
vulkaninfo --summary | head   # GPU/Turnip
```
