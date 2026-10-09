# QAM detrás del juego — causa raíz y fix permanente (09-oct-2026)

**Síntoma.** En la Odin 3, con Steam en Game Mode (gamescope), al abrir el **QAM**
(Quick Access Menu, el menú de Steam con `...`) **detrás del juego** en muchas pantallas:
el QAM se veía por debajo del juego a pantalla completa, o directamente no respondía — el
**toque y el foco** caían en el juego, no en el QAM. No pasaba en todos los juegos ni en todas
las pantallas; aparecía sobre todo con juegos que presentan en fullscreen.

**Efecto secundario visible.** El `xprop -root | grep GAMESCOPE_COMPOSITE_FORCE` no bastaba
para arreglarlo en caliente: al cambiarlo, el QAM seguía sin recibir foco.

---

## Causa raíz (dos piezas que se pelean)

### 1) El parche ROCKNIX `0008-steamcompmgr-classify-the-interactive-overlay-by-out`
En el gamescope de **ROCKNIX** (el que usábamos al principio) el parche
`0008-steamcompmgr-classify-the-interactive-overlay-by-out…` clasificaba el *overlay*
interactivo por la **anchura de la salida** (`out_width`). En un **panel rotado con ancho
lógico ≤ 1200** (justo el caso de la Odin: 1080 de ancho lógico tras la rotación), el QAM
se clasificaba como **notificación** en vez de como overlay interactivo. Una notificación:
- no captura **foco**,
- no recibe **toque**,
- y se compone **por debajo** de la superficie del juego.

Es decir: el QAM existía, pero el compositor no lo trataba como algo con lo que se interactúa.

### 2) Nuestra base gamescope de OGC ya trae la lógica buena
La base de gamescope que usamos ahora (**OGC**, `gamescope-1:3.16.29.ogc2…`) **ya trae** el
arreglo correcto: la clasificación del overlay usa

```c
nWidth >= root_width || inputFocusMode
```

y **no** la anchura de la salida. Con esto, en la Odin el QAM vuelve a clasificarse como
overlay **interactivo**: recibe foco y toque, y se pinta **encima**. Este es exactamente el
comportamiento de **armadaOS**, que usa esta misma base.

### 3) Y encima `--force-composition` se pelea con la base OGC
En una fase anterior, para el gamescope de **ROCKNIX**, añadimos `--force-composition`
al `GAMESCOPECMD` de la sesión (y al lanzador `pocknix-steam`): el scan-out directo de
MSM/Adreno no componía los planos overlay y la UI de gamescope (QAM, MangoHUD vía
`mangoapp`) quedaba detrás del juego. Se reforzó con el parche `0011` para que la propiedad
X11 `GAMESCOPE_COMPOSITE_FORCE` no pudiera cancelar el flag.

**Con la base de OGC, ese flag ya no hace falta y además estorba**: forzar la composición
en una base que **ya clasifica bien** el overlay interactivo provoca que el QAM se componga
**detrás** del juego. La base OGC resuelve el problema por sí sola (por `root_width`);
`--force-composition` sólo lo reintroduce, por la puerta de atrás.

---

## Fix = quitar `--force-composition` (como armada)

Se **elimina** el flag de los dos sitios donde vivía, y se deja la sesión/lanzador como los
tiene armadaOS:

| Fichero | Antes | Ahora |
|---|---|---|
| `packages/gamescope-session-steam/usr/share/gamescope-session-plus/sessions.d/steam` | `--force-composition \` en `GAMESCOPECMD` | **fuera** |
| `packages/pocknix-steam/pocknix-steam` | `… "${GS_ROTATE[@]}" --force-composition -e --` | `… "${GS_ROTATE[@]}" -e --` |

Lo que **sí** sigue: `--rotated-output-max-height` (rotación en scanout del DPU del SM8750),
`--force-orientation`, `--mangoapp`, etc.

La propiedad X11 `GAMESCOPE_COMPOSITE_FORCE` y el parche `0011` dejan de usarse: ya no hay
watcher `xprop -spy` (se retiró antes) y tampoco hay flag que asegurar. Los comentarios de
los dos ficheros y de los `PKGBUILD` se reescribieron para decir que **YA NO se usa**.

- `gamescope-session-steam` → `pkgrel` **3**
- `pocknix-steam` → `pkgrel` **65**

---

## Checklist para versiones futuras

### ⛔ Qué NO reintroducir
- **`--force-composition`** en `GAMESCOPECMD` (sesión) ni en la línea de `gamescope` del
  lanzador `pocknix-steam`. **No** lo reintroduzcas “por si acaso”: con la base OGC deja el
  QAM detrás.
- Tampoco el watcher `xprop -spy` de `GAMESCOPE_COMPOSITE_FORCE`, ni el parche
  `0011-force-composition-not-cancelled-by-x-property` ligado a él.
- Ojo de no confundir con **`--force-composition-rotation`** (opt-in
  `POCKNIX_PANEL_ROTATE_SHADER=1`), que es **otro** flag, para la rotación por shader, y
  **no** se toca.

### ✅ Cómo verificar (con la sesión arrancada)
1. **El QAM se pinta ENCIMA del juego** y responde a foco y toque.
2. Que el flag no está en marcha: `ps -ef | grep -F -- '--force-composition'` no debe
   mostrar la línea de arranque de gamescope (sí puede aparecer
   `--force-composition-rotation` si se activó el opt-in, y eso es correcto).
3. Propiedad X11: `xprop -root | grep GAMESCOPE_COMPOSITE_FORCE`. Si aparece a `1`, algo
   la ha vuelto a poner (un watcher o una versión vieja de la sesión); con el fix no se
   fuerza.
4. **Comparar con armadaOS**, que usa la base OGC sin el flag: la sesión
   `sessions.d/steam` de armada no lleva `--force-composition`. Ante la duda, armada es la
   referencia.

### Si algún día se vuelve a partir el QAM
- Comprueba primero **qué gamescope** está instalado (`pacman -Q gamescope`): debe ser la
  base **OGC** (con la lógica `nWidth >= root_width || inputFocusMode`), no el ROCKNIX con
  el parche `0008` que clasifica por `out_width`.
- Si se cambia de base y el problema es de **foco/toque** (clasificación), el arreglo es en
  **gamescope**, no en la sesión: no vuelvas a taparlo con `--force-composition`.

---

## Referencias
- `docs/session-fixes.md` — historia de los flags de la sesión.
- `docs/ARMADAOS-IMPL.md` / `docs/ARMADAOS-STUDY.md` — por qué armada es la referencia.
- `docs/DECKARD-0.5.x-INTEGRACION-2026-10-09.md` — base de gamescope/Turnip usada.
