# Plan de distribución de la próxima build (decidido 28/10/2026)

> **Estado**: no se publica nada por ahora. Este documento se ejecuta **cuando se compile la build**.
> No es una guía para el usuario: no hace falta. Se graba la imagen y punto; las actualizaciones ya
> llegan por nuestros repos.

## Decisiones

- **Sin anuncio público** hasta que la build esté compilada y verificada.
- **Distribución principal: torrent sembrado desde el portátil** (está siempre encendido).
- **R2 como espejo/almacenamiento** solo si el espacio no nos compromete (las descargas ya son gratis;
  el riesgo es el cupo de almacenamiento del bucket).
- **Descartados**: MEGA y Google Drive (cupos, límites de transferencia y bloqueos con descargas
  masivas). Ver comparativa en la conversación del 28/10.

## Qué preparar al compilar la build

1. Imagen final: `build/image/sm8750/pocknix-sm8750-sd.img` (cruda ~25 GB).
   - Comprimir con **zstd** para el torrent (estimado 3-4 GB).
   - Generar **SHA256** del `.img` y del archivo comprimido; publicarlos junto al torrent.
2. Crear el `.torrent` + **magnet** (trackers públicos, p. ej. opentrackr/ngtorrents) y dejar el
   **web seed** apuntando a R2 si la imagen cabe allí.
3. Sembrar desde el portátil en una ruta estable (p. ej. `~/releases/`), con el cliente torrent
   arrancando al inicio de sesión y límite de subida razonable para no ahogar la red de casa.
4. Verificar el seed desde fuera (magnet en otra máquina / `transmission-remote`).

## Verificaciones de la build (antes de sembrar)

- Kernel y módulos coherentes (`pocknix-kernel-guard` en OK) y `/flash/KERNEL` con el parche del panel.
- `cma=256M` presente en `/proc/cmdline` (viene en el BSP; el boot se reensambla en la instalación).
- **DeckStation y WProton: instalación inicial** (ya se probó en la build anterior; **revalidar** que
  el primer arranque los deja listos sin tocar nada).
- Primer arranque limpio: Steam en modo juego, splash nuevo, informe de incidencias operativo,
  `systemctl --failed` vacío.
- Actualizaciones: `pacman -Sy` contra nuestros repos de R2 y un `pacman -S <paquete>` de prueba.

## Pendientes que NO bloquean

- `kernel/common/patches/1082-...battmgr-fix-charge-full...` (salud de batería) → próximo build del kernel.
- Audio por **HDMI/DP**: falta dock para probar la tplg de armada.
- Formateo de SD nativo de Steam (requiere portar CDP al launcher bash).
- Hangover (Wine arm64 + ARM64EC) como segundo motor: spike, no integración.

## Aviso legal al publicar

La imagen incluye **firmware propietario de Qualcomm** y el cliente de Steam. ROCKNIX distribuye lo
mismo, pero conviene mencionarlo en el README/notas de la release.
