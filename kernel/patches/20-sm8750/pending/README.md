# Pendientes: parches de la AYN Odin 3 Portal que NO aplican todavia

Copiados de ArmadaOS `b031deef99a095104ef234c5a0705850152dffe1`
(`packages/kernel/patches/1304-...` y `1305-...`) el 11/11/2026.

**No estan activos**: este subdirectorio queda fuera del glob `*.patch` que aplica
`scripts/build-kernel.sh` (solo mira ficheros del directorio, no recursivo), porque
el build **aborta** con `patch conflict` (ya no avisa y sigue).

## Por que fallan

Los dos parches son contra `drivers/gpu/drm/panel/panel-visionox-vtdr6130-cog.c`,
el driver "COG" de Armada (el de sus parches sm8250: `panel_info`,
`vtdr6130_write_seq`, `panel_desc`, `vtdr6130_supply_config`).

Nuestro 7.2.15 **no tiene** ese fichero. Solo trae el driver upstream simple
`drivers/gpu/drm/panel/panel-visionox-vtdr6130.c` (compatible `visionox,vtdr6130`,
supplies `vddio`/`vci`/`vdd`, `devm_gpiod_get("reset")`), con otro modelo de datos.

Dry-run en `build/kernel/sm8750/linux-7.2.15`:

```
$ patch -p1 --dry-run -f < 2160-...patch
can't find file to patch at input line 11
No file to patch.  Skipping patch.
4 out of 4 hunks ignored

$ patch -p1 --dry-run -f < 2161-...patch
can't find file to patch at input line 13
No file to patch.  Skipping patch.
14 out of 14 hunks ignored
```

## Que falta para activarlos

1. Traer el driver COG (o portar los dos parches al driver simple) y anadir su
   `CONFIG_DRM_PANEL_VISIONOX_VTDR6130_COG` (hoy ni siquiera esta
   `CONFIG_DRM_PANEL_VISIONOX_VTDR6130` en `kernel/sm8750/config/linux.aarch64.conf`).
2. 2161 depende de 2160 (modifica codigo que introduce 2160): deben aplicarse en orden.
3. Solo entonces moverlos a `kernel/patches/20-sm8750/` con sus nombres 2160/2161.

El DTS `cq8725s-ayn-odin3portal.dts` ya declara `compatible = "vtdr6130,o3p"` y
`armada,dpu-8bpc-dither`; sin el driver el panel simplemente no hara probe (el DT
compila y arranca, pero la pantalla no se enciende). Es bring-up a ciegas: no hay
unidad para probarlo.
