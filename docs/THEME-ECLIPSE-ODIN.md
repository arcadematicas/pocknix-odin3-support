# THEME ECLIPSE — adaptación a la Odin 3 (preparación, sin aplicar)

> **Estado: PREPARACIÓN.** La Odin está caída (bucle de arranque, pendiente de la
> tarjeta SD). Nada de esto está aplicado. Este documento deja el terreno listo:
> tema descargado y verificado, plugin identificado, plan de adaptación/reversión
> y valoración honesta de riesgos.
>
> Fecha: 2026-10-07. Autor del doc: agente de preparación (PC, `pc-local`).
> Fuentes primarias consultadas en línea el mismo día.

---

## 1. Qué es exactamente `eclipse`

| Campo | Valor |
|---|---|
| Nombre en CSS Loader | **Hooandee Eclipse** (`theme.json` → `"name"`) |
| Id catálogo panel | `hooandee-eclipse` |
| Nombre visible | **Eclipse** (es/en/it) |
| Autor | **Hooandee** (GitHub: `Hooandee`) |
| Versión | **0.2.5** (única publicada en el catálogo oficial) |
| Descripción (en) | *"A theme inspired by space and eclipses. Your games become planets over a truly black background, with stars and a soft glow on whatever you have selected. Made for OLED screens"* |
| Target | `System-Wide` (bigpicture + QuickAccess + MainMenu + notificationtoasts.*) |
| Manifest CSS Loader | `manifest_version: 9` |
| Requisitos mínimos | CSS Loader **≥ 2.1.2**, `cssLoaderBackend ≥ 9`, Panel de Control **≥ 0.56.0** |
| Artefacto | `theme.zip` — 62 848 bytes — SHA-256 `c8da01e28119eae00f9a05148f756a9a43fc3b03635de1c90e95f8e6c1fe7e43` ✅ verificado |
| Licencia | **NO declara licencia** (no hay LICENSE dentro del zip ni en el repo `Hooandee/hooandee-themes`; el repo `Hooandee/panel-de-control` es GPL-3.0 pero es otra obra). Es tema de terceros: **sin licencia explícita = "all rights reserved"** — se puede usar para uso personal propio, no redistribuir. |

### Ficheros que contiene (53, ~208 KB desempaquetado)
Carpeta raíz `Hooandee Eclipse/` con:
- `theme.json` — descriptor CSS Loader (inject map + 12 patches configurables).
- `panel-theme.json` + `panel-extension.js` — integración con el plugin **Panel de Control** (ABI v2): etiquetas localizadas de los patches y la extensión que hace el *orbit* interactivo (los juegos como planetas con menú de lanzar/reanudar/detalles/ajustes).
- CSS por superficies: `home.css` (pantalla principal/carrusel), `library.css`, `details.css`, `settings.css`, `qam.css` (menú rápido), `main-menu.css`, `system.css`, `friends.css`, `surfaces.css`, `windows.css`, `storage.css`, `notifications.css`, `controls.css`, `plugins.css`, `avatars.css`, `header-icons.css`, `rings.css`, `orbit.css`, `starfield.css`, `twinkle.css`, `cosmos.css`, `tokens.css` (variables), `options/` (12 variantes de patches: acentos de 8 planetas, corona, motion, estrellas, header/footer…).

### Qué hace visualmente
- Negro OLED absoluto (`--ecl-void: #000`), luz solo donde hay foco.
- Home: los juegos recientes son **planetas** en un carrusel circular animado sobre un fondo de estrellas con luna y horizonte.
- Acento por defecto "Venus" (verde `rgb(95,242,176)`), configurable (8 planetas).
- Patches: ahorro OLED, corona de foco, movimiento, estrellas titilantes, contenido de header/footer, iconos, etc.

---

## 2. De dónde sale y cómo se descarga

Catálogo oficial del plugin **Panel de Control** (`Hooandee/panel-de-control`, hoy v0.63.0):

- Lista: `https://hooandee.github.io/panel-de-control/themes/v1/catalog.json`
  (solo 3 temas oficiales: `hooandee-eclipse` 0.2.5, `hooandee-gallery` 0.9.55, `hooandee-luminous-atlas` 1.1.2).
- Paquete: `https://hooandee.github.io/panel-de-control/themes/v1/hooandee-eclipse/0.2.5/theme.zip`

La URL y el formato los confirman `py_modules/theme_remote.py` / `theme_remote_contract.py` / `main.py` del panel (`_OFFICIAL_THEME_CHANNEL`, `pages_base_url=…panel-de-control`, `catalog_path=themes/v1/catalog.json`).

El zip se validó contra el `sha256` del catálogo. **Descarga ya hecha y guardada** (ver §7).

> Nota: el repo `Hooandee/hooandee-themes` ("Temas para CSS Loader de Decky") **no contiene el tema Eclipse**: solo aloja "Hooandee Gallery" (un tema que muestra una galería de temas dentro de CSS Loader). La fuente autoritativa de Eclipse es el catálogo del panel.

---

## 3. CSS Loader (el plugin que carga estos temas)

| Campo | Valor |
|---|---|
| Plugin | **CSS Loader** de **DeckThemes** (repo `DeckThemes/SDH-CssLoader`) |
| Último release estable | **v2.1.2** (2024-07-07) — coincide EXACTAMENTE con el mínimo que pide Eclipse (2.1.2) |
| Backend | `CSS_LOADER_VER = 9` → `get_backend_version()` devuelve 9 → cumple `cssLoaderBackend ≥ 9` ✅ |
| Artefacto Decky | `SDH-CSSLoader-Decky.zip` (188 KB), carpeta raíz `SDH-CssLoader/` (plugin 100 % Python + JS, **sin binarios nativos**) |
| Licencia | GPL-3.0 |
| Fecha de hoy | el repo tiene commits hasta oct-2026 en `main`, pero **no hay release nuevo desde v2.1.2**; ojo con build de rama (no oficial) |

### ¿Es viable en la Odin (Decky, ARM64)? — SÍ, con condiciones
- **Arquitectura**: el plugin es **Python puro + frontend JS** (`css_browserhook.py`, `css_inject.py`, `css_loader.py`, `css_theme.py`, …). No hay `.so`/`.dll` nativos que compilar: **ARM64 no es obstáculo**. (En la Odin Decky corre vía FEX x86 desde `/home/deck/homebrew/`; los plugins Python siguen funcionando igual.)
- **Mecanismo de inyección**: se conecta al **puerto de depuración CEF de Steam** (`http://127.0.0.1:8080/json/version` → WebSocket, protocolo CDP) e inyecta `<style>` por `Runtime.evaluate`. Depende de que Steam tenga activo el remote-debugging: el plugin crea el flag `~/.steam/steam/.cef-enable-remote-debugging` (lo hace al activar el "server" interno; en la Deck está siempre). **En la Odin hay que asegurarse de que exista ese flag** (paso 1 del plan de instalación) y de que Steam se lanza con gamepadui — cosa que ya hace (`pocknix-steam` usa `-gamepadui -steamos3 -steampal -steamdeck`, ver `docs/POCKNIX-EXPERIENCE.md`).
- **"Mappings" de clases**: el plugin baja `https://api.deckthemes.com/stable.json` → `~/homebrew/themes/css_translations.json` y **reescribe las clases hash del tema** a los nombres que usa la versión de Steam instalada. Verificado hoy: las 6 clases clave del tema (p. ej. `_2_cRkGdbegoIbiRsy_-I7`, `_282X0J4BtrSF1IXctmOe-X`, `_1pwP4eeP1zQD7PEgmsep0W`) están en las mappings (14 929 entradas) → el mecanismo anti-rotura aplica.
- **Punto crítico real**: no es ARM64, es que la versión del cliente Steam de la Odin esté cubierta por las mappings (comunidad) y que el DOM del gamepadui en un handheld no-Deck coincida con el de la Deck en las superficies que toca el tema (Home, Biblioteca, QAM, Ajustes, amigos, notificaciones).

### Instalación del plugin (en la Odin, cuando vuelva)
1. `~/homebrew/plugins/` es el raíz de plugins de Decky en la Odin (`/home/deck/homebrew/`).
2. Opción A: Decky → engranaje → *Install from file* → `SDH-CSSLoader-Decky.zip`.
3. Opción B (fácil): el plugin está en la **tienda de Decky** (Store → "CSS Loader").
4. Opción C (copia manual): descomprimir como `~/homebrew/plugins/CSSLoader` (o `SDH-CssLoader`, como viene el zip) y reiniciar Decky.
5. Comprobar en el QAM que aparece "CSS Loader" y que conecta con Steam (log: "Connected to tab: …").
6. Asegurar el flag de debugging: `touch /home/deck/.steam/steam/.cef-enable-remote-debugging` (+ reiniciar Steam una vez).

---

## 4. Análisis del CSS del tema: selectores y fragilidad

### Selectores que usa (del DOM de Steam)
- **Estables (IDs de nivel superior)**: `#Main`, `#QuickAccess-Menu`, `#QuickAccess-NA`, `#MainNavMenuContainer`, `#GamepadUI_Full_Root`, `#header`, `#Footer`, `#MainNavMenu-Rest`. Estos son muy estables en el cliente.
- **Roles ARIA estables**: `[role="menu"]`, `[role="menuitem"]`, `[role="grid"]`, `[role="tab"]`, `[role="link"]`, `[role="listitem"]`, `[role="button"]`, `[role="heading"]`. Uso extenso → robusto.
- **Clases con nombre de módulo (semi-estables)**: `quickaccessmenu_Tabs_3Ag1w`, `gamepadpagedsettings_PagedSettingsDialog_2P_CG`, `basicgamecarousel_TextBoxCarouselContents_3bvCH`, `appdetailsprimarylinkssection_Anchor_DY4_w`, etc. El prefijo es estable; el sufijo hash cambia con cada build de Steam (lo mitigan las mappings de deckthemes).
- **Clases 100 % hash de CSS modules (FRÁGILES)**: `._2_cRkGdbegoIbiRsy_-I7` (raíz Home), `._282X0J4BtrSF1IXctmOe-X` (sección juegos recientes), `._1pwP4eeP1zQD7PEgmsep0W` (items del carrusel), `._1R9r2OBCxAmtuUVrgBEUBw`, `._2BOmkMg4r689AAjdLObYs2`, `._3VOR2AeYATx3qSE0I-Pm-5`, `._3IBLc81yyL08OJ7rfKtF00` (tabs), etc. **Cambian en cada actualización de Steam**; sin las mappings se rompería (fondos y carrusel fuera de sitio). Es la fragilidad nº 1, mitigada por el sistema de mappings + reediciones del autor.
- **Selectores propios del tema**: `[data-pdc-ecl-orbit]`, `--ecl-*` (no dependen de Steam; los crea `panel-extension.js`).

**Conclusión fragilidad**: riesgo MEDIO. Las superficies más frágiles son Home (carrusel) y QAM por las clases hash; el resto es bastante estable. Mitigaciones: mappings automáticas de DeckThemes + reediciones del autor (el tema se actualiza vía catálogo del panel). **Si Steam de la Odin se actualiza y algo se descuadra, la respuesta correcta es esperar actualización del tema/mappings, no parchear a mano.**

### Unidades y escala
- **0 media queries** en todo el tema. Se adapta por **unidades relativas**: 93 usos de `vw/vh` (7 ficheros: sistema, órbita, home, detalles, cosmos, main-menu, saving-normal) + el resto de tamaños viajan en variables `--ecl-*` con `calc()`.
- px fijos que aparecen: `42px` (offset fila carrusel), `17px` (tipografía menú), `11px` (etiquetas), `1040px` (max-width ajustes), `1800px` (radio dial decorativo QAM), `4000px`/`130vh` (elipses de fondo). El resto de los "999px" que salen en un grep son `border-radius: 999px` (píldoras), no layout.
- CSS moderno usado: `view-timeline`/`animation-timeline`/`timeline-scope`, `translate`/`scale` individuales, `mask-image`, `@keyframes` con timeline. Requiere el CEF/chromium del cliente Steam actual (2024+); en el Steam 2026 de la Odin no debería haber problema.

---

## 5. Plan de adaptación a 1080p (y cómo NO romper nada)

Contexto: el tema se diseñó para 1280×800 (Deck). La Odin es 1920×1080.

- **Caso A (probable) — gamepadui con viewport lógico 1280×800 escalado**: Steam Deck, y casi todo handheld con `-gamepadui`, renderiza el UI en resolución lógica y lo escala. En ese caso **el tema funciona sin tocar nada**: sus `vh/vw` son relativos al viewport lógico. Es lo primero que hay que comprobar en la Odin (cómo se ve de primeras con el tema activado).
- **Caso B — viewport CSS real 1920×1080**: los `vh/vw` crecen un ~35 % y los px fijos quedan pequeños. Ajustar, en este orden:
  1. Revisar las variables de geometría de Home (`--ecl-home-horizon 71vh`, `--ecl-home-moon 13vh`, `--ecl-home-moon-lit 20vh`, `--ecl-home-headroom 6.5vh`, `--ecl-home-row-offset 42px`, `--ecl-home-dawn 40vh`).
  2. Revisar el radio del dial del QAM (`--ecl-qdial-r: 1800px`) y los tamaños del orbit (`--ecl-orbit-size: min(46vh, 30vw)`).
  3. Tipografías fijas (`17px`, `11px`) si quedan pequeñas.
  4. El **carousel** (juegos recientes) es la pieza más delicada: la animación orbital `ecl-orbit` y el `view-timeline` están pensados para 8 px/vh; en 1080p native el arco se hace más grande — normal, pero conviene mirarlo.
- **Herramienta de ajuste preparada**: tema compañero `ZZZ Eclipse Odin 1080p` (carpeta + `theme.json` + `override.css` de plantilla con los knobs comentados). Se copia a `~/homebrew/themes/`, se activa después de Eclipse en CSS Loader, se edita el CSS y el watchdog recarga en caliente. El prefijo `ZZZ` garantiza que se inyecta al final y gana la cascada con `!important`. **No hace nada por defecto** (todo comentado) → riesgo cero si no se toca.
- **Previsualización previa en el PC (sin tocar la Odin)**: descargado `CSSLoader.Desktop_1.2.1.AppImage` (76 MB, GPL-3.0, el visor oficial de DeckThemes). Con el Steam del PC en Big Picture se puede inyectar el tema y verlo en 1080p antes de tocar nada. (El PC es la mejor "maqueta" porque Steam ya está instalado; ver §7.)
- **Enfoque de despliegue seguro** (cuando la Odin vuelva):
  1. Instalar CSS Loader (zip) → activar → verificar logs.
  2. Copiar `Hooandee Eclipse/` a `~/homebrew/themes/` (por defecto viene **desactivado**, el plugin no lo enciende solo).
  3. Activar desde el QAM de CSS Loader; revisar Home, Biblioteca, QAM, Ajustes, notificaciones; capturar fotos.
  4. Si algo se ve mal: desactivarlo desde el QAM al instante (ver §6). Solo si además se quiere la experiencia completa (menú órbita al pulsar un juego), instalar el plugin Panel de Control y activar el tema desde ahí.

---

## 6. Cómo se revierte (si algo se ve mal)

### Desde Decky (lo más rápido)
- **CSS Loader** en el QAM: toggle del tema "Hooandee Eclipse" → OFF. Se reinyecta al momento (elimina los `<style>`).
- Aún más rápido si hace falta: **desactivar el plugin CSS Loader entero** (QAM → engranaje de Decky → CSS Loader → desactivar) o reiniciar Steam para quitar los estilos.
- Panel de Control (si se usó esa ruta): el panel gestiona activación/desactivación del tema; si la activación va mal tiene **journal de recuperación** (`theme-activation-recovery.json` en los settings del plugin) y **cuarentena** (`.panel-theme-quarantine-*`): revierte solo.

### A mano (ficheros exactos que se tocan)
Todo vive en la carpeta de temas de Decky de la Odin: **`/home/deck/homebrew/themes/`** (DECKY_HOME).
- Tema: `/home/deck/homebrew/themes/Hooandee Eclipse/` (si se borra o renombra la carpeta, desaparece de CSS Loader).
- Estado activo del tema: `/home/deck/homebrew/themes/Hooandee Eclipse/config_USER.json` (o `config_ROOT.json`) → `{"active": true, "<patch>": "<valor>", …}`. **Poner `"active": false` (o borrar el fichero) = revertir manual.** CSS Loader lo relee con el watchdog; si no, reiniciar el plugin.
- Mappings (no tocar, se regeneran): `/home/deck/homebrew/themes/css_translations.json`.
- Flag de debugging (no rompe nada, solo activa el puerto CEF): `/home/deck/.steam/steam/.cef-enable-remote-debugging`.
- Symlink que crea el plugin (iconos `/themes_custom/...`): `~/.steam/steam/steamui/themes_custom → ~/homebrew/themes`.
- Otros temas activos: cualquier otro tema de CSS Loader puede interferir; si hay varios, desactivar todos salvo el que se prueba.

### Restaurar estado original
1. CSS Loader: apagar el tema (toggle) → ya está.
2. Si se quiere "cero rastro": parar Decky (`pocknix-decky-loader`), borrar `homebrew/themes/Hooandee Eclipse`, borrar el `config_*.json`, arrancar de nuevo.
3. Nada de esto toca el sistema, los juegos ni el Steam; el tema es solo CSS inyectado en el webhelper y un plugin desactivable.

---

## 7. Qué se ha dejado preparado en el PC

Centro: `~/pocknix-odin3-project/pocknix-odin3-support/` (repo git del proyecto, rama `master`).

```
docs/THEME-ECLIPSE-ODIN.md                                  ← este documento
reference/themes/theme-eclipse/
├── theme/
│   ├── theme.zip                                           ← eclipse 0.2.5 verificado (sha256 ok)
│   └── Hooandee Eclipse/                                   ← desempaquetado (53 ficheros)
├── catálogo/catalog-20261007.json                          ← snapshot del catálogo oficial
├── css-loader-plugin/
│   ├── SDH-CSSLoader-Decky.zip                             ← CSS Loader v2.1.2 (plugin Decky)
│   └── SDH-CssLoader/                                      ← desempaquetado (código fuente Python)
├── assets/eclipse-cover.jpg                                ← portada oficial del tema
├── extra/
│   ├── snapshot-mappings/css_translations-stable-20261007.json  ← mappings deckthemes (14 929)
│   └── preview-desktop/CSSLoader.Desktop_1.2.1.AppImage    ← visor oficial (preview en PC)
└── companion/ZZZ Eclipse Odin 1080p/                       ← plantilla de ajuste 1080p
    ├── theme.json
    └── override.css                                        ← knobs comentados (no-op por defecto)
```

También queda una copia de trabajo del análisis en `/tmp/opencode/theme-eclipse/` (clones shallow de `panel-de-control`, catálogo, cssloader, mappings).

> ⚠️ No se ha instalado nada en la Odin (está caída) ni se ha tocado `~/windwaker-hd/` ni `pocknix-os`.

---

## 8. Valoración honesta (¿merece la pena? ¿qué se puede romper?)

**¿Merece la pena?** Sí, como experimento de bajo riesgo: es 100 % reversible (CSS inyectado + plugin desactivable), no toca sistema ni juegos, y el resultado es espectacular en OLED/negra — que es justo el tipo de pantalla de la Odin 3. El coste real es tiempo de prueba y ajuste fino.

**Probabilidad de que funcione bien a la primera: media-alta (~70 %).** A favor: mismo UI (gamepadui con `-steamdeck`), mappings cubriendo las clases del tema, plugin sin dependencias nativas, tema reciente (0.2.5, actualizado vía catálogo). En contra: la Odin no es una Deck (DOM de Home/tienda puede diferir en detalles), 1080p vs 800p, y Steam del handheld se actualiza con clases hash nuevas.

**Qué se puede romper (y qué no):**
- NO se rompe: sistema, Steam, juegos, saves, el propio Decky. El plugin solo inyecta CSS y es desactivable.
- SÍ se puede *ver* raro (cosmético): carrusel de Home descentrado/cortado, tipografías pequeñas, iconos del header que no cargan, QAM con radios raros, solapamiento con otros temas. Nada de eso deja la interfaz inutilizable: se desactiva el tema y vuelve todo.
- Riesgo operativo pequeño: el flag `.cef-enable-remote-debugging` abre el puerto 8080 de CEF en local (solo 127.0.0.1); es el mismo mecanismo que usa la Deck. Aceptable; se puede quitar el flag tras probar.
- **Riesgo de una actualización de Steam**: las clases hash cambian; las mappings automáticas y las reediciones del tema lo cubren con retraso (días). Si un día el tema se descuadra tras un update, lo correcto es desactivarlo y esperar reedición.
- **Dependencias**: la experiencia "planetaria" completa (menú órbita al pulsar un juego) la añade `panel-extension.js` y **solo se ejecuta si está instalado el plugin Panel de Control** (que además corre con privilegios y toca TDP/voll, *otra* decisión aparte). Sin el panel, el tema luce igual en Home/QAM/Ajustes pero sin el orbit interactivo.

**Expectativas a vigilar:** el autor lo describe "pensado para pantallas OLED"; en una pantalla LCD/IPS el negro puro no luce igual y los halos pueden perderse. Y es un tema, no un cambio de rendimiento: si se ve lento, el patch "Movimiento" se puede apagar.

---

## 9. Referencias
- Catálogo de temas (panel): `https://hooandee.github.io/panel-de-control/themes/v1/catalog.json`
- Tema: `https://hooandee.github.io/panel-de-control/themes/v1/hooandee-eclipse/0.2.5/theme.zip`
- Panel de Control: `https://github.com/Hooandee/panel-de-control` (GPL-3.0; hoy v0.63.0)
- Temas de Hooandee (solo la Gallery): `https://github.com/Hooandee/hooandee-themes` (sin licencia)
- CSS Loader: `https://github.com/DeckThemes/SDH-CssLoader` (GPL-3.0; v2.1.2 release)
- Visor de escritorio: `https://github.com/DeckThemes/CSSLoader-Desktop` (GPL-3.0; v1.2.1)
- Mappings: `https://api.deckthemes.com/stable.json`