# HDR APAGADO POR DEFECTO + MANGOHUD NUESTRO (16/10/2026) — Odin 3

Dos arreglos sobre la Odin (`192.168.4.21`, usuario `deck`), acordados con Fransis el 11/10:

1. **El HDR debe arrancar APAGADO por defecto** → `pocknix-hdr-restore` nunca se ejecutaba por un
   **ciclo de ordenación** de systemd.
2. **MangoHUD correcto** → la Odin llevaba el snapshot de **Valve (Deckard)**, sin nuestros parches
   Qualcomm, lo que **desfasaba los FPS** sobre todo con HDR activo.

---

## 1 — HDR: ciclo de ordenación (causa raíz)

### Síntoma
El HDR arrancaba **ON** (`GAMESCOPE_DISPLAY_HDR_ENABLED = 1`) y el servicio que lo corrige estaba
`enabled` pero **`inactive (dead)`**, sin `ActiveEnterTimestamp`: **nunca llegó a ejecutarse**.

### Causa raíz (journal de arranque)
```
multi-user.target: Found ordering cycle: pocknix-hdr-restore.service/start after graphical.target/start
  after multi-user.target/start - after pocknix-hdr-restore.service
multi-user.target: Job pocknix-hdr-restore.service/start deleted to break ordering cycle
  starting with multi-user.target/start
```

systemd **borra el trabajo** para romper el ciclo → la unidad queda `enabled` pero jamás arranca.

El ciclo venía de mezclar, en la misma unidad, las tres cosas a la vez:

| Directriz | Valor viejo | Por qué cierra el ciclo |
|---|---|---|
| `[Install] WantedBy=` | `multi-user.target` | `multi-user.target` **tira** de la unidad |
| `[Unit] Wants=` | `graphical.target` | la unidad **tira** de `graphical.target` |
| `[Unit] After=` | `graphical.target` | `graphical.target` va **después** de `multi-user.target` |

Cadena: `multi-user` → quiere → `pocknix-hdr-restore` → quiere → `graphical.target` → (After) →
`multi-user.target`. **Ciclo cerrado.**

### Arreglo
Fichero (centro): `overlay/etc/systemd/system/pocknix-hdr-restore.service`

| | Antes | Después |
|---|---|---|
| `[Unit] Wants=` | `graphical.target` | **(eliminado)** |
| `[Unit] After=` | `graphical.target pocknix-decky-loader.service` | igual (sin cambios) |
| `[Install] WantedBy=` | `multi-user.target` | **`graphical.target`** |

Con `WantedBy=graphical.target` + `After=graphical.target`, la unidad entra por `graphical.target`
y se ordena **tras** él: `graphical` → quiere → `unidad` → After → `graphical`. Sin ciclo, y además
la unidad arranca **en el punto correcto** (cuando la sesión gráfica ya existe).

**Sin carrera**: el script `/usr/local/bin/pocknix-hdr-restore` **espera hasta 3 min**
(90 × 2 s) a que exista el átomo `GAMESCOPE_DISPLAY_HDR_ENABLED`, así que no importa que la unidad
arranque algo antes que la sesión.

### Validación de sintaxis
```
systemd-analyze verify --root=/tmp/opencode .../pocknix-hdr-restore.service   → exit 0, sin avisos
```
En la propia Odin: `sudo systemd-analyze verify /etc/systemd/system/pocknix-hdr-restore.service`
→ **exit 0**, sin "ordering cycle". (En el PC local da un aviso de *binary no ejecutable*, que es
esperado: `/usr/local/bin/pocknix-hdr-restore` solo existe en el dispositivo.)

### El mecanismo de preferencia (sin cambios)
`overlay/usr/local/bin/pocknix-hdr-restore`:
- lee `/var/lib/pocknix/hdr-enabled` (lo escribe **PocknixControl**);
- si **no existe**, usa `POCKNIX_HDR_DEFAULT` de `/etc/pocknix/hdr.conf` = **`off`**;
- aplica el átomo **dos veces** (5 s de separación) porque **el cliente Steam lo pone a 1** al
  arrancar (`GAMESCOPE_INTERNAL_DEVICE_ID` + perfil Lua hacen que el panel se anuncie HDR-capable).

### Bump para OTA
`packages/pocknix-system-overlay/PKGBUILD`: **`pkgrel=2` → `pkgrel=3`**
(el contenido lo aporta `tools/sync-to-os.sh`, que copia `overlay/` → `rootfs/` en el build).

---

## 2 — Estado del átomo HDR en la Odin (antes / después)

| | Antes | Después |
|---|---|---|
| `xprop -root GAMESCOPE_DISPLAY_HDR_ENABLED` | **`= 1`** (HDR ON) | **`= 0`** (SDR, por defecto) |
| `systemctl status pocknix-hdr-restore` | `inactive (dead)` | `active (exited)`, status=0 |
| `systemctl is-enabled` | `enabled` (pero borrado del job) | `enabled` |
| symlink | `multi-user.target.wants/…` | **`graphical.target.wants/…`** |
| ciclo en el journal | sí (14:40:16) | **no** (nada desde 16:15) |
| `/var/lib/pocknix/hdr-enabled` | **no existe** → defecto `off` | **no existe** → se aplica `off` ✔ |

Log del servicio tras el fix:
```
pocknix-hdr-restore: HDR=0 (preferencia: /var/lib/pocknix/hdr-enabled …)
Finished Aplicar la preferencia de HDR (gamescope) al arrancar la sesion.
```

### Pasos aplicados en caliente (sin reiniciar la Odin)
```bash
cp -a /etc/systemd/system/pocknix-hdr-restore.service \
      /etc/systemd/system/pocknix-hdr-restore.service.bak-20261016   # backup previo
cp /tmp/pocknix-hdr-restore.service.new /etc/systemd/system/pocknix-hdr-restore.service
systemctl daemon-reload
systemctl disable pocknix-hdr-restore    # ← elimina el symlink viejo de multi-user.target.wants
systemctl enable  pocknix-hdr-restore    # ← crea el nuevo en graphical.target.wants
systemctl start   pocknix-hdr-restore
```
`disable` + `enable` es obligatorio: `daemon-reload` **no** reubica los symlinks de `[Install]`.

El `.install` del paquete usa `systemctl enable pocknix-hdr-restore.service` **genérico** (no fija
el target), así que al llegar por OTA reproduce exactamente este estado → **no hay que tocarlo**.

---

## 3 — MangoHUD: el equivocado vs el nuestro

### Problema
La Odin tenía **`mangohud 1:0.8.4.r184.ge1430aba-1`** = snapshot de **Valve (Deckard)**, **sin** los
parches Qualcomm → el HUD **marca los FPS desfasados** (visiblemente, y sobre todo con HDR activo).

### La diferencia: el parche 0006 de frame pacing
El nuestro (`packages/mangohud`, `pkgver=0.8.4 pkgrel=1`) lleva **8 parches**:

| # | Parche | Para qué |
|---|---|---|
| 0001 | Qualcomm-GPU-support | soporte GPU Qualcomm |
| 0002 | GPU-devfreq | devfreq de la GPU |
| 0003 | Battery-name | nombre de batería |
| 0004 | Qualcomm-battery-power-now | potencia de batería Qualcomm |
| 0005 | RAM-name | nombre de RAM |
| **0006** | **mangoapp-pace-redraw-to-frame-messages** | **frame pacing del HUD** ← el relevante aquí |
| 0007 | msm-hottest-gpu-zone | zona más caliente MSM |
| 0008 | gpu_fdinfo-skip-unreadable-fdinfo | fdinfo ilegible |

**El 0006 es el que arregla el desfase.** `mangoapp` no tenía *pacing* en el caso visible:
`new_frame` se ponía a `true` con cada mensaje de fotograma de gamescope pero **nunca se limpiaba**
→ tras el primer mensaje el bucle quedaba en **free-running**, golpeando `glfwSwapBuffers` sin control
y desincronizando el HUD del juego (medido en la RP6: 72-120 composites/s contra un juego de ~44 fps).
El parche consume `new_frame` tras renderizar (**1 redraw por fotograma**) y espera en la condvar con
**timeout de 100 ms** (los keybinds siguen respondiendo).

> Nota: upstream lo resolvió de forma funcionalmente idéntica como PR #2067 (commit `2c1dc528`,
> fusionada 06/06/2026) pero **aún no está en ninguna release** (post-v0.8.4) → **mantener el parche**
> mientras estemos en v0.8.4.

### Instalación (Odin)
Ruta del paquete ya compilado en el PC (solo se leyó; **no se compiló nada**):
```
fransis@192.168.4.60:/home/fransis/pocknix-odin3-project/pocknix-os/build/localrepo/sm8750/
  mangohud-0.8.4-1-aarch64.pkg.tar.xz        # 2 178 760 bytes, 15:07 CEST
md5 = 9ff0692009e1e09c283e3b48d3ae5d65       # verificado en PC, portátil y Odin
```
Copiado PC → portátil → Odin, e instalado con:
```bash
sudo pacman -U --noconfirm /tmp/mangohud-0.8.4-1-aarch64.pkg.tar.xz
# warning: downgrading package mangohud (1:0.8.4.r184.ge1430aba-1 => 0.8.4-1)
# downgrading mangohud...    exit=0
```
**Nota**: `pacman -U` lo trató como *downgrade* explícito (por el epoch de Valve); con
`--noconfirm` lo acepta sin preguntar. **No fue un `-Syu`** (ver el pendiente del epoch).

### Verificación (antes → después)

| | Antes | Después |
|---|---|---|
| `pacman -Q mangohud` | `1:0.8.4.r184.ge1430aba-1` (Valve) | **`0.8.4-1`** (nuestro) |
| `mangohud --version` | (r184 de Deckard) | **`v0.8.4+`** |
| `Build Date` | — | `Fri Oct 16 14:55:00 2026` |
| binarios | `/usr/bin/mangohud`, `/usr/bin/mangoapp` | idem, `mangoapp` 5 446 296 B |

**Prueba de que es nuestro** (y lleva los 8 parches): el `.BUILDINFO` del paquete instalado trae
```
pkgbuild_sha256sum = 4d496509839453bb6ba55e87c790989ab87e9f6f5f0b006ec3a22fd2dd3d7c2d
```
y ese hash coincide **exactamente** con:
- `packages/mangohud/PKGBUILD` del **centro** (el que declara los 8 parches, incluido el 0006),
- `pocknix-os/packages/soc/mangohud/PKGBUILD` (receta del árbol de build),
- el `PKGBUILD` dentro del chroot `build/pkgbuild-root-sm8750/build/mangohud/`.

Las tres rutas = `4d496509…` → el binario instalado salió de **nuestra** receta.

---

## ⏳ PENDIENTES (no hecho a propósito)

### P1 — `epoch=1` en `packages/mangohud/PKGBUILD` + recompilar/publicar ⚠️ **AVISO A FRANSIS**
El de Valve es **`1:0.8.4.r184.ge1430aba-1`** (epoch **1**) y el nuestro **`0.8.4-1`** (sin epoch).
**`1:0.8.4.r184…` > `0.8.4-1` para pacman**, así que:
- un `-Syu` **no** cambiaría nunca un dispositivo que tenga el de Valve por el nuestro;
- y **hoy** el repo `pocknix` ni siquiera ofrece el nuestro (`pacman -Ss mangohud` →
  `pocknix/mangohud 0.8.3-6`; el `0.8.4-1` **solo está en `build/localrepo`, sin publicar**).

**Fix pendiente**: poner `epoch=1` en `packages/mangohud/PKGBUILD` → obliga a **recompilar y
republish** el paquete. **NO se ha hecho sin autorización** (según lo acordado): si se pone el epoch,
avisar antes, porque toca cadena de build/publicación.

### P2 — Toggles de HDR duplicados → decidir con Fransis
Hay **dos** toggles de HDR que pisan la misma preferencia:
- **`pocknix-control`** → `py_modules/pocknix_control/hdr.py`, escribe `/var/lib/pocknix/hdr-enabled`
  (la lee `pocknix-hdr-restore`);
- **plugin "Panel de Control" de Hooandee** (Decky).

Hoy `pocknix-hdr-restore` solo mira el fichero de PocknixControl. Hace falta decidir **cuál manda**
(si uno escribe en un sitio y el otro en otro, el átomo final es imprevisible) y unificar la fuente
de verdad.

### P3 — `pocknix-system-overlay` pkgrel 3 pendiente de publicar por OTA
El `pkgrel=2 → 3` está en el centro pero **falta publicar** para que el fix del ciclo llegue a los
dispositivos por OTA (mientras tanto, hay que aplicarlo en caliente como se hizo hoy en la Odin).

---

## Referencias
- `docs/HDR-OFF-POR-DEFECTO-2026-10-11.md` — acuerdo de dejar HDR apagado por defecto (11/10) y
  por qué el gate `STEAM_GAMESCOPE_HDR_SUPPORTED` **no** basta (el cliente Steam ARM64 pone el átomo
  a 1 por su cuenta): el que lo apaga de verdad es `pocknix-hdr-restore`.
- `docs/QAM-DETRAS-DEL-JUEGO-2026-10-09.md` — síntoma original del HDR global sobre QAM/mangoapp.
- `packages/mangohud/0006-mangoapp-pace-redraw-to-frame-messages.patch` — por qué el HUD se desfasa.
