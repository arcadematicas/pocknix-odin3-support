# Deckard `release/0.5.x` — integración y pruebas (09-oct-2026)

## Qué trae la 0.5.x (nuevo, publicado hoy) vs la 0.4.x que probamos
| Paquete | 0.4.x | **0.5.x** | ¿Aplica a la Odin? |
|---|---|---|---|
| `deckard-mesa-linux-aarch64` (Turnip) | `26.3.0_devel+gitabc426bb` | **`gite07916b4`** | Solo **prueba** (per-game), NO se toca nuestra mesa |
| `deckard-vulkan-layers` | `20260923.1` | **`20261001.1`** | ✅ (aditivo) |
| `deckard-audio-config` (UCM/LV2) | `20260914.1` | **`20261007.1`** | ❌ (altavoces del Frame; la nuestra es más completa) |
| `deckard-hw-support` | `20260911.1` | `20260916.2` | ❌ (sysctls ya cubiertos) |

Base 0.5.x: `https://holo-packages.steamos.cloud/archlinux-deckard-hotfixes/release/0.5.x/`
Copia local: `~/deckard-paquetes/0.5.x/` (PC).

## Hecho en la Odin (09-oct)
- ✅ **Layers Vulkan INSTALADAS**: `deckard-vulkan-layers-linux-aarch64 20261001.1-1`
  (`libVkLayer_VALVE_rpo.so` + `libVkLayer_VALVE_fdm_injection.so` + `libVkLayer_fossilize.so` + json).
  *(Los `.sig` del repo dan "signature format error"; con `LocalFileSigLevel=Optional` se instala quitando el `.sig`.)*
- ✅ **Mesa de Valve EXTRAÍDA** (NO instalada) en `~/deckard-0.5.x/valve-mesa/` + **ICD de prueba**
  `~/deckard-0.5.x/valve-turnip-icd.json` (apunta a `valve-mesa/usr/lib/libvulkan_freedreno.so`).
- ✅ **Carga verificada**: `VK_ICD_FILENAMES=~deckard-0.5.x/valve-turnip-icd.json vulkaninfo --summary`
  → `driverInfo = Mesa 26.3.0-devel (git-e07916b45f)`, Adreno 830, api **1.4.362**, `turnip Mesa driver`.
  *(Nuestra actual: `Mesa 26.3.0-pocknix2.1`, api 1.4.363.)*
- 📦 `deckard-audio-config` extraído a `~/deckard-0.5.x/valve-audio/` (**no aplicar**).

## Cómo probar (per-game, reversible)
Steam → juego → Propiedades → **Opciones de lanzamiento**:
```
VK_LOADER_LAYERS_ENABLE=VK_LAYER_VALVE_rpo VK_ICD_FILENAMES=/home/deck/deckard-0.5.x/valve-turnip-icd.json %command%
```
- Sin las variables → nuestra Turnip (como ahora). Con ellas → Turnip de Valve + layer RPO.
- Medir **FPS** con MangoHud (QAM), con y sin.

## Vuelta atrás
- Borrar las opciones de lanzamiento → vuelve a lo nuestro (no se tocó el sistema).
- Layers: `sudo pacman -R deckard-vulkan-layers-linux-aarch64` (o quedan inertes sin `VK_LOADER_LAYERS_ENABLE`).

## Pendiente (con Fransis)
- **Pruebas de estabilidad** (Turnip de Valve + RPO vs lo nuestro).
- Decidir si se **integra de serie**: la Mesa de Valve es una **Mesa completa** (choca con la nuestra) →
  integrarla sería **per-game** (`VK_ICD_FILENAMES`) o sustituir la nuestra (riesgo). Las **layers** sí son
  fáciles de hornear (aditivas).
