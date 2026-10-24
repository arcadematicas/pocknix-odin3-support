# Notas de pocknix sobre el plugin vendido "Panel de Control"

Plugin upstream: https://github.com/Hooandee/panel-de-control

## Versión vendida

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
