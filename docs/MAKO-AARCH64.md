# MAKO (Lossless Scaling) en la AYN Odin 3 — por qué NO funciona todavía

**Fecha:** 15/09/2026
**Estado:** integración **lista**, funcionalidad **bloqueada por MAKO** (falta un Renderer AArch64)
**Issue abierto en MAKO:** https://github.com/eugeniosegala/MAKO/issues/60 (preguntando por el roadmap AArch64 y ofreciendo la Odin 3 para probar)

---

## Resumen

MAKO Decky (frame generation de Lossless Scaling) está **integrado y correctamente
configurado** en Pocknix para la Odin 3, pero **no puede generar frames** porque su Renderer
es **x86_64** y la Odin ejecuta los juegos con un stack Vulkan **aarch64**.

No es un problema de configuración ni de nuestra integración: es una **incompatibilidad de
arquitectura** que el propio autor de MAKO reconoce
([issue #15](https://github.com/eugeniosegala/MAKO/issues/15), agosto 2026):

> "MAKO currently ships an x86-64 Renderer... MAKO Renderer does not support AArch64 devices
> yet. **I will work on this as a new feature.**"

Otro usuario de Pocknix aarch64 (Retroid Pocket 5) llegó al mismo muro en ese issue.

---

## La cadena completa (verificada)

1. El juego es x86_64 (Windows) → corre bajo **Proton ARM64 + FEX**.
2. FEX **no** ejecuta un stack Vulkan x86_64: hace **thunking** — las llamadas Vulkan del juego
   van al **Vulkan del host, que es aarch64**:
   - `/run/host/usr/lib/libvulkan.so.1.4.357` (loader)
   - `/run/host/usr/lib/libvulkan_freedreno.so` (Turnip, ICD)
3. Por tanto **las capas Vulkan deben ser aarch64**.
4. El Renderer de MAKO (`libmako-render.so`) es **x86_64** → el loader lo registra pero
   **no puede cargarlo**.

---

## Evidencia

### 1. El loader ve la capa pero falla al cargarla

```console
$ ENABLE_MAKO=1 VK_LOADER_DEBUG=all vulkaninfo --summary
[Vulkan Loader] LAYER:  .../VkLayer_MAKO_render.json      <- la encuentra
[Vulkan Loader] INFO:   The library architecture in layer
                        .../VkLayer_MAKO_render.x86.json doesn't match the current running
                        architecture, skipping this layer
[Vulkan Loader] ERROR:  .../lib/libmako-render.so:
                        cannot open shared object file: No such file or directory
```

Ese *"No such file or directory"* es el error engañoso típico de una `.so` de arquitectura
incorrecta: **el fichero existe y es legible**.

### 2. dlopen directo desde un proceso aarch64

```console
$ file ~/.local/lib/libmako-render.so
ELF 64-bit LSB shared object, x86-64
$ python3 -c "import ctypes; ctypes.CDLL('/home/deck/.local/lib/libmako-render.so')"
FALLO: /home/deck/.local/lib/libmako-render.so: cannot open shared object file: No such file or directory
```

### 3. La capa SÍ aparece registrada (por eso engaña)

```console
$ ENABLE_MAKO=1 vulkaninfo --summary
Instance Layers: count = 11
VK_LAYER_MAKO_render          MAKO Renderer graphics layer          1.4.328  version 2
VK_LAYER_MAKO_spatial_scaling MAKO Renderer spatial-scaling layer  1.4.328  version 1
```

### 4. El proceso del juego nunca la carga

```console
$ grep mako /proc/<drt.exe>/maps      -> (nada)
```

### 5. La cadena de lanzamiento SÍ es correcta

```console
$ tr '\0' '\n' < /proc/<drt.exe>/environ | grep -E "MAKO|VK_"
ENABLE_MAKO=1
MAKO_CONFIG=/home/deck/.config/mako-render/conf.toml
MAKO_PROFILE_FALLBACK=mako
```

(Nota: `VK_IMPLICIT_LAYER_PATH` lo pone el wrapper pero **pressure-vessel lo elimina** al
entrar en el Steam Linux Runtime; no importa, porque la capa igualmente se descubre por la
ruta por defecto `~/.local/share/vulkan/implicit_layer.d`. El bloqueo real es la arquitectura.)

---

## Lo que SÍ está hecho y funcionando

| Pieza | Estado |
|---|---|
| Plugin MAKO Decky v3.2.0 en Pocknix | ✅ `pocknix-decky` (pkgrel 31) |
| Renderer 3.2.0 instalado en `~/.local` | ✅ adoptado por Decky ("Adopted the active standalone MAKO Renderer") |
| `Lossless.dll` (copia legal del usuario) | ✅ en `~/.local/share/Steam/steamapps/common/Lossless Scaling/` |
| Toggle por juego en el QAM | ✅ Pocknix Control → Games → "MAKO (Lossless Scaling frame gen)" |
| Cadena de lanzamiento | ✅ `ENABLE_MAKO=1`, `MAKO_CONFIG`, capa registrada por el loader |

---

## Cómo se activa (cuando llegue el Renderer AArch64)

1. **Toggle por juego**: Pocknix Control → **Games** → elegir juego → **"MAKO (Lossless
   Scaling frame gen)"**. Escribe la launch option `~/.local/bin/mako-run %command%` usando
   `SteamClient.Apps.SetAppLaunchOptions` (preserva otros tokens, p. ej. el de FEX).
2. **Verificar**: con el juego corriendo → `~/.local/bin/mako-check`
   (debe mostrar `✅ libmako-render.so`).
3. En el QAM de Decky, el plugin MAKO tiene una sección **Live Status** con el modo activo.

---

## Al publicar MAKO el Renderer AArch64

1. **Re-vendorizar** el plugin MAKO en `packages/shared/pocknix-decky/mako/` (release nueva).
2. **Borrar `mako-aarch64.patch`** y su línea `patch` en el `PKGBUILD` de `pocknix-decky`
   (la versión oficial ya soportará aarch64 nativamente).
3. **Rebuild** de la imagen.
4. Probar: toggle + `mako-check` + Live Status.

---

## Parche temporal aplicado (y su conclusión)

`packages/shared/pocknix-decky/mako-aarch64.patch` (commit `7ae2054`), aplicado en el
`PKGBUILD`:

1. `package.json`: `remote_binary[].host_architectures` += `"aarch64"` (gate de instalación).
2. `wrapper_generation.py`: el guard del wrapper pasa a comprobar **solo** el marcador Armada
   (se quita la condición `uname -m = aarch64/arm64`), conservando el marcador.

**Conclusión:** con el Renderer x86_64 **no sirve de nada** — solo permite que el plugin deje
instalar/activar en aarch64, pero la capa no puede cargarse. Se mantiene por decisión
explícita (Opción B) hasta que MAKO publique el Renderer AArch64, y entonces se revierte.

---

## Herramientas de diagnóstico dejadas en la Odin

- `~/.local/bin/mako-check` — informe rápido: ¿capa cargada?, ¿env?, ¿launch option?, config.
- `~/.local/bin/mako-diagnostics` — el oficial de MAKO (lee el log de Steam).
- El CEF DevTools de Steam (puerto `127.0.0.1:8080`) permite evaluar `SteamClient.Apps.
  SetAppLaunchOptions` desde fuera (túnel SSH + cliente WebSocket).

---

## Actualización 23/10/2026 — estado real y qué pide el autor

**Versión más reciente**: `render-v4.6.0` + `plugin-v4.6.0` (21/10/2026). Sigue siendo **x86_64**:

> README de MAKO: *"Published Renderer packages currently target x86_64 Linux hosts... **Native
> AArch64/Armada packages are not included in this release.**"*

Y hay un cambio importante de comportamiento: **el plugin ahora se niega a instalarse/activarse en un
host AArch64 nativo** (fail-closed). Lo documentan en `plugin/docs/ARMADA.md`:

| Situación | Comportamiento |
|---|---|
| Host x86_64 nativo | instala y activa normal |
| **Armada / AArch64 nativo** (incluido Decky bajo FEX) | **instalación deshabilitada**; wrapper en passthrough; se limpian activaciones antiguas |
| Ficheros x86 del Renderer en disco | siguen ahí para limpiar, pero el wrapper **nunca** los activa |

⚠️ **Consecuencia para nosotros**: si actualizamos el plugin Mako a 4.5/4.6 en la Odin, se
**desactivará solo** en vez de intentar cargar una capa que no puede. Nuestra integración antigua
(la que dejaba el plugin instalado) queda obsoleta por diseño.

### Lo que pide el autor (issue #60, 10/10)
> *"A native build attempt with the first concrete failures would be useful; you don't need to take on
> the whole port..."*

Es decir: **intentar compilar el Renderer para aarch64 y mandarle los primeros errores concretos**.
Y los requisitos que ellos mismos han fijado para habilitar Armada (`ARMADA.md`):

1. Renderer AArch64 **compilado desde fuente revisable** en su flujo normal (versión y checksum inmutables).
2. Definir la matriz host nativo ↔ payload Vulkan del proceso cliente (no dar por bueno que las
   etiquetas `64/32` x86_64 impliquen compatibilidad con FEX/Turnip).
3. Demostrar **activación y teardown limpios** de la capa Vulkan en Armada sin editar el `Config.json`
   global de FEX ni instalar una capa always-on.
4. Validar `armada-game-launch`, juegos directos de Steam/Proton, lanzadores Flatpak y el *bypass*
   explícito del Renderer.

### Plan concreto nuestro
- **Intento de build aarch64** del Renderer en el chroot de compilación del PC (mismo que usamos para
  el kernel/BSP): recoger los **primeros errores** (toolchain, intrínsecos x86, SPIR-V, dependencias)
  y pegarlos en el issue #60. Eso es exactamente lo que piden para mover la prioridad.
- **No** tocar FEX `Config.json` global ni instalar nada always-on (requisito 3).
- Si algún día hay Renderer AArch64: nuestra integración ya está hecha (ver el resto de este doc).
