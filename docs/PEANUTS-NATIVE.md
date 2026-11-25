# Peanuts Native / nxnative — qué es y por qué solo lo vigilamos (25/11/2026)

## Qué es

**No es un emulador**: es un **recompilador estático** de juegos de Switch 1. Reescribe los
ejecutables del juego (NSO) para que su ARM64 corra nativo, con un host que implementa los
servicios de Horizon y los gráficos NVN reconstruidos en **Vulkan** (Android) o **Metal**
(Apple). Se genera una app a partir del **dump propio** del juego.

- Repo: <https://github.com/igawa6/peanuts-native> (C, creado 12/11/2026, ~1.000 estrellas,
  76 juegos en catálogo, commits diarios, ~290 issues abiertos).
- Licencia: MIT en el repo, pero el traductor de shaders (Ryujinx + un fichero de Eden) deja el
  binario en **GPL-3.0-or-later**.
- El núcleo es **nxnative** (<https://github.com/seedds/nxnative>): frontends para iPhone/iPad,
  Mac (Metal) y Android (Peanuts, con pantalla dual Eden Duo).

## Lo que ya existe para Linux (la razón de no portar nada)

- **PR #130 de peanuts-native** (`titooo7`): *"aarch64 Linux AppImage (SteamOS-style ARM
  handhelds)"*. Porta el host Linux de Banana Native + lanzador AppImage, importa `.nsp`/`.xci`
  con las claves del propio usuario y trae un perfil por título.
  - Probado en **AYN Odin 2 Pro**: Super Mario Bros. Wonder ~30 fps, **Metroid Dread 60 fps**.
  - Estado: **abierto, pendiente de revisión**. `igawa6` (22/11): *"no lo hemos revisado aún;
    lo veremos después del próximo release y volvemos a hablar"*.
- **nxnative #3250**: port del lanzador Qt a Linux; Linux ya puede hacer extracción, rewriter,
  shader split y perfiles, pero no la parte Metal.
- El host está preparado para esto: `dm/host/plat/plat.h` existe justamente para "Apple vs Linux"
  y el backend Vulkan de Android es reutilizable; lo Android-específico es la superficie
  (`ANativeWindow`), `AAudio` y `AMediaCodec`.

## Decisión (25/11/2026)

**No entramos en el proyecto.** No lo necesitamos: el puerto Linux está en marcha y validado en
una Odin. Nuestro papel es **probar su AppImage en la Odin 3 (SM8750 + Adreno 830/Turnip)**
cuando haya algo que probar, y reportar lo que veamos.

**Vigilancia**: `tools/watch-peanuts.py` (instalado en el PC con `vigilar-peanuts.timer`, diario a
las 09:00). Avisa por Telegram **solo si cambia algo**: release nueva, estado o comentarios del
PR #130 (destacado si se mergea), y issues/PR nuevos que mencionen Linux en los dos repos.

## Si algún día se integra

- Sería un **paquete aparte** (`calvos-peanuts-native` o similar) con el AppImage, no parte de la
  imagen base: requiere **dump propio** del juego y el "prepare" (extracción, rewriter, shaders) es
  pesado en CPU/RAM/disco.
- Dependencias a mirar: **.NET en aarch64** (el traductor `dmsh_xlate` es AnyCPU), `zstd`, y
  espacio para las librerías de shaders (miles por juego).
- Ventaja: juegos de Switch nativos con Turnip, sin emulador. Encaja con la línea de
  SkywardRecomp (Skyward Sword HD está en su catálogo).
