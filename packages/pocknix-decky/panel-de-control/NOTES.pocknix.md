# Notas de pocknix sobre el plugin vendido "Panel de Control"

Plugin upstream: https://github.com/Hooandee/panel-de-control

## Versión vendida

- **v0.96.0** (release `panel-de-control-v0.96.0`, publicada el 2026-11-25), re-vendorizada el
  26/11 desde `Panel.de.Control.zip`. Ya trae `hdr=True` en `ayn_odin3` (PR #947 mergeado) y el
  arreglo del frontend (`DFL.staticClasses.Title` ya no existe), así que los dos parches
  locales anteriores son **no-op** y se mantienen solo como red por si el plugin se
  autoactualiza a una versión vieja.

## Parche local: MAKO en aarch64 (`upscalers/mako.py`)

Upstream solo conoce el Renderer **x86_64** y rechaza instalar en ARM (`mako_arch`). El parche
(`overlay/usr/share/pocknix/patches/panel-de-control-arm64-mako.patch`) añade:

- `ASSET5_ARM` → `MAKO-Renderer-v5.0.0-linux-arm64.tar.gz` de `Ken5998/mako-arm64` (v0.1.0,
  sha256 `3bace05d…`), la build comunitaria del mismo Renderer.
- `PAYLOAD5_ARM` → sin `lib32/` ni `VkLayer_MAKO_render.x86.json` (en ARM hay un único JSON) y
  con `lib/libmako-render-scaling.so`.
- En ARM: `supported` incluye aarch64, el motor por defecto es el **5** (el 4 no existe para
  ARM), los perfiles con `engine=4` se leen como 5 y `install()` ignora la línea 4.

El plugin **se autoactualiza**, así que `overlay/usr/local/bin/pocknix-panel-control-patch`
re-aplica este parche (idempotente, con backup `.orig-arm64`) además de los dos anteriores.


- **v0.82.1** (release `panel-de-control-v0.82.1`, publicada el 2026-11-03), actualizada el 4/11
  desde `Panel.de.Control.zip`. Incluye la sección Ambiente (fondos/música/radio), cola de
  reproducción, enlaces por QR, arreglo de caída con Steam beta, cierre de juegos colgados y
  que los temas recuerden sus ajustes. El `hdr=True` de `ayn_odin3` ya está upstream.
- **v0.70.1** (release `panel-de-control-v0.70.1`, publicada el 2026-10-14),
  descargada del asset `Panel.de.Control.zip`.
- Versión anterior en la imagen: **v0.66.0** (copia del 2026-10-12).
- El salto incluye el soporte del **AYN Odin 3** (`b0b7d612 feat(arm): support the
  AYN Odin 3 on Armada`, 2026-10-13) y nuevos ficheros: `py_modules/remote_access.py`,
  `py_modules/display/input_wake.py`, `py_modules/display/screen_sleep.py` y los binarios
  `bin/dropbear-*`.

## Parche local de pocknix (temporal)

`py_modules/device_profiles.py`, perfil `ayn_odin3` → se añade `hdr=True`:

```python
    DeviceProfile("ayn_odin3", "AYN Odin 3", "Snapdragon 8 Elite", "qualcomm",
                  1, 6, 10, 10, dt_compatible=("ayn,odin3",), experimental=True,
                  panel="oled", hdr=True, arch="arm"),
```

- **pocknix: `hdr=True` en `ayn_odin3` (PR #947 a Hooandee, pendiente de merge)**.
- El perfil `ayn_thor` **NO** se toca.
- En la v0.70.1 este perfil viene **sin** `hdr=True` (el PR #947 aún no está mergeado),
  así que la edición es necesaria.
- **Cómo revertirlo**: al re-vendorizar una release que ya traiga `hdr=True` en
  `ayn_odin3`, esta edición deja de ser necesaria (no duplicar `hdr=True`).

## Re-aplicado automático en el dispositivo (16/10/2026)

Este plugin es el único que **se autoactualiza** desde GitHub (botón en el QAM →
`py_modules/self_updater.py`), y cada release **borra** el `hdr=True` de la copia
instalada en `/home/deck/homebrew/plugins/Panel de Control/`. Para no depender de que
nadie lo repare a mano, el paquete **`pocknix-system-overlay`** instala un script
(`/usr/local/bin/pocknix-panel-control-patch`) + una unidad `.path` que vigila
`device_profiles.py` + un `.service` (al boot) + un `.timer` (cada 15 min) que **re-aplican
`hdr=True` de forma idempotente y robusta (AST, no `sed`)**.

- Ficheros del centro: `overlay/usr/local/bin/pocknix-panel-control-patch`,
  `overlay/etc/systemd/system/pocknix-panel-control-patch.{service,path,timer}`.
- Documentación completa: `docs/PANEL-CONTROL-HDR-PATCH-20261016.md`.
- **Solución definitiva**: el PR #947 a Hooandee (cuando se mergee y salga en release, el script
  queda como no-op).

## Cómo actualizar (procedimiento, 25/10/2026)

Datos del 25/10: vendemos **v0.70.1** (14/10) y upstream va por **v0.76.0** (23/10).
**Ya no llevamos delta propio**: nuestro parche `hdr=True` en el perfil `ayn_odin3` entró en
upstream (PR #947, **mergeado el 17/10**; `main` lo tiene). O sea, actualizar = sustituir.

```bash
cd <repo>/pocknix-odin3-support
V=panel-de-control-v0.76.0     # <- el que diga tools/check-hooandee.sh
curl -L -o /tmp/pdc.zip "https://github.com/Hooandee/panel-de-control/releases/download/$V/Panel.de.Control.zip"
rm -rf packages/pocknix-decky/panel-de-control
mkdir -p /tmp/pdc && unzip -q -o /tmp/pdc.zip -d /tmp/pdc
cp -a "/tmp/pdc/Panel de Control/." packages/pocknix-decky/panel-de-control/
echo "$V" > packages/pocknix-decky/panel-de-control/VENDORED
# el zip NO trae NOTES.pocknix.md: recuperarlo de git
git checkout -- packages/pocknix-decky/panel-de-control/NOTES.pocknix.md
```

Después: **bump de `pkgrel`** en `packages/pocknix-decky/PKGBUILD`, `tools/sync-to-os.sh`,
`make packages PKG="pocknix-decky"`, `stage-shared` + `publish-shared`.
**Comprobar antes** que upstream no cambió `plugin.json` de forma incompatible (api_version 1) y
que `flags` sigue llevando `root`.

Vigilancia: `tools/check-hooandee.sh` (enganchado a `check-upstream-daily.sh`), que compara
`VENDORED` con el último release y marca `<<< ACTUALIZAR`.
