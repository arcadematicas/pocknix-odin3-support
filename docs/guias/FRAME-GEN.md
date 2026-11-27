# Frame generation (MAKO) — guía de usuario

**Qué es**: la consola genera **frames intermedios** entre los que dibuja el juego, para que se
vea más fluido sin subir los FPS reales. Ejemplo típico: un juego a 30 fps se ve a ~60.

Se hace con **MAKO**, integrado en el **Panel de Control**. No hay que instalar nada fuera de él.

---

## Requisitos

- Juego con **Vulkan en aarch64**: ports nativos ARM64 (Wind Waker HD, decomps nativos) o juegos
  bajo **Proton ARM64**. Los juegos **x86 puros bajo FEX** no entran.
- Conexión a internet la primera vez (el panel descarga el Renderer ARM64, ~11 MB).

## Activarlo en un juego

1. Abre el **QAM → Panel de Control → juegos** y elige el juego.
2. Entra en **Frame generation** (o *Upscaler and models*) → **MAKO** → **Instalar** si es la
   primera vez.
3. Ajustes recomendados para empezar:
   - **Multiplicador 2** (si el juego va a ~30, lo deja en ~60).
   - **Modo fixed** con objetivo 60, o **adaptive** si tu pantalla no es múltiplo exacto.
   - **MAKO FG mode: balanced**.
   - **Escalado: apagado** en la primera prueba (mejor una variable cada vez).
4. **Guardar**. El panel pone las opciones de lanzamiento con `mako-launch`; después solo hay que
   lanzar el juego como siempre (modo juego).

## Los dos motores (importante)

MAKO es **una** capa, pero trae **dos** motores de frame generation:

| Motor | Nombre en el panel | ¿Necesita `Lossless.dll`? |
|---|---|---|
| **MAKO FG** (motor 5) | por defecto | **No** (lleva su propio modelo) |
| **LSFG** (motor 4) | hay que forzarlo | **Sí** (tu Lossless Scaling de Steam) |

- **MAKO FG** es el que usa el panel en ARM. Es el más sencillo: no depende de nada externo.
- **LSFG** es el motor de **Lossless Scaling**. Si tienes el juego en Steam, el panel busca
  `steamapps/common/Lossless Scaling/Lossless.dll`. Para probarlo hay que lanzar el juego con
  `MAKO_FRAME_GENERATION_MODEL=lossless-scaling` en el entorno (el panel escribe
  `frame_generation_model = "mako-fg"` en el perfil).

> La sección **“Lossless”** del Panel es **otra capa** (`lsfg-vk`) y pide `lsfg-vk.dll` (rama beta
> de Lossless Scaling). No es lo mismo que el LSFG de MAKO y no hace falta para nada de esto.

## Escalado (opcional)

MAKO también escala imagen (factor, nitidez). Es independiente del frame generation: si vas a
comparar FG, **apágalo** en esa prueba.

## Qué esperar

- **Más fluidez**, no más FPS reales: el contador de Steam (que cuenta presentaciones) sube; el
  juego sigue simulando a la misma tasa.
- **Algo más de latencia** y, en textos/HUD, un leve *ghosting* al mover cámara. Es normal.
- Si el juego ya va a 60 estables, el FG aporta poco; brilla en juegos de 30.

## Problemas comunes

| Síntoma | Qué mirar |
|---|---|
| “MAKO no está disponible en esta arquitectura” | Panel viejo (0.94.x) o parche aarch64 sin aplicar. Actualiza el panel y reinicia el loader. |
| No aparece la sección de frame generation | El panel solo la muestra por juego: activa los ajustes por juego. |
| Se activa pero no cambia nada | El juego no es Vulkan aarch64 (x86 bajo FEX), o el lanzamiento no pasa por `mako-launch`. Mira las opciones de lanzamiento del juego. |
| Tirones o artefactos | Baja el multiplicador a 2, modo balanced, y prueba sin escalado. |

Detalle técnico y estado del proyecto: [`../FRAME-GEN-ARM.md`](../FRAME-GEN-ARM.md).
