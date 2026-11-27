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
| 2026-11-27 | Panel de Control (Hooandee) | https://github.com/Hooandee/panel-de-control/pull/1524 | PR | open (0 comentarios) | 2026-11-27 | Esperando review del soporte aarch64 de MAKO. |
| 2026-09 | ArmadaOS | https://github.com/armada-os/armada/issues/402 | Issue | closed (resuelto) | 2026-09-25 | Nada; guardado como referencia de la carga de batería. |
