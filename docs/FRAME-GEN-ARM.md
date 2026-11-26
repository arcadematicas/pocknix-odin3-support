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

## Pendiente

- Probar de verdad en la Odin (WWHD, 30→60) y medir input lag/pacing.
- Decidir si se empaqueta como `calvos-mako-arm64` (ojo: el binario de MAKO FG es CC BY-NC,
  uso no comercial; las capas GPL-3.0).
- Añadirlo al vigilante (release nueva de `mako-arm64`).
