# Arranque lento + Asistente OOBE de Steam — RESUELTO (14/09/2026)

**Estado: la Odin 3 arranca en ~20 s, llega a `graphical.target` en ~9.5 s de
userspace, y el asistente inicial de Steam (idioma/zona/WiFi) aparece **una sola
vez** en una imagen limpia: se completa, la consola reinicia una vez (modo
"factory image") y el siguiente arranque va directo al login de Steam — sin bucle.**

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

### 6. Causa raíz (parte 3: el marker fuerza modo "factory image" → bucle)

El fix `d13f65d` eliminó el reinicio provocado por el **paso de update**, pero la
consola seguía reiniciándose. Log del cliente Steam (UI, bundle
`steamui/chunk~2dcc5aaf7.js`):

```js
IsDeckFactoryImage() || … ? bRequireReboot = true : bRequireSteamRestart = true
…
if (kr) { console.warn("Restarting PC"); SteamClient.System.RestartPC() }
```

y la condición de "OOBE completada":

```js
GetOOBEStage1Complete() { return (oobe_completed) && !IsDeckFactoryImage() }
```

Es decir: `/etc/steamos-oobe-image` hace que el cliente trate la imagen como una
**"Deck factory image"**. Consecuencias:

1. la OOBE se muestra **siempre** (`!IsDeckFactoryImage()` es `false` → nunca se da
   por completada), y
2. al terminar llama a `RestartPC()` → reinicia **la consola entera**, no solo Steam.

Como nadie borraba el marker, una imagen limpia entraba en **bucle**: OOBE →
reinicio → OOBE → …

> **Nota importante**: `scripts/build-image.sh` (código upstream) asume que borrar
> `registry.vdf` hace que la OOBE aparezca **sin** marker. Verificado en la Odin que
> **no es así**: sin el marker la OOBE **no sale** y va directo al login (probado con
> el estado de Steam completamente limpio). El proyecto hermano ArmadaOS
> directamente hace `rm -f /etc/steamos-oobe-image` (renuncia a la OOBE). Por eso
> nuestra solución **mantiene** el marker y lo limpia después.

### 7. Fix 3: servicio que borra el marker al completar la OOBE (commit `a5bfc9d`)

| Fichero | Cambio |
|---|---|
| `overlay/usr/local/bin/pocknix-oobe-marker` | **Nuevo**: one-shot. Si existe el marker **y** `~/.steam/registry.vdf` contiene `CompletedOOBEStage1 "1"` (lo escribe Steam al terminar idioma/zona/WiFi), borra `/etc/steamos-oobe-image` |
| `overlay/etc/systemd/system/pocknix-oobe-marker.service` | **Nuevo**: `Before=getty@tty1.service` (mismo slot que `pocknix-expand-root.service`), `ConditionPathExists=/etc/steamos-oobe-image` |
| `scripts/build-sd-image.sh` | Lo instala (`chmod +x`) y lo habilita (`systemctl enable`) |

Resultado: la OOBE sale **una vez** (arranque 1), la consola reinicia una vez
(comportamiento normal del modo factory) y en el arranque 2 el servicio ya borró el
marker → **directo al login de Steam**.

### 8. Verificación

Exit codes del shim (en el rootfs de la SD):

```bash
$ /usr/bin/steamos-update --supports-duplicate-detection
0
$ /usr/bin/steamos-update check
7
$ /usr/bin/steamos-update          # sin args (= apply)
7
$ /usr/bin/steamos-mandatory-update check
7
```

Ciclo completo en la Odin (imagen con el fix):

- **Arranque 1**: OOBE (idioma → zona → WiFi) → se completa → la consola reinicia.
- **Arranque 2**: `/etc/steamos-oobe-image` ya no existe (lo borró el servicio),
  `CompletedOOBEStage1=1` en el registry, `pocknix-oobe-marker.service` = `active
  (exited)`, **0 unidades fallidas** → **directo al login de Steam, sin OOBE.**

> Observación menor: tras el reinicio de la OOBE, en el primer arranque en modo juego
> el audio de la interfaz de Steam apareció mudo hasta volver a entrar en modo juego
> (en Plasma sonaba bien). Transitorio; no se ha reproducido después.

---

## Commits asociados

| Commit | Descripción |
|---|---|
| `e574b2a` | `fix(boot)`: pocknix-diag a timer (no bloquea multi-user.target) + gate DRM en pocknix-steam |
| `b88018d` | `feat(steamos-shim)`: OOBE marker (`/etc/steamos-oobe-image`) + shims `steamos-mandatory-update` / `jupiter-initial-firmware-update` (pkgrel 8) |
| `d13f65d` | `fix(steamos-shim)`: `steamos-update` / `steamos-mandatory-update` `apply` → exit 7 (no "system restart required") |
| `a5bfc9d` | `fix(oobe)`: servicio `pocknix-oobe-marker` que borra el marker al completar la OOBE (fin del bucle de reinicio) |

## Ficheros tocados

| Fichero | Commits |
|---|---|
| `overlay/etc/systemd/system/pocknix-diag.timer` | `e574b2a` |
| `overlay/etc/systemd/system/pocknix-diag.service` | `e574b2a` |
| `scripts/build-sd-image.sh` | `e574b2a`, `a5bfc9d` |
| `packages/shared/pocknix-steam/pocknix-steam` | `e574b2a` |
| `packages/shared/pocknix-steamos-shim/PKGBUILD` | `b88018d`, `d13f65d` |
| `packages/shared/pocknix-steamos-shim/steamos-update` | `d13f65d` |
| `packages/shared/pocknix-steamos-shim/steamos-mandatory-update` | `b88018d`, `d13f65d` |
| `packages/shared/pocknix-steamos-shim/steamos-oobe-image` | `b88018d` |
| `overlay/usr/local/bin/pocknix-oobe-marker` | `a5bfc9d` |
| `overlay/etc/systemd/system/pocknix-oobe-marker.service` | `a5bfc9d` |
