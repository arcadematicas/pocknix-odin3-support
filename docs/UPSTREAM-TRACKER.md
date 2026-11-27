# Registro de upstream (UPSTREAM-TRACKER)

Aquí se anota **todo lo que abrimos o comentamos en repositorios ajenos** (PRs, issues y
seguimientos). Es el historial de trabajo compartido con el upstream: qué hemos tocado, en qué
estado está y qué queda pendiente de nuestra parte.

## Flujo de trabajo

1. **Al abrir o comentar algo en un repo ajeno se añade una fila** a la tabla de abajo, con la
   fecha, el enlace y, sobre todo, la **siguiente acción** (que es humana).
2. **`tools/upstream-tracker.py` revisa todas las entradas cada día** contra la API pública de
   GitHub (sin token, con pausa entre llamadas y reintentos ante límites de tasa).
3. **El script actualiza `Estado` y `Última revisión`** con lo que diga GitHub (state, número de
   comentarios/reseñas y `updated_at`) y avisa por Telegram solo cuando hay cambios. No escribe
   en este fichero: `estado.json` guarda la comparación.
4. **La columna `Siguiente acción` es manual**: nadie la toca automáticamente. Es la decisión
   nuestra (esperar, rebasar, probar en la Odin, cerrar...). Para pegar filas ya revisadas,
   `upstream-tracker.py --print-md` imprime las filas con estado actualizado.

Estado a **27/11/2026**.

| Fecha | Proyecto | Enlace | Tipo | Estado | Última revisión | Siguiente acción |
|---|---|---|---|---|---|---|
| 2026-09-14 | pocknix (shuuri-labs) | https://github.com/shuuri-labs/pocknix-os/pull/81 | PR | open (8 comentarios) | 2026-10-12 | Esperar respuesta; rebasar si la piden. No moverlo mientras revisa. |
| 2026-10-15 | MAKO (eugeniosegala) | https://github.com/eugeniosegala/MAKO/issues/60 | Issue | open (7 comentarios) | 2026-11-19 | Autor no trabaja ARM; seguimos con el port comunitario. Cerrar cuando el panel tenga soporte. |
| 2026-11-22 | SkywardRecomp | https://github.com/Ramasanjaya22/SkywardRecomp/issues/18 | Issue | closed (arreglado en v0.8.3) | 2026-11-27 | Probar v0.8.4 SIN turnipfix en la Odin y confirmar. |
| 2026-11-23 | SkywardRecomp | https://github.com/Ramasanjaya22/SkywardRecomp/issues/19 | Issue | open (3 comentarios) | 2026-11-27 | Esperando respuesta a nuestro update del 26/11; probar v0.8.4. |
| 2026-11-27 | Panel de Control (Hooandee) | https://github.com/Hooandee/panel-de-control/pull/1524 | PR | open (0 comentarios) | 2026-11-27 | Añadir al PR: coerción motor 4→5 al guardar y puente ppd→nivel TDP; luego comentar. |
| 2026-09 | ArmadaOS | https://github.com/armada-os/armada/issues/402 | Issue | closed (resuelto) | 2026-09-25 | Nada; guardado como referencia de la carga de batería. |

| 2026-11-27 | RustDesk | (por abrir) | Issue | por abrir | - | Reportar: AppImage aarch64 con GStreamer 1.16/libpipewire 0.2 crashea al capturar (SIGSEGV); el .deb va. |
| 2026-11-27 | KDE | https://bugs.kde.org/show_bug.cgi?id=466276 | Bug | REOPENED | 2026-11-11 | Comentar nuestro caso (Odin 3, salida rotada, escala 1.5) y el workaround. |
| 2026-11-27 | Peanuts (igawa6) | https://github.com/igawa6/peanuts-native/pull/130 | PR | open | 2026-11-27 | Comentar: falta xcb-util-cursor en la doc de Linux; idioma por DM_LANG en launcher Linux. |

## Tiendas de AppImages (revisar 28/11/2026)

- **metalmike17/appimage-vault** — https://github.com/metalmike17/appimage-vault: catálogo de
  AppImages (aarch64/x86). Tarea: ver qué sirve para la Odin (emuladores, herramientas), comparar
  con nuestra tienda (`calvos-appman` / `pocknix-decky` store) y valorar integrar el catálogo o
  sacar paquetes sueltos (`calvos-*`).
