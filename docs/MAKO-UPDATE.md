# MAKO en ARM: actualización rápida (runbook)

MAKO (frame generation) no lo publica el autor para aarch64: en la Odin 3 usamos el Renderer
comunitario de **Ken5998/mako-arm64** y lo inyectamos en el Panel de Control de **Hooandee**
con un parche del overlay. Cuando sale una versión nueva hay que tocar **dos sitios**: el asset
del parche y, si el Panel cambió su `mako.py`, el propio parche.

## Qué vigila el chequeo

`tools/mako-check.sh` comprueba tres cosas:

1. **Release de `Ken5998/mako-arm64`**: última release y su asset `linux-arm64`
   (nombre, sha256 y tamaño).
2. **Release del Panel de Control (`Hooandee/panel-de-control`)**: por si hay una versión nueva
   que cambie el instalador de MAKO.
3. **Si nuestro parche sigue aplicando sobre su `main`**: baja
   `py_modules/upscalers/mako.py` y hace `patch -p1 --dry-run`.

Códigos de salida: `0` = todo al día y el parche aplica; `1` = hay que actualizar o rebasar;
`2` = error de red. Opciones: `--download` (descarga el asset aunque haya `digest`),
`--dry-run` (sin descargas ni envíos), `--notify` (Telegram solo si hay cambios).

## Sale una versión nueva del Renderer ARM

El script imprime los valores exactos. Editar
[`overlay/usr/share/pocknix/patches/panel-de-control-arm64-mako.patch`](../overlay/usr/share/pocknix/patches/panel-de-control-arm64-mako.patch):

- Actualizar la línea `+ASSET5_ARM`: **nombre**, **sha256**, **tamaño** y **URL** del asset.
- Actualizar `+PAYLOAD5_ARM` solo si la nueva build trae otros ficheros (o quita algunos).
- Si el asset nuevo no trae `digest` en la API, `mako-check.sh` lo descarga y calcula el
  sha256 con `sha256sum`; con `--dry-run` solo avisará de que no puede comparar el hash.

## El Panel se autoactualiza y el parche ya no aplica

Es normal: Hooandee toca `mako.py` y nuestros `@@` quedan desplazados.

1. Bajar el `mako.py` nuevo y hacer el diff contra el nuestro parcheado:
   ```bash
   curl -fsSLO https://raw.githubusercontent.com/Hooandee/panel-de-control/main/py_modules/upscalers/mako.py
   # diff -u mako.py.new mako.py.parcheado  ->  rehacer los bloques del parche
   ```
2. **Rebasar el parche**: regenerar los bloques `@@` y revisar que `ASSET5_ARM`,
   `PAYLOAD5_ARM`, `_arm()` y el `DEFAULTS["engine"] = 5` siguen en su sitio.
3. Comprobar que `tools/mako-check.sh` dice *«APLICA LIMPIO»*.
4. **Probar en la Odin** antes de publicar (instalación desde el panel + partida real).
5. **Bumpear `pkgrel` del overlay** en
   [`packages/pocknix-system-overlay/PKGBUILD`](../packages/pocknix-system-overlay/PKGBUILD)
   para que la imagen incluya el parche rebasado.

## Verificación antes de publicar

1. Instalar MAKO **desde el panel** en la Odin (no a mano): activar el engine 5 y comprobar
   que se descarga el asset aarch64 y que no aparece el error de capa x86_64.
2. `mako-cli quality-regression` y `mako-cli benchmark` en la consola de la Odin.
3. **Una partida real** con FG activado: fluidez, sin artefactos y sin crashes al entrar/salir.
4. Publicar con [`tools/sync-to-os.sh`](../tools/sync-to-os.sh) y el `pkgrel` del overlay
   actualizado; anotar el cambio en el CHANGELOG.

## Enlaces del repo

- Parche del Panel: [`overlay/usr/share/pocknix/patches/panel-de-control-arm64-mako.patch`](../overlay/usr/share/pocknix/patches/panel-de-control-arm64-mako.patch)
- Chequeo automático: [`tools/mako-check.sh`](../tools/mako-check.sh)
- Sincronización al OS: [`tools/sync-to-os.sh`](../tools/sync-to-os.sh)
- Contexto y diagnóstico previo: [`docs/MAKO-AARCH64.md`](MAKO-AARCH64.md)
- Seguimiento de upstream: [`docs/UPSTREAM-TRACKER.md`](UPSTREAM-TRACKER.md)
- Release ARM: https://github.com/Ken5998/mako-arm64/releases/latest
- Panel: https://github.com/Hooandee/panel-de-control
