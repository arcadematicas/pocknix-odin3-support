# Cores de RetroArch (ARM)

La opción **«Cores de RetroArch (ARM)»** del Centro de Mando del Updater gestiona
los **cores libretro aarch64** que usa el RetroArch de DeckStation. Tiene dos
partes:

| Sub-opción | Qué hace | Motor (script) |
|---|---|---|
| **Actualizar pack de cores** | Actualiza el paquete del sistema `libretro-cores-pocknix` con `pacman` y copia los cores al RetroArch portable | `scripts/deckstation-cores-pack.sh` |
| **Cores sueltos (buildbot ARM)** | Lista los cores **aarch64** del buildbot oficial que el pack **no** trae y los descarga a mano | `scripts/deckstation-cores-loose.sh` |

Como en todo DeckStation, **el motor vive en los scripts**: funcionan desde la
terminal o Pocknix Tools (sin escritorio) y la GUI del Updater solo los llama. Así
una avería de pygame no deja al usuario sin cores.

## Contexto: dos carpetas de cores

- **El pack** (`libretro-cores-pocknix`) instala en **`/usr/lib/libretro/*.so`**
  (rutas estándar de Arch Linux ARM). Son cores del proyecto: set de ArkOS +
  extras del buildbot + propios (azahar, bsnes-hd, vboycolor…) y van **parcheados**.
- **El RetroArch de DeckStation es portable**: vive en
  `Apps/RetroArch/RetroArch-Linux-aarch64/*.AppImage.home/.config/retroarch/` y
  **no mira `/usr/lib/libretro`**. El puente `deckstation-cores.sh` copia los
  cores del pack ahí (sin sobrescribir nada que el usuario haya puesto).
- Los **cores sueltos del buildbot** son los que el pack **no** cubre (p. ej.
  `rpcs3`, `xenia_edge`, `vita3k`, `cemu`, `armsx2`). El buildbot los publica
  para aarch64, así que se bajan **directamente** a la carpeta portable.

## Opción 1 — Actualizar pack de cores

`deckstation-cores-pack.sh` hace exactamente dos cosas:

```bash
pacman -Sy --needed --noconfirm libretro-cores-pocknix   # 1) el pack del sistema
/opt/deckstation/scripts/deckstation-cores.sh            # 2) copia al RetroArch portable
```

- **Sí requiere root**, pero **solo en el paso de `pacman`**: el script eleva con
  `pkexec` si hay entorno gráfico (dialogo de polkit) y con `sudo` en consola/
  headless. Se puede forzar con `DECKSTATION_SUDO="sudo -n"`.
- `pacman -Sy --needed` **no** hace `-Syu`: actualiza solo el paquete del pack.
  (Sobre la base congelada de Pocknix, `-Syu` subiría ~260 paquetes — es un
  landmine, ver `AGENTS.md`.)
- El paso 2 (`deckstation-cores.sh`) es **no destructivo**: enlaza/copía los
  `.so` y `.info` del sistema a la carpeta portable sin pisar lo que haya ahí.

Si el paquete no está en el repositorio, el script lo dice y sale sin tocar nada.

## Opción 2 — Cores sueltos (buildbot ARM)

`deckstation-cores-loose.sh` construye un inventario y descarga a demanda.

### De dónde vienen los ficheros

- **Índice de cores** (h5ai):
  `https://buildbot.libretro.com/nightly/linux/aarch64/latest/` → todos los
  `*_libretro.so.zip`.
- **`.info`** (metadata de RetroArch):
  `https://raw.githubusercontent.com/libretro/libretro-super/master/dist/info/<n>_libretro.info`.

El buildbot sirve «lo de hoy» (no está pinnado): son cores **sin nuestros
parches**. Sirven para lo que el pack **no** cubre, **no** para reemplazarlo.

### Estados del inventario

| Estado | Significado | ¿Se puede bajar? |
|---|---|---|
| `pack` | ya viene del pack (`/usr/lib/libretro`) | **No** (intocable) |
| `installed` | ya está en la carpeta portable | No (ya lo tienes) |
| `free` | disponible en el buildbot | **Sí** |

### REGLA DE ORO: nunca se pisa un core del pack

Un core que ya existe en `/usr/lib/libretro` **no se muestra ni se descarga**: si
así lo pidieran, el script responde `exit 3` y avisa de que ese core **va
parcheado** y hay que usar la opción del pack. Se hace **también** porque el
«Online Updater» de RetroArch sobrescribe cores por encima de la carpeta
portable y **rompería los cores parcheados del pack** (ver aviso más abajo).

### Uso por terminal

```bash
# inventario (TAB: nombre<TAB>estado) + resumen en la última línea
/opt/deckstation/scripts/deckstation-cores-loose.sh --list

# bajar un core concreto a la carpeta portable
/opt/deckstation/scripts/deckstation-cores-loose.sh --install 2048

# bajar todos los sueltos que falten (los del pack se saltan solos)
/opt/deckstation/scripts/deckstation-cores-loose.sh --install-all

# no descargar nada, solo simular
/opt/deckstation/scripts/deckstation-cores-loose.sh --list --dry-run
```

La carpeta destino es la del RetroArch portable resuelta por el propio script
(misma lógica que `deckstation-cores.sh`):
`Apps/RetroArch/**/.AppImage.home/.config/retroarch/cores/`.

## ⚠️ No usar el «Online Updater» de RetroArch como vía normal

El menú **Online Updater** de RetroArch *Core Updater / Update Installed Cores*
baja los cores del buildbot **por encima de la carpeta portable y pisando lo que
haya**. Eso **sobrescribe los cores parcheados del pack** (el set propio de
Pocknix) con los genéricos del buildbot, que no traen nuestros cambios.

La vía normal es, por tanto, esta opción del Updater:

1. **Cores del pack** → *«Actualizar pack de cores»* (mantiene los parches).
2. **Cores que el pack no trae** → *«Cores sueltos (buildbot ARM)»* (baja solo
   los que faltan y **nunca** toca los del pack).

El «Online Updater» de RetroArch debe considerarse **excepcional**, no la forma
habitual de actualizar cores.

## Pruebas (sin tocar la Odin)

```bash
# scripts: sintaxis
bash -n scripts/deckstation-cores-pack.sh
bash -n scripts/deckstation-cores-loose.sh

# motor en seco (no toca nada)
scripts/deckstation-cores-pack.sh --dry-run --no-bridge
scripts/deckstation-cores-loose.sh --list | head
scripts/deckstation-cores-loose.sh --install <core> --dry-run

# la GUI del Updater: Centro de Mando -> "Cores de RetroArch (ARM)"
```
