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
