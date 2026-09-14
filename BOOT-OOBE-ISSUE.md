# Arranque lento + Asistente OOBE de Steam — RESUELTO (14/09/2026)

**Estado: la Odin 3 arranca en ~20 s, llega a `graphical.target` en ~9.5 s de
userspace, y el asistente inicial de Steam (idioma/zona/WiFi) aparece y funciona
sin reiniciar la consola.**

Rama `odin3-pr` de `arcadematicas/pocknix-os`. Imagen limpia de Pocknix, SM8750,
kernel 7.2.0.

---

## A) Arranque lentísimo + pantalla negra — RESUELTO (commit `e574b2a`)

### 1. Síntoma

- El arranque tardaba **minutos**.
- La sesión de Steam no aparecía: pantalla negra con backlight encendido; tras
  mucho rato quedaba en "starting".
- `systemctl is-system-running` mostraba **`starting`** (nunca llegaba a `running`).

### 2. Causa raíz

**Dos problemas independientes** se combinaban:

#### Causa 1: `pocknix-diag.service` bloqueaba `multi-user.target`

El servicio de diagnóstico tenía:

```ini
[Install]
WantedBy=multi-user.target

[Unit]
After=multi-user.target
Wants=multi-user.target

[Service]
ExecStartPre=/bin/sh -c 'sleep 30'
```

Esto mantenía `multi-user.target` en estado `activating` hasta que terminaba el
dump (30 s de sleep + tiempo de ejecución), retrasando el arranque y el lanzamiento
de la sesión gráfica.

#### Causa 2 (race condition): gamescope arrancaba antes del panel DSI

gamescope podía iniciarse antes de que el panel DSI estuviera listo y se quedaba
con DRM en negro **sin salir**. El retry de <5 s en el supervisor `~/.bash_profile`
nunca se disparaba; matar gamescope y relanzarlo arreglaba la sesión manualmente.

### 3. El fix

| Fichero | Cambio |
|---|---|
| `overlay/etc/systemd/system/pocknix-diag.timer` | **Nuevo**: `OnBootSec=45s`, `WantedBy=timers.target` — ejecuta el diagnóstico como timer, no como servicio de arranque |
| `overlay/etc/systemd/system/pocknix-diag.service` | Pierde `[Install]`, `After` y `Wants=multi-user.target`. Ya no bloquea el boot |
| `scripts/build-sd-image.sh` | Habilita el **timer** (`pocknix-diag.timer`), no el servicio |
| `packages/shared/pocknix-steam/pocknix-steam` | **Gate de readiness DRM**: espera (máx 30 s) a que el conector DSI (`/sys/class/drm/card*-DSI-*/status`, o variable `POCKNIX_PANEL_OUTPUT`) reporte `connected` antes de lanzar gamescope. No-op en boot normal (el panel ya está listo) |

### 4. Verificación

```
$ systemd-analyze
Startup finished in 11.214s (kernel) + 9.518s (userspace) = 20.732s

$ systemd-analyze critical-chain
graphical.target @4.129s
└─pocknix-steam.service @2.987s +1.132s
  └─network-online.target @2.836s

$ systemctl is-system-running
running
```

Antes del fix:
- `systemctl is-system-running` = **`starting`** (minutos).
- `graphical.target` nunca se alcanzaba de forma fiable.

Después del fix:
- **`running`** a los 20 s.
- `graphical.target` a los 9.5 s de userspace.

---

## B) Asistente inicial de Steam (OOBE) — RESUELTO (commits `b88018d` + `d13f65d`)

### 1. Síntoma

En una imagen limpia de Pocknix el cliente Steam **no mostraba el asistente
inicial** (selección de idioma, zona horaria, WiFi) e iba directo al login.

### 2. Causa raíz (parte 1: ausencia del marker)

En SteamOS el cliente Steam detecta la presencia de `/etc/steamos-oobe-image` y,
si existe, lanza la OOBE. Verificado con `strings` del binario `steam`:

```
$ strings /usr/lib/steam/ubuntu12_32/steam | grep oobe
/etc/steamos-oobe-image
```

En nuestra imagen no existía ese fichero → el cliente saltaba la OOBE.

### 3. Fix 1: marker de OOBE (commit `b88018d`)

El paquete `pocknix-steamos-shim` ahora instala `/etc/steamos-oobe-image`
(contenido: `pocknix`). Con eso la OOBE aparece.

### 4. Causa raíz (parte 2: bucle de reinicio durante la OOBE)

**Bug importante**: durante la OOBE el cliente Steam llama **siempre** a
`steamos-update` con el subcomando `apply` (no solo `check`). Nuestro shim
`steamos-update` devolvía **0** en ese caso, y el cliente lo interpretaba como
"se aplicó una actualización":

```
YieldingApplyUpdateOS: applying OS update
steamos-update returned: 0
YieldingApplyUpdateOS: OS update result: 1
CSystemManagerApplyUpdateJob: system restart required
```

Resultado: **la consola se reiniciaba** justo tras elegir idioma/WiFi → bucle
infinito de OOBE → reinicio → OOBE → reinicio.

### 5. Fix 2: `apply` devuelve exit 7 (commit `d13f65d`)

Contrato de exit codes de Valve (script real `jupiter-legacy-support` /
`usr/bin/steamos-update`, renombrado `holo-update` en SteamOS 3.9):

| Exit code | Significado |
|---|---|
| 0 | Update disponible / aplicado → **requiere reinicio** |
| 1 | Error |
| 7 | No hay actualización disponible |
| 8 | Ya aplicado, reinicia (**SOLO** con `--enable-duplicate-detection check`) |

Fix: `apply` (y cualquier invocación sin `check`) ahora devuelve **7** ("No
update available"), igual que el script real de Valve.

Shims afectados (instalados en `/usr/bin/` **Y** `/usr/bin/steamos-polkit-helpers/`):
- `steamos-update`
- `steamos-mandatory-update` (invención nuestra, no existe en SteamOS; el OOBE lo
  usa como gate de check)

`jupiter-initial-firmware-update` ya era no-op (exit 0). pkgrel 8 → 9.

### 6. Verificación

```bash
# En el rootfs de la SD:
$ /usr/bin/steamos-update --supports-duplicate-detection
0

$ /usr/bin/steamos-update check
7

$ /usr/bin/steamos-update --enable-duplicate-detection check
7

$ /usr/bin/steamos-update          # sin args (= apply)
7

$ /usr/bin/steamos-update apply
7

$ /usr/bin/steamos-mandatory-update check
7

$ /usr/bin/steamos-mandatory-update
7
```

Resultado en la Odin: la OOBE aparece, el usuario elige idioma/zona/WiFi, y la
consola **no se reinicia**. Tras completar la OOBE, Steam llega al login
correctamente.

---

## Commits asociados

| Commit | Descripción |
|---|---|
| `e574b2a` | `fix(boot)`: pocknix-diag a timer (no bloquea multi-user.target) + gate DRM en pocknix-steam |
| `b88018d` | `feat(steamos-shim)`: OOBE marker (`/etc/steamos-oobe-image`) + shims `steamos-mandatory-update` / `jupiter-initial-firmware-update` (pkgrel 8) |
| `d13f65d` | `fix(steamos-shim)`: `steamos-update` / `steamos-mandatory-update` `apply` → exit 7 (no "system restart required") |

## Ficheros tocados

| Fichero | Commits |
|---|---|
| `overlay/etc/systemd/system/pocknix-diag.timer` | `e574b2a` |
| `overlay/etc/systemd/system/pocknix-diag.service` | `e574b2a` |
| `scripts/build-sd-image.sh` | `e574b2a` |
| `packages/shared/pocknix-steam/pocknix-steam` | `e574b2a` |
| `packages/shared/pocknix-steamos-shim/PKGBUILD` | `b88018d`, `d13f65d` |
| `packages/shared/pocknix-steamos-shim/steamos-update` | `d13f65d` |
| `packages/shared/pocknix-steamos-shim/steamos-mandatory-update` | `b88018d`, `d13f65d` |
| `packages/shared/pocknix-steamos-shim/steamos-oobe-image` | `b88018d` |
