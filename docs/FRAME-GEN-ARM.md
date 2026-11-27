# Frame generation en ARM (aarch64) — estado 26/11/2026

## Resumen

- **MAKO upstream no tiene ARM** y su autor lo dice claro (issue #60, 15/11): *"no estoy
  trabajando en esto; me gustaría que lo hiciera alguien que use AArch64 de verdad; estoy
  esperando a la comunidad"*. No es un "aún no": es un "que lo haga otro".
- **Sí existe un port de la comunidad**: [Ken5998/mako-arm64](https://github.com/Ken5998/mako-arm64)
  (16/11, GPL-3.0). Compila el **Renderer de MAKO v5.0.0 para aarch64** y lo empaqueta con el
  instalador oficial. 79/82 tests de upstream pasan en aarch64.

## Qué funciona ahí (según su matriz, sobre ArmadaOS)

| Función | Estado |
|---|---|
| **LSFG Quality/Performance** | **Nativo** dentro del layer. Necesita tu **Lossless Scaling** (Steam). |
| MAKO Scaler | Nativo |
| LS1 scaling | Nativo (con Lossless Scaling) |
| **MAKO FG** | **Experimental**: corre un programa **x86-64** por FEX y llega a la GPU por el thunk Vulkan del host |
| vkBasalt / shaders | Todavía no |
| MangoHud vía `mako-launch` | Todavía no (el overlay de Steam no se toca) |
| Plugin Decky de MAKO | No (upstream lo desactiva en ARM a propósito) |

## A quién cubre

El layer entra **en el proceso del juego**, así que sirve a juegos cuyo **Vulkan es aarch64**:
**ports nativos ARM64** y **juegos bajo Proton ARM64** (Vulkan thunkeado al host).
**No** cubre juegos x86 de Linux que corren enteros bajo FEX con su propio stack Vulkan x86.

## Nuestro caso

- **Wind Waker HD (wwhd)**: port nativo aarch64 con Vulkan → **candidato ideal** para LSFG.
- Dolphin/RetroArch (Vulkan nativo) → también.
- Juegos de Steam con Proton ARM64 → deberían entrar; los x86 puros bajo FEX, no.

## Instalación (probada a medias el 26/11)

1. Modo escritorio, extraer `MAKO-Renderer-v5.0.0-linux-arm64.tar.gz` (ya copiado a
   `~/Mako/` en la Odin).
2. Ejecutar **Install MAKO Renderer** (copia a `~/.local`, conserva perfiles) y abrir
   **MAKO Renderer Configuration**.
3. Perfil por juego y, en las opciones de lanzamiento: `mako-launch %command%`.

Requisitos en runtime: Vulkan 1.3+ (Turnip), Qt6 Quick/Qml para la configuración (Plasma
Mobile lo trae). Las capas enlazan su propio libstdc++ oculto: no chocan con el del juego.


## Integración en el Panel de Control (Hooandee) — sí, es el sitio natural

El panel ya tiene `py_modules/upscalers/mako.py`: instala MAKO en su propio prefijo
(`~/.local/share/panel-de-control/mako/5`), guarda perfiles por juego y los aplica con un
wrapper (`MAKO_LAUNCH_CONFIG` + `bin/mako-launch`). Lo que no sabe es que existe una build
aarch64: su `Asset` es el tarball x86 y su `PAYLOAD` exige `lib32/libmako-render.so` y
`VkLayer_MAKO_render.x86.json`, que en ARM no existen.

Cambios necesarios (patch a `panel-de-control/py_modules/upscalers/mako.py`):

1. **Elegir asset por arquitectura**: si `platform.machine()` es `aarch64`/`arm64`, usar
   `MAKO-Renderer-v5.0.0-linux-arm64.tar.gz` de `Ken5998/mako-arm64` (v0.1.0),
   sha256 `3bace05df3c99508f84f403d7a6585de6e2351411bde6fc844141e1e1c854aad`, 11.218.307 B.
2. **PAYLOAD aarch64** = el de v5 **sin** `lib32/libmako-render.so` **ni**
   `share/.../VkLayer_MAKO_render.x86.json` (el tarball ARM trae un único JSON).
3. **Motor por defecto en ARM: 4 (LSFG)** — es el nativo; el motor 5 (MAKO FG) usa
   `lib/mako-fg/mako-fg-host`, que es **x86-64** y solo corre por FEX (experimental).
4. **Detección de "foreign"**: el panel se niega a gestionar si existe
   `~/.local/bin/mako-launch` (instalación standalone). Si se integra en el panel, **no** se
   instala el tarball a mano.

Extra: en `pocknix-control/py_modules/pocknix_control/mako.py` (`mako_status()`), aceptar
también el prefijo del panel como "instalado", para que el toggle por juego de PocknixControl
aparezca cuando el panel lo haya instalado.

Ojo: `packages/pocknix-decky/mako-aarch64.patch` fuerza hoy a **MAKO's Decky plugin** a
instalar el renderer x86 en ARM (por eso no funcionaba). Cuando el panel gestione la build
aarch64, ese parche debe retirarse y dejar un solo instalador.

Mejor aún: proponerlo upstream a Hooandee (es su plugin) con este mismo parche.

## Pendiente

- Probar de verdad en la Odin (WWHD, 30→60) y medir input lag/pacing.
- Decidir si se empaqueta como `calvos-mako-arm64` (ojo: el binario de MAKO FG es CC BY-NC,
  uso no comercial; las capas GPL-3.0).
- Añadirlo al vigilante (release nueva de `mako-arm64`).

## Syluxium Motion (motor de LiquidFrames) — validado en Turnip (27/11/2026)

LiquidFrames es una app **cerrada y solo x86_64**, pero su motor **Syluxium Motion** es **MIT,
C++20 y Vulkan 1.2+** y se compila para aarch64.

**Compilación en la Odin** (nativo, sin parches):

```
[13/13] Linking CXX static library libsyluxium-motion.a
```

Los 9 shaders `flow_*` compilan con `glslc`; Turnip expone lo que pide
(`timeline_semaphore`, `external_memory_fd`, `external_semaphore_fd`, `synchronization2`).

**Prueba funcional** (banco propio con la API `testUpload/testDownload`, 320x180, dos frames con
un bloque desplazado 24 px, `generated=1`):

```
format=37 (RGBA8) dispatches=15
out=57600 px mean=89.1 min=10 max=240  wall=49 ms
```

El frame generado coloca el bloque a **8 px** (A=0, B=24) y difiere de un cross-fade 50/50 en
**46 niveles de media**: interpola movimiento, no mezcla. `lastGpuMs()` da 0 (sin perfil de GPU;
usar `SYLUXIUM_MOTION_GPU_PROFILE=1` para medirlo).

**Qué falta para usarlo en juegos**: el motor no captura ni presenta frames. Hace falta una **capa
Vulkan** (o app) que:
1. intercepte `vkQueuePresentKHR` y copie el frame a `ctx.input(k % 2)` (la API tiene
   `exportable`, `exportInput/exportOutput/exportTimeline/exportConsumed` justo para compartir
   imágenes y semáforos por fd con el VkDevice del juego, sin copias);
2. llame a `ctx.submit(k)` (o `submit(k, count, times)` para pacing adaptativo);
3. presente los `ctx.output(i)` en cadencia.

Atajo posible: partir de la capa del port comunitario de MAKO (`Ken5998/mako-arm64`, GPL) y
sustituir su motor de FG por Syluxium Motion. Sigue siendo un proyecto (sincronización y pacing),
no un ajuste.

## MAKO 4 / LSFG en aarch64: no es posible (y el error `mako_not_installed`)

MAKO 4 hace la generación de fotogramas con **`Lossless.dll` de Lossless Scaling**, que es un
binario **x86 de Windows**: un proceso aarch64 no puede cargarlo. En ARM solo existe el renderer
de la **línea 5** (modelo propio `mako-fg`, asset `Ken5998/mako-arm64`).

Por eso el panel, en ARM:

- pone `engine = 5` por defecto (`DEFAULTS`);
- convierte motor 4 → 5 al **arrancar** (`_engine_of`);
- instala siempre la línea 5 aunque se pida la 4 (`install`);
- pero al **guardar el perfil** validaba la línea 4 → `mako_not_installed` al elegir "LSFG" en la UI.

Arreglo (27/11/2026): `save` también convierte 4 → 5 en ARM. Está en
`overlay/usr/local/bin/pocknix-panel-control-patch` (`ensure_engine4_coercion`), que se ejecuta al
instalar/actualizar el plugin y es idempotente; deja `mako.py.bak-engine4` al aplicar. Con eso,
elegir LSFG en la Odin guarda un perfil de MAKO 5 en vez de fallar.

> `mako-cli inspect-dll` y `benchmark` sí pueden analizar la DLL en ARM (compatibilidad estructural
> del modelo), pero eso no habilita el motor 4: no hay renderer v4 para aarch64.
