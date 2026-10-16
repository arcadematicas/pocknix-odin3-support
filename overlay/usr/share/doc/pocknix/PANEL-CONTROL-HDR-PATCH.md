# Parche HDR del plugin «Panel de Control» (Hooandee) — re-aplicado automático

**Fecha:** 16/10/2026 · **Device:** AYN Odin 3 (`192.168.4.21`) · **Centro:** `arcadematicas/pocknix-odin3-support`

> Este documento es la fuente de verdad. Una copia se instala en el dispositivo como
> `/usr/share/doc/pocknix/PANEL-CONTROL-HDR-PATCH.md` (a donde apunta el `Documentation=`
> de las unidades) — ver `overlay/usr/share/doc/pocknix/PANEL-CONTROL-HDR-PATCH.md`.

---

## 1. El problema

El plugin Decky **«Panel de Control»** (autor **Hooandee**, repo `Hooandee/panel-de-control`)
vive en la Odin en:

```
/home/deck/homebrew/plugins/Panel de Control/
```

Necesitamos que el perfil `ayn_odin3` de `py_modules/device_profiles.py` lleve **`hdr=True`**.
Sin ese campo (el dataclass lo define `hdr: bool = False` por defecto) el bloque de HDR **no se
dibuja** en la UI: `src/sections/displayBlocks.tsx` hace `if (!hdr.state?.supported) return null;`.

Decisión de Fransis (16/10): **el toggle de HDR que manda es el del plugin de Hooandee** (no el
de nuestro `PocknixControl`), así que hay que mantener el `hdr=True` **siempre**.

La línea que necesitamos es exactamente:

```python
    DeviceProfile("ayn_odin3", "AYN Odin 3", "Snapdragon 8 Elite", "qualcomm",
                  1, 6, 10, 10, dt_compatible=("ayn,odin3",), experimental=True,
                  panel="oled", hdr=True, arch="arm"),
```

### Por qué se pierde

Dos cosas, en capas:

1. **La imagen ya lo trae parcheado.** El paquete `pocknix-decky` vende la release v0.70.1 con
   la edición local aplicada (ver `packages/pocknix-decky/panel-de-control/NOTES.pocknix.md`).
2. **Pero el plugin se autoactualiza solo.** Es el ÚNICO plugin que no va por la tienda Decky:
   trae un **auto-updater propio** en `py_modules/self_updater.py` con un botón «Actualizar» en el
   QAM. Al pulsarlo, `self_updater.install()` **descarga el zip de la última release de GitHub y lo
   copia ENCIMA del plugin instalado** (`shutil.copy2` fichero a fichero) y luego reinicia el loader.
   Como el **PR #947 a Hooandee** (que añade `hdr=True` a `ayn_odin3`) **sigue pendiente**, cada
   release vuelve a escribir `device_profiles.py` **sin** `hdr=True` → se pierde el parche.

Además, `pocknix-decky-sync.service` (nuestro) **NO** pisa «Panel de Control»: siembra el plugin
solo si falta (ver el bloque `PANEL DE CONTROL exception` en `pocknix-decky-sync`), nunca lo
re-copia sobre una versión actualizada por el usuario. O sea que la sincronización **no** puede
recuperar el parche — es justo por eso que necesitamos un mecanismo aparte.

### Lo que NO se toca (diseño que se respeta)

El estado HDR **al arrancar** lo fija `pocknix-hdr-restore.service` (centro:
`overlay/usr/local/bin/pocknix-hdr-restore` + su unidad) leyendo `/var/lib/pocknix/hdr-enabled`
o el defecto `POCKNIX_HDR_DEFAULT=off` de `/etc/pocknix/hdr.conf`. **Arranque en SDR** y el plugin
enciende cuando el usuario quiere. El plugin **no** escribe ese fichero: solo mueve el átomo
`GAMESCOPE_DISPLAY_HDR_ENABLED`. Este parche **no cambia nada de eso**.

---

## 2. Cómo se actualiza el plugin (lo que se ve en el journal)

- **Auto-updater del propio plugin** (`py_modules/self_updater.py`): botón «Actualizar» en el QAM →
  `install()` copia la nueva release encima y llama a
  `subprocess.Popen(["/usr/bin/systemctl","restart","plugin_loader"])`.
  `/usr/lib/systemd/system/plugin_loader.service` es un **symlink** a `pocknix-decky-loader.service`.
  Evidencia en el journal de la Odin:

  ```
  $ journalctl -u pocknix-decky-loader.service | grep -iE 'Started|Stopping'
  ... Stopping response listener for Panel de Control (v0.70.1)
  ... Started Decky Loader (via FEX).
  ```

- **Versión instalada:** `Panel de Control/package.json` → `"version": "0.70.1"` (Decky lee la
  versión de `package.json`, no de `plugin.json`; `py_modules/version.py`).
- **Propietario del fichero:** `device_profiles.py` queda **`root:root`** (el loader corre como
  root: `User=root` en la unidad; el plugin declara `"flags": ["root","_root"]`). Nuestro script
  corre como root y **preserva dueño y modo**.
- **`pocknix-decky-sync.service`** corre al arranque (lo vimos: `Finished Seed Decky Loader…`) y
  **no** toca el plugin si ya existe.

---

## 3. La solución: re-aplicado automático

Tres piezas, todas en el **overlay** del centro (llegan a la imagen y por OTA vía el paquete
`pocknix-system-overlay`):

| Fichero (centro) | Se instala en | Qué hace |
|---|---|---|
| `overlay/usr/local/bin/pocknix-panel-control-patch` | `/usr/local/bin/` | Script Python que re-aplica `hdr=True` (idempotente y robusto) |
| `overlay/etc/systemd/system/pocknix-panel-control-patch.path` | `/etc/systemd/system/` | Vigila `device_profiles.py` y dispara el `.service` cuando cambia |
| `overlay/etc/systemd/system/pocknix-panel-control-patch.service` | `/etc/systemd/system/` | Ejecuta el script (al **boot** y cuando lo dispara el `.path`) |
| `overlay/etc/systemd/system/pocknix-panel-control-patch.timer` | `/etc/systemd/system/` | Respaldo: cada **15 min** (`OnBootSec=3min`), por si el inotify no ve el reemplazo |
| `overlay/usr/share/doc/pocknix/PANEL-CONTROL-HDR-PATCH.md` | `/usr/share/doc/pocknix/` | Este mismo documento (copia) |

Las tres unidades se **habilitan** desde `packages/pocknix-system-overlay/pocknix-system-overlay.install`
(`post_install` / `post_upgrade`), así que se activan solas al instalar/actualizar el paquete.

### El script (robusto, no un `sed` frágil)

- Localiza la llamada `DeviceProfile("ayn_odin3", …)` con el **AST de Python** (`ast.parse` +
  `ast.walk`), así que respeta multilínea, comillas y paréntesis anidados.
- Si el perfil **ya** tiene un argumento `hdr=` → **no toca nada** (idempotente) y sale con 0.
- Si no lo tiene → inserta `, hdr=True` **justo después del último argumento** de la llamada
  (sea posicional o keyword), que siempre produce Python válido
  (`…panel="oled", arch="arm", hdr=True),`).
- **Valida** el resultado con `ast.parse` antes de escribir; si no es válido, **no escribe** y sale
  con ≠0.
- Deja backup **`.orig`** (la copia sin parchear que va a reemplazar).
- Escribe de forma **atómica** (`mkstemp` en el mismo directorio + `os.replace`) y **preserva modo
  y dueño** (root:root, 0755).
- Borra `__pycache__/device_profiles*.pyc` para que el siguiente import recompile.
- Registra en el **journal** lo que hizo (`print` + `syslog`, tag `pocknix-panel-control-patch`).

### Unidades (y la lección del ciclo de ordenación)

- `.path` usa **`PathChanged=`** (IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE | …) y **deliberadamente
  NO** `PathModified=` (IN_MODIFY). El auto-updater usa `shutil.copy2` (abre el destino con `wb`,
  lo trunca y lo cierra) → `IN_CLOSE_WRITE` dispara cuando el fichero **ya está completo**, así que
  el script nunca lee un fichero a medias. También cubre el reemplazo atómico (rename) y la creación.
- `.service`: `Type=oneshot`, `WantedBy=multi-user.target`, `After=local-fs.target
  pocknix-decky-sync.service`, **`Before=pocknix-decky-loader.service`**. Al arrancar, el parche se
  aplica **antes** de que el loader lea `device_profiles.py`. No depende de `graphical.target` → **no
  hay ciclo**. (Recordatorio del 16/10: `WantedBy=multi-user.target` + `After=graphical.target` +
  `Wants=graphical.target` deja el trabajo cancelado; aquí no se mezcla nada de eso.)
- `.timer`: `WantedBy=timers.target`, `OnBootSec=3min` + `OnUnitActiveSec=15min`.

### NO reinicia Decky

El script solo deja el fichero correcto para el **siguiente** arranque del loader. **Nunca** reinicia
el loader: en modo juego reiniciar `plugin_loader` crashea `steamwebhelper` (crasheo conocido). En el
flujo normal, el propio auto-updater **ya** reinicia el loader justo después de copiar; entre el
`restart` y el `RestartSec=5` + `TimeoutStopSec=15` del loader, el `.path` tiene tiempo de sobra para
re-aplicar el parche antes de que el loader vuelva a leer el fichero.

---

## 4. Verificación en la Odin

```sh
# estado
systemctl is-enabled pocknix-panel-control-patch.{service,path,timer}   # enabled/enabled/enabled
systemctl is-active  pocknix-panel-control-patch.path                   # active
systemctl list-timers pocknix-panel-control-patch.timer

# prueba (romper el parche a propósito)
F='/home/deck/homebrew/plugins/Panel de Control/py_modules/device_profiles.py'
sudo cp -f "$F.orig" "$F"        # deja el perfil SIN hdr=True
sleep 6
sed -n '/ayn_odin3/,+2p' "$F"    # -> debe volver a aparecer ", hdr=True"
sudo journalctl -u pocknix-panel-control-patch.service -n 5 --no-pager
```

Resultado real (16/10, Odin): tras romperlo, el journal muestra
`APLICADO: hdr=True anadido al perfil ayn_odin3 …` y el fichero queda con `hdr=True`. Probado en
los tres caminos: `cp` in-place, `shutil.copy2` (lo que hace el updater) y **rename atómico**; y el
arranque de boot (`systemctl start …service`) es un **no-op idempotente** (`ok: ayn_odin3 ya tiene hdr`).

---

## 5. Cómo revertir

- **Automático (lo esperado):** cuando Hooandee mergee el **PR #947** y una release traiga
  `hdr=True` de fábrica, el script se vuelve un **no-op** (detecta el `hdr=` y no hace nada). Se puede
  retirar el mecanismo:

  ```sh
  sudo systemctl disable --now pocknix-panel-control-patch.{path,timer,service}
  sudo rm /etc/systemd/system/pocknix-panel-control-patch.{service,path,timer}
  sudo rm /usr/local/bin/pocknix-panel-control-patch
  sudo systemctl daemon-reload
  ```

  (y quitar los ficheros del centro + el `enable` del `.install` + bajar/ajustar el `pkgrel`).
- **Manual:** `cp -f device_profiles.py.orig device_profiles.py` (el `.orig` es la copia sin parche).

---

## 6. La solución definitiva

El apaño es **temporal**. Lo correcto es el **PR #947 a Hooandee**
(`Hooandee/panel-de-control`) que añade `hdr=True` al perfil `ayn_odin3` aguas arriba. Cuando lo
acepte y salga en una release, este mecanismo deja de ser necesario (el script quedará inactivo solo).
Mientras tanto, esto garantiza que el toggle de HDR del plugin siga disponible pase lo que pase con
las autoactualizaciones.

---

## Apéndice — ficheros del centro

```
packages/pocknix-system-overlay/PKGBUILD                 # pkgrel 3 -> 4
packages/pocknix-system-overlay/pocknix-system-overlay.install   # enable de las 3 unidades
overlay/usr/local/bin/pocknix-panel-control-patch
overlay/etc/systemd/system/pocknix-panel-control-patch.service
overlay/etc/systemd/system/pocknix-panel-control-patch.path
overlay/etc/systemd/system/pocknix-panel-control-patch.timer
overlay/usr/share/doc/pocknix/PANEL-CONTROL-HDR-PATCH.md
docs/PANEL-CONTROL-HDR-PATCH-20261016.md                 # este documento
```

Se aplican al árbol de compilación con `tools/sync-to-os.sh` (mapea `overlay/` →
`packages/shared/pocknix-system-overlay/rootfs/` y también a `overlay/` del build).
