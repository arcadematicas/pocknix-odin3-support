# Actualizar la Odin 3 y ponerse al día — Davidusky y Jarvis (23/10/2026)

Guía **autocontenida**: no hace falta tener clonado ningún repositorio para actualizar. Si además
queréis compilar o tocar el sistema, los repos están al final.

> Sustituye a [`ACTUALIZAR-ODIN-DAVIDUSKY-2026-10-09.md`](ACTUALIZAR-ODIN-DAVIDUSKY-2026-10-09.md).
> La advertencia de "no actualizar" sigue **levantada**: el repo propio está firmado y verificado.

---

## 0. Qué es qué (para situarse)

| Cosa | Dónde |
|---|---|
| Repo pacman propio (firmado) | `https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev` → `/sm8750`, `/shared`, `/base` |
| Clave del repo | `85C433EE12621EED` (`pocknix-repo@arcadematicas`) · pública: `…/sm8750/pocknix-repo.gpg` |
| Sistema (árbol de compilación) | `github.com/arcadematicas/pocknix-os` rama **`odin3-sm8750`** |
| Centro (fuente de verdad de lo nuestro) | `github.com/arcadematicas/pocknix-odin3-support` |
| Informes de diagnóstico | `github.com/arcadematicas/calvOS-reports` (issues) |
| Documentación | `pocknix-odin3-support/docs/` (empieza por `INSTALACION-INTERNA-20261023.md` y `UPSTREAM-BACKLOG.md`) |

**Regla de oro del proyecto**: se edita en el **centro** y se regenera el árbol con
`tools/sync-to-os.sh`. Editar en `pocknix-os` y no en el centro se pierde en el siguiente sync.

---

## 1. Requisitos y acceso

- Odin 3 con nuestra imagen (Pocknix/CalvOS).
- WiFi con internet.
- Terminal: **SSH** `ssh deck@<IP>` (contraseña por defecto `pocknix`) o en la consola con
  **Ctrl+Alt+F2**. `sudo` pide la misma contraseña.

---

## 2. PASO 0 — Copia de seguridad (siempre)

```bash
sudo cp -a /flash/KERNEL      /flash/KERNEL.bak-$(date +%Y%m%d)
sudo cp -a /flash/KERNEL.md5  /flash/KERNEL.md5.bak-$(date +%Y%m%d)
sudo pocknix-snapshots 2>/dev/null || true      # snapshot btrfs (rollback)
```

---

## 3. PASO 1 — Apuntar al repo propio (solo si no lo está)

Comprobad primero:

```bash
grep -A3 '\[pocknix\]' /etc/pacman.conf
```

Si no sale, o sale `pocknix.shuuri.net` (que da 404 para sm8750), reemplazad el fichero:

```bash
sudo cp -a /etc/pacman.conf /etc/pacman.conf.bak-$(date +%Y%m%d-%H%M%S)
sudo tee /etc/pacman.conf >/dev/null <<'CONF'
[options]
Architecture = aarch64
HoldPkg     = pacman glibc
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional
ParallelDownloads = 5

[pocknix]
SigLevel = Required DatabaseOptional
Server = https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev/sm8750

[pocknix-shared]
SigLevel = Required DatabaseOptional
Server = https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev/shared

[pocknix-base]
SigLevel = Required DatabaseOptional
Server = https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev/base

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[alarm]
Include = /etc/pacman.d/mirrorlist
CONF
```

> **NO hay `[aur]`** (era el veneno: ofrecía paquetes que bajaban versiones). `[core]/[extra]/[alarm]`
> quedan solo de comodín; lo instalado se resuelve por `[pocknix-base]` (ALARM **pinneada**, no la viva).

## 4. PASO 2 — Clave del repo

```bash
curl -fsSL https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev/sm8750/pocknix-repo.gpg -o /tmp/pocknix-repo.gpg
sudo pacman-key --add /tmp/pocknix-repo.gpg
sudo pacman-key --lsign-key 85C433EE12621EED
```

## 5. PASO 3 — Refrescar y **verificar antes de actualizar**

```bash
sudo pacman -Syy
# Debe bajar pocknix, pocknix-shared, pocknix-base (+ core/extra/alarm).
# NO debe aparecer "signature invalid" ni errores.

sudo pacman -Sp --print-format '%n %v %r' mesa gamescope linux-pocknix-sm8750
# Los tres deben salir del repo "pocknix", NO de "extra".
```

## 6. PASO 4 — Actualizar

```bash
sudo pocknix-update
```

Si no existe, la alternativa manual (política de `--overwrite` **acotada**, nunca `'*'`):

```bash
sudo pacman -Syu \
  --overwrite '/usr/lib/libplutovg.so*'        --overwrite '/usr/lib/libplutosvg.so*' \
  --overwrite '/usr/lib/libFLAC.so.8*'         --overwrite '/usr/lib/libpcap.so.0.8*' \
  --overwrite '/usr/lib/libdisplay-info.so.1*' --overwrite '/usr/share/pocknix/vk-arm/*'
```

## 7. PASO 5 — Reiniciar y verificar

```bash
sudo systemctl reboot
```

Cuando vuelva:

```bash
uname -r                                  # 7.2.12
pacman -Q linux-pocknix-sm8750            # 7.2.12-16
pacman -Q pocknix-bsp-sm8750              # 0.2.0-32
pacman -Q pocknix-decky                   # 0.1.0-56
sudo systemctl --failed                   # 0 unidades fallidas
systemctl is-active pocknix-audio-jack steamui-watchdog power-button-daemon systemd-oomd
ip -br addr show | grep wlan              # WiFi UP
```

**Criterio de éxito**: kernel **7.2.12-16**, `pacman -Qu` ≈ vacío, 0 unidades fallidas, los cuatro
servicios `active`.

---

## 8. Qué trae esta actualización (desde el 9/10)

- **Suspend**: 0,37 W → **0,24–0,26 W** (parches `0044`/`0521` fuera, `0512` dentro, hooks de
  InputPlumber y WiFi).
- **Kernel 7.2.11-8 → 7.2.12-16**: `1030` (swr2), `1031` (relojes PM del tx-macro), `1032` (PLL del
  DSI, de armada), `1033-TEST` (60 Hz primero, ver avisos) y **`2109`** (volumen real de los
  auriculares en el WCD939x).
- **Audio**:
  - El EQ del panel ya no clava el destino en los auriculares (seguía al sink por defecto).
  - **`pocknix-audio-jack`**: reengancha el audio al conmutar el jack y apaga la **compander** de los
    auriculares (DAPM la reactivaba → chisporroteo). Conmutación medida: **17–29 ms**.
  - El **altavoz** son dos amps **AW88166**: su `SPK_L/R PCM Playback Volume` es **atenuación**
    (0 = máximo). El fallo de "no vuelve el sonido al altavoz" era de **ruta** (HPH/RDAC/CLSH
    encendidos), no de volumen.
- **QAM**: `steamui-watchdog` ya **no cuenta fallos ni reinicia la UI mientras hay un juego** (eso era
  el "se traba el QAM" al jugar). Healthcheck 5 → 8 s.
- **Botón de encendido**: `power-button-daemon.py` podía **faltar en disco** (el paquete lo lista) →
  servicio en bucle y botón muerto. Si os pasa: `sudo pacman -S pocknix-system-overlay`.
- **`systemd-oomd`** activo con umbrales altos (95 % swap / 70 % de presión 45 s): en el caso
  patológico mata el proceso más pesado en vez de dejar el sistema arrastrándose.
- **`calvos-doctor`** (`/usr/local/bin/calvos-doctor`): informe redactado en local y, si se quiere,
  envío al colector propio (`calvos-reports`). Sin token en la imagen.
- **Instalación en la flash interna** con los juegos en la SD: ver
  [`INSTALACION-INTERNA-20261023.md`](INSTALACION-INTERNA-20261023.md).

---

## 9. Avisos que os pueden morder

1. **`1033-TEST`: el panel arranca a 60 Hz.** Es un parche de prueba (60 Hz como modo preferido), no
   la conmutación en caliente (esa sigue bloqueada: el panel no se re-inicializa tras un `disable`).
   Si queréis volver a 120 Hz estables: `sudo pacman -S linux-pocknix-sm8750=7.2.11-13` (sigue en R2).
2. **Micrófono**: **no funciona** y no es configuración — el FE pide `graph_id=2` y ese grafo no existe
   en la tplg (ni AYN ni Kaanapali). Está reportado en `armada-os/armada#766`.
3. **Juegos x86 pesados (UE5 bajo FEX)**: con 11 GB de RAM se llega a **fallos de asignación**
   (`page allocation failure: order:0`) y el sistema se arrastra. `oomd` ahora lo corta, pero no es
   jugable: para AAA, streaming (Moonlight) o el modelo de 16 GB.
4. **No abráis el QAM con esos juegos** ni dejéis el plugin de ambilight capturando: suma memoria y
   GPU justo cuando no hay.
5. **`--overwrite '*'` jamás.** Solo rutas concretas.

---

## 10. Si queréis instalar el sistema en la flash interna

El instalador clona **todo** el root de la SD. Si tenéis juegos ahí, no cabe (en la Odin de Fransis:
419 GiB usados vs 196 GiB útiles). Con el parche del centro:

```bash
# copiar el instalador parcheado (soporta --exclude)
curl -fsSL https://raw.githubusercontent.com/arcadematicas/pocknix-odin3-support/master/packages/pocknix-tools/pocknix-install-internal \
  -o /tmp/ii && sudo install -Dm755 /tmp/ii /usr/bin/pocknix-install-internal

sudo pocknix-install-internal --detect --exclude /opt            # sonda: debe salir mode=fresh
sudo pocknix-install-internal --dry-run --exclude /opt --userdata-gib 1
sudo pocknix-install-internal --yes    --exclude /opt --userdata-gib 1
```

Después: apagar, quitar la SD, encender. Los juegos se quedan en la SD y se montan en `/opt`
(ver el doc de instalación interna, incluido el **renombrado de la SD** y la lección del **ABL**:
elige el origen de arranque en su menú, y **sin `KERNEL` en la SD no arranca nada**).

Revertir: `sudo pocknix-uninstall-internal` desde la SD.

---

## 11. Si algo va mal

| Síntoma | Qué hacer |
|---|---|
| Kernel no arranca | `sudo cp -a /flash/KERNEL.bak-<fecha> /flash/KERNEL` + regenerar `KERNEL.md5` (el ABL valida el md5) |
| Sistema roto tras actualizar | `sudo pocknix-rollback` (snapshot btrfs) o el menú de arranque |
| `signature invalid` | Reimportar la clave (PASO 2) y `pacman-key --lsign-key 85C433EE12621EED` |
| Botón de encendido muerto | `sudo pacman -S pocknix-system-overlay` y `sudo systemctl restart power-button-daemon` |
| Audio raro / sin altavoz | `systemctl status pocknix-audio-jack`, `journalctl -u pocknix-audio-jack -n 20` |
| "Se traba el QAM" jugando | `journalctl -t steamui-watchdog`; comprobar que el watchdog es el nuevo (grep `game_running`) |

---

## 12. Notas para Jarvis (la IA)

1. **Nunca `pacman -Sy` solo**: actualización parcial = sistema roto. Siempre `-Syu` o `pocknix-update`.
2. **Verificación dura** antes de decir "actualizado": (a) `pacman -Syy` sin `signature invalid`;
   (b) `pacman -Sp mesa gamescope linux-pocknix-sm8750` con `%r` = `pocknix`; (c) tras reiniciar,
   `uname -r` = **7.2.12** y `pacman -Q linux-pocknix-sm8750` = **7.2.12-16**; (d) `systemctl --failed`
   vacío; (e) los servicios `pocknix-audio-jack`, `steamui-watchdog`, `power-button-daemon`,
   `systemd-oomd` en `active`.
3. **Datos del usuario que NUNCA se tocan**: `/home/deck`, `/opt` (ROMs, juegos, saves, BIOS).
   `/opt` puede estar montado desde otra unidad: comprobar con `findmnt /opt` antes de asumir nada.
4. **Distinguir "no suena" de "no hay volumen"**: los amps del altavoz (AW88166) usan **atenuación**
   (0 = máximo). Si alguien "arregla" el sonido poniéndolos a 950, lo está **silenciando**.
5. **Antes de tocar el arranque**: `stat -c %y /flash/KERNEL`, `ls /flash | head`, y saber que el ABL
   arranca del FAT con `KERNEL`; dejar siempre un `KERNEL.bak`.
6. **Si compiláis**: editar en el **centro** y `tools/sync-to-os.sh`; `tools/check-sync.sh` aborta el
   build si el árbol no coincide. El kernel se fija en `kernel/sm8750/kernel.conf` (7.2.12) y su
   `pkgrel` en `packages/linux-pocknix-sm8750/PKGBUILD` (16).
7. **Informes**: `calvos-doctor` (local, redactado) o `calvos-doctor --send` (colector propio →
   issues en `calvOS-reports`). No inventar issues en repos ajenos: el del micrófono es
   `armada-os/armada#766`.

---

## 13. Estado de referencia (23/10/2026, Odin 3 de Fransis)

```
kernel 7.2.12-16 · bsp 0.2.0-32 · decky 0.1.0-56 · gamescope 1:3.16.31.ogc1…-3
sistema en la UFS interna (POCKNIX_ROOT) · /opt montado desde la SD (POCKNIX_SD)
suspensión 0,24-0,26 W · audio auriculares/altavoz OK · QAM estable jugando
pendiente: micrófono (armada#766) y conmutación de refresco 60/120 en caliente
```
