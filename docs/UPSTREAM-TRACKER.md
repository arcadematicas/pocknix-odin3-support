# Registro de upstream (UPSTREAM-TRACKER)

Aquí se anota **todo lo que tocamos en repositorios ajenos** (PRs, issues y comentarios) y lo que
tenemos **pendiente de tocar**. La columna **Depende de** separa lo que está esperando a otros de
lo que es acción nuestra; así no se confunde "abierto" con "pendiente de nosotros".

## Flujo de trabajo

1. **Se añade una fila al abrir o comentar algo** en un repo ajeno, con fecha, enlace, estado y
   **siguiente acción** (humana).
2. **`tools/upstream-tracker.py`** revisa todas las entradas a diario contra la API de GitHub y
   avisa por Telegram si cambia algo (estado, comentarios, `updated_at`). No edita este fichero.
3. **`Depende de`**: `ellos` = esperando su respuesta; `nosotros` = acción nuestra pendiente;
   `hecho` = cerrado/mergeado, se puede archivar.
4. Estado a **27/11/2026, 23:30**.

| Fecha | Proyecto | Enlace | Tipo | Estado hoy | Depende de | Siguiente acción |
|---|---|---|---|---|---|---|
| 2026-09-14 | pocknix (shuuri-labs) | https://github.com/shuuri-labs/pocknix-os/pull/81 | PR | open · 8 comentarios · 12/10 | ellos | Esperar; si sigue parado en diciembre, un ping amable. No rebasar sin que lo pidan. |
| 2026-10-15 | MAKO (eugeniosegala) | https://github.com/eugeniosegala/MAKO/issues/60 | Issue | open · 7 comentarios · 19/11 | ellos | Comentar el estado ARM real (renderer Ken5998 en el panel, coerción 4→5, puente ppd) y dejar claro que no esperamos cambios del autor. |
| 2026-11-22 | SkywardRecomp | https://github.com/Ramasanjaya22/SkywardRecomp/issues/18 | Issue | **closed** (v0.8.3) | hecho | Nada; guardado como referencia (lo arreglaron tras nuestro reporte). |
| 2026-11-23 | SkywardRecomp | https://github.com/Ramasanjaya22/SkywardRecomp/issues/19 | Issue | open · 3 comentarios · 27/11 | nosotros | Probar **v0.8.4 sin turnipfix**; si no reproduce (como el 26/11), comentar y cerrar como no reproducible. |
| 2026-11-27 | Panel de Control (Hooandee) | https://github.com/Hooandee/panel-de-control/pull/1524 | PR | open · 2 commits (`dc51f97`) · **CI verde** · comentario 28/11 | ellos | Esperar review. Comentario con la coerción 4→5 y el test corregido ya puesto. El **puente ppd→TDP** irá en PR aparte. |
| 2026-11-27 | Peanuts (igawa6) | https://github.com/igawa6/peanuts-native/pull/130 | PR | open · 5 comentarios · 26/11 (rebase `71562611`; revisión tras la próxima release) | nosotros + ellos | Comentar que en Linux falta **`xcb-util-cursor`** en la doc y que el idioma va por **`DM_LANG`**; seguir releases para revalidar. |
| 2026-11-28 | RustDesk | https://github.com/rustdesk/rustdesk/issues/17301 | Issue | open · 0 comentarios · 28/11 | ellos | Abierto con stack y evidencia; el `.deb` es el workaround (paquete `calvos-rustdesk` 1.5.3-3). |
| 2026-11-27 | KDE | https://bugs.kde.org/show_bug.cgi?id=466276 | Bug | REOPENED · 11/11 | nosotros | Comentar nuestro caso (Odin 3, salida **rotada**, escala 1.5, RustDesk) y el workaround 100 % + reconectar. |
| 2026-11-27 | Armada / ROCKNIX | (por comentar) | Issue/comentario | — | nosotros | Compartir el fix del zumbido: `qcom,ssp-period = <6>` + `pcm-ports-mask = <0x204>` en `&swr1` (docs/AUDIO-ZUMBIDO-20261126.md). |
| 2026-09 | ArmadaOS | https://github.com/armada-os/armada/issues/402 | Issue | **closed** (resuelto) | hecho | Nada; referencia de la carga de batería. |
| 2026-11-28 | SymphonyRecomp | https://github.com/BlackLabelHQ/SymphonyRecomp/issues/178 | Issue | open · 0 comentarios · 28/11 | ellos | v1.2.0p: franja verde arriba en la Odin (Box64/Turnip); en PC no aparece y el shader viejo crashea. Esperar respuesta; mientras, valorar volver a 0.5.1b. |

## Tiendas de AppImages (revisar 28/11/2026)

- **metalmike17/appimage-vault** — https://github.com/metalmike17/appimage-vault: catálogo de
  AppImages (aarch64/x86). Tarea: ver qué sirve para la Odin (emuladores, herramientas), comparar
  con nuestra tienda (`calvos-appman` / `pocknix-decky` store) y valorar integrar el catálogo o
  sacar paquetes sueltos (`calvos-*`).
