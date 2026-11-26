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
   sha256 `PENDIENTE_CALCULAR`, 11.218.307 B.
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
