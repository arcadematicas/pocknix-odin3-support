# Batocera 44 (2026/11/17) y la AYN Odin 3 — qué nos sirve

Revisión para DeckStation. Fuente: changelog oficial de Batocera 44 ("Malachite") y notas de
retrohandhelds.

## Soporte de la consola

- **AYN Odin 3: soporte inicial** en v44.
- Todos los Qualcomm (SDM845…SM8750) **arrancan solo por OpenABL**: exigen OpenABL ≥ 1.1 y su
  propio menú. Nosotros ya vamos con **1.2 en los dos slots**, así que no nos pilla por sorpresa.
- Las imágenes ARM nuevas usan **partición de arranque de 8 GB (10 GB en SM8750)**: no caben en
  tarjetas de 8 GB. Dato a tener en cuenta si algún día comparamos reparto de particiones.
- `batocera-upgrade --update-bootloader` puede flashear ABL/firmware: misma idea que nuestro
  `pocknix-update-abl` (que además escribe los dos slots).

## Emuladores / cores que **no** tenemos y sí existen para aarch64

Comparado con `deckstation-arm/updater/git.txt` (25 emuladores: Amiberry, ares, Azahar, BigPEmu,
Cemu, ClownMDEmu, Dolphin, DOSBox-Pure/X, DREAMM, DuckStation, Flycast, MAME, melonDS, mGBA,
OpenMSX, PCSX-Redux, RMG, Ruffle, ScummVM, SkyEmu, Supermodel, Xemu, Ymir, ZSNES).

| Emulador | Sistema | Estado en DeckStation | Nota |
|---|---|---|---|
| **Armsx2 2.7.2** | PS2 | **falta** | Fork ARM64 de PCSX2; soporte de force feedback. El salto más grande: no tenemos PS2 usable (PCSX-Redux no es para jugar). |
| **PCSX2x6** | PS2 / Namco System 2x6 | **falta** | Segundo camino para PS2 en ARM; Batocera lo usa para arcade 2x6 y como emulador de PS2. |
| **RPCS3** | PS3 (+ Namco 357/369) | **falta** | En v44 ya corre juegos de System 357/369 en aarch64. Nuestro AGENTS decía "sin build ARM": **ya no es cierto**. |
| **DraStic** | NDS | tenemos melonDS | Vuelve en v44 para aarch64. Es cerrado (y de pago en Android): revisar licencia antes de empaquetarlo. |
| **NanoBoyAdvance** | GBA | tenemos mGBA | Alternativa orientada a precisión; valorar solo si mGBA da problemas. |
| **Libretro-Beetle-PCE** (no "Fast") | PC Engine / CD | por confirmar | Añadido para aarch64 "capaces". |
| **Odin** (standalone) | Sega Hikaru / Gaelco | falta | Curioso pero nicho. |
| **Lindbergh** como `.squashfs` | Arcade Lindbergh | falta | Encaja con la idea de wsquashfs que ya usamos. |
| ShadPS4 | PS4 | — | Solo x86_64; no aplica. |

## Qué merece la pena de verdad

1. **PS2 (Armsx2 o PCSX2x6)**: es el hueco más grande de DeckStation y ahora hay binarios ARM64.
   Probar primero **Armsx2** (AppImage/PkgForge si publica aarch64) con 2-3 juegos.
2. **RPCS3 aarch64**: interesante, pero pesado; solo si el rendimiento del 8 Elite da la talla.
3. **DraStic**: mejora de rendimiento en NDS, pero **licencia** antes que nada.

## Otras notas

- MangoHud con stats de GPU en Qualcomm/Mali (ya lo tenemos).
- "Odin" standalone y Lindbergh: nicho, pero demuestran que el ecosistema aarch64 se está
  moviendo rápido; conviene revisar Batocera/ROCKNIX de vez en cuando.
- La exigencia de OpenABL en Batocera 44 es una señal de que nuestro camino (OpenABL en los dos
  slots) es el estándar de facto.
