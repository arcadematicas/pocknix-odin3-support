# HDR al despertar (2026-11-06)

## Síntoma

Tras suspender/despertar la Odin, el HDR vuelve a estar activo aunque en el Panel
de Control (Hooandee) esté desactivado:

```
$ xprop -root GAMESCOPE_DISPLAY_HDR_ENABLED
GAMESCOPE_DISPLAY_HDR_ENABLED(CARDINAL) = 1
```

El panel muestra `hdr = false`, pero la pantalla sale en HDR.

## Causa

Steam escribe el átomo X11 `GAMESCOPE_DISPLAY_HDR_ENABLED` a `1` al iniciar la
sesión y al resumir. El Panel de Control, por diseño, en el resume **solo re-afirma
HDR ON** (nunca apaga), así que el estado OFF del panel nunca se vuelve a aplicar y
Steam gana la carrera.

## Arreglo

Una única fuente de verdad: el perfil de color del Panel de Control

```
/home/deck/homebrew/settings/Panel de Control/color.json
```

con `global.hdr` y, por juego, `games.<appid>.hdr` (si `follow_global` está
desactivado). El estado deseado se re-aplica **en ambos sentidos** (ON y OFF):

- al arrancar la sesión (Steam pone el átomo a 1 al iniciar);
- al despertar (hook de `system-sleep`), con varias pasadas porque Steam puede
  reescribir el átomo unos segundos después del resume.

Si `color.json` no existe, el script cae a `/var/lib/pocknix/hdr-enabled` y a
`POCKNIX_HDR_DEFAULT` en `/etc/pocknix/hdr.conf`.

## Ficheros tocados

- `overlay/usr/local/bin/pocknix-hdr-restore` (reescrito; 755) — lee `color.json`,
  resuelve el appid enfocado y aplica `GAMESCOPE_DISPLAY_HDR_ENABLED` como `deck`
  sobre `DISPLAY=:0`, con 3 pasadas separadas 5 s.
- `overlay/etc/systemd/system/pocknix-hdr-resume.service` (nuevo) — oneshot sin
  `[Install]`, lo dispara el hook de sleep.
- `overlay/usr/lib/systemd/system-sleep/zz-hdr` (nuevo; 755) — en `post` lanza
  `pocknix-hdr-resume.service` con `--no-block`.
- `packages/pocknix-system-overlay/PKGBUILD` — `pkgrel` 12 → 13.
- `docs/HDR-RESUME-20261106.md` — este documento.

## Limitación conocida

Al **lanzar** un juego con `hdr = false`, el Panel de Control tampoco apaga el HDR
(solo lo re-afirma al resumir). Ese caso se corrige en el siguiente
suspender/despertar, que ya aplica el estado real del juego enfocado.

## Cómo probar

1. Con HDR desactivado en el Panel de Control, comprobar el valor actual:

   ```
   runuser -u deck -- env DISPLAY=:0 xprop -root GAMESCOPE_DISPLAY_HDR_ENABLED
   ```

2. Suspender y despertar el dispositivo.

3. Volver a leer el átomo: debe quedar en `0`.

   ```
   runuser -u deck -- env DISPLAY=:0 xprop -root GAMESCOPE_DISPLAY_HDR_ENABLED
   ```

4. Revisar el journal del servicio (debe imprimir
   `pocknix-hdr-restore: HDR=0 appid=global`):

   ```
   journalctl -u pocknix-hdr-resume.service -b --no-pager
   ```

5. Repetir con HDR activado en el panel: el átomo debe quedar en `1`.
