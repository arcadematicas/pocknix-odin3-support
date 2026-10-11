# RENDIMIENTO — tirones por compilacion de shaders (PENDIENTE, sin hacer)

**Decidido por Fransis (11/10/2026): se apunta como posible mejora, pero NO se toca por ahora.**

## El problema
Tirones ("shader compilation stutter") al entrar en zonas nuevas / primera ejecucion.
Es el mismo problema que ataca **SCSKiller** en Windows (precompilar/reproducir las
pipelines y llenar la cache del driver antes de jugar):

- SCSKiller (Windows, D3D12/D3D11): graba las pipelines del juego y las precompila en la
  cache del driver; tiene "recorder", deteccion de anti-cheat, UI.
- https://github.com/BlueHeisenberg/SCSKiller

## Equivalentes en Linux (no hay uno unico)
| Pieza de SCSKiller | En Linux |
|---|---|
| Grabar pipelines | **Fossilize** (ValveSoftare/Fossilize), capa Vulkan -> `.foz` |
| Precompilar/calentar la cache | **`fossilize-replay`** (llena la `VkPipelineCache` sin ejecutar el juego) |
| Caches persistentes | **DXVK** (`~/.cache/dxvk`), **vkd3d-proton** (`~/.cache/vkd3d-proton`), **Mesa** (`MESA_SHADER_CACHE_*`), NVIDIA `~/.nv/ComputeCache` |
| Caches ya hechas (descarga) | **Steam -> Pre-cache de shaders** (usa Fossilize; pensado para Steam Deck/x86) |
| Evitar el tiron mientras compila | **DXVK**: `dxvk.enableGraphicsPipelineLibrary` (GPL) · fork **`dxvk-gplasync`** (compilacion asincrona) |
| Todo en uno | **`nvshader`** (GhostKellz, Linux/Zig): prewarm + watch + export/import + Steam Deck. **NVIDIA + x86_64** |

## OJO: estamos en ARM
Odin 3 = ARM64 + **Turnip/freedreno**; los juegos x86 pasan por **FEX** -> DXVK/vkd3d -> Turnip.
Asi que:
- APLICABLE: caches persistentes de DXVK/vkd3d + cache de Mesa (`MESA_SHADER_CACHE_MAX_SIZE`).
- PROBABLEMENTE NO: `nvshader` (NVIDIA), pre-cache de Steam (Deck/x86), `dxvk-gplasync` (hay que
  ver si compila en aarch64/FEX y si rompe anti-cheats).

## Plan de pruebas propuesto (cuando se retome)
1. **Inventario** (sin jugar): tamano/estado de `~/.cache/dxvk`, `~/.cache/vkd3d-proton`,
   `~/.cache/mesa_shader_cache`, `steamapps/shadercache/<appid>`; env/config actuales.
2. **Frio vs caliente** en un juego con tirones: MangoHud a CSV (frametimes) + `DXVK_HUD=compiler`
   (cuenta compilaciones de pipeline) -> decidir si el tiron es de SHADERS o de FEX/CPU.
3. **Mitigaciones por coste**: (a) `dxvk.enableGraphicsPipelineLibrary` en `dxvk.conf` (cero coste);
   (b) `MESA_SHADER_CACHE_MAX_SIZE`; (c) `dxvk-gplasync` aarch64; (d) pre-warm con `fossilize-replay`.
4. Si mejora -> dejarlo por defecto (paquete/env) + entrar en la siguiente imagen con numeros A/B.

## Requisitos para empezar
- Juego concreto que muestre tirones (lo elige Fransis).
- Dispositivo: la SD de 1 TB (tiene los juegos y el WProton nuevo).
