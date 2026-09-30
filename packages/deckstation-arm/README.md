# DeckStation ARM

**Sistema de emulación portable para arquitectura ARM (aarch64/armv7h)**

> **DeckStation** es un proyecto independiente de emulación portable.
> Creado por **stshunz** — https://github.com/stshunz
> Esta es la adaptación para arquitecturas ARM.

---

## Documentación

- **`CAMBIOS-REALIZADOS.md`** — registro de los cambios de portabilidad y saneado
  (rutas, saves/logs centralizados, Updater). Equivale al `.CAMBIOS_REALIZADOS.md`
  de la versión x86_64.
- **`configs/README.md`** — detalle fichero a fichero de cada configuración saneada.
- **`updater/README.md`** — el actualizador de AppImages.
- **`docs/INSTALACION.md`** — instalación.
- **`docs/PORTABILIDAD-DISTROS.md`** — qué es portable hoy y qué ataría a Arch.

---

## ¿Qué es?

DeckStation ARM es un sistema de emulación portable que transforma cualquier
dispositivo **ARM64** (AYN Odin 3, Raspberry Pi, tablets, etc.) en una consola de
emulación completa. Está inspirado en Steam Deck y DeckStation, pero diseñado para
funcionar en hardware ARM.

Es un proyecto **independiente de cualquier sistema operativo**: no depende de
ninguna distribución concreta y **todo queda autocontenido en su propia carpeta**.

## Filosofía

- **Todo autocontenido**: Todo vive dentro de `/opt/deckstation/`
- **Nada en el sistema host**: No toca `/home/`, `/etc/` ni configs del usuario
- **Portable**: Mover el directorio funciona en otro dispositivo
- **Sin dependencias del sistema**: Se auto-descarga todo lo necesario
  — **incluidos los cores de RetroArch** (ver [Cores](#cores))
- **Modular**: Cada emulador es independiente

## Estado (octubre 2026)

| Área | Estado |
|---|---|
| **Cores** | 259 instalados · **211 ofrecidos en ES-DE** (todos con alternativa por sistema) · 3 fuera por crashear |
| **BIOS** | **40 sistemas** en el manifiesto (`deckstation-bios.sh --check` → 40/40 cubiertos) |
| **Configs** | Base propia + aportes de Batocera (core options de RetroArch, 27 juegos de Model 3, Amiberry) |
| **Autonomía** | 100 %: cores, BIOS y configs viven **dentro** de `/opt/deckstation` |

## Arquitecturas

| Arquitectura | Estado |
|---|---|
| **aarch64 (ARM64)** | ✅ Este repo — adaptación ARM |
| **armv7h (ARM32)** | ⚠️ Parcial (depende del emulador) |
| **x86_64** | ❌ Ver repo `deckstation-x86_64` (proyecto original) |

## Cores

Los cores de libretro son la pieza que hace que RetroArch sirva para algo: **sin
cores, no se juega a casi nada**. Aquí están resueltos **dentro de DeckStation**,
sin depender de los paquetes del sistema:

| Script | Qué hace |
|---|---|
| `scripts/deckstation-cores.sh` | **COPIA** a la carpeta portable los cores que encuentre en las rutas estándar del sistema (`/usr/lib/libretro`). No destructivo: solo lo que falte. |
| `scripts/deckstation-cores-fetch.sh` | **DESCARGA** a la carpeta portable los cores que falten, de tres fuentes: el set de **ArkOS** (`christianhaitian/retroarch-cores`, commit pineado), el **buildbot oficial** de libretro y un **release propio** para los que nadie publica compilados (`azahar`, `bsnes-hd`). |
| `scripts/deckstation-cores-sync.sh` | Regenera el `es_systems.xml` **activo** de ES-DE quitando los `<command>` cuyo core no exista. Si mañana instalas ese core, el comando **reaparece solo**. |

- **Destino de todo**: `<RetroArch>.home/.config/retroarch/cores/`, como **ficheros reales**.
  Mover la carpeta de DeckStation a otro dispositivo **se lleva los cores contigo**.
- **Los que nadie publica** se compilan y se publican en
  **[`arcadematicas/deckstation-cores`](https://github.com/arcadematicas/deckstation-cores)**
  (release `cores-2026-09`): `azahar_libretro.so` (3DS) y `bsnes_hd_beta_libretro.so` (SNES HD).
  `azahar` **no se puede compilar con qemu** (falla gcc), de ahí que se distribuya ya compilado.
- ⚠️ **Orden importante**: primero `deckstation-cores.sh` / `-fetch.sh` (poblar) y **después**
  `deckstation-cores-sync.sh` (podar ES-DE). Al revés, el sync no ve el core y lo poda igual.
- ⚠️ **Cores personales**: lo que pongas tú en la carpeta portable **no se toca nunca**
  (los scripts solo añaden lo que falta). Ideal para cores con licencias restrictivas que no se
  pueden distribuir.
- **Todos los cores instalados aparecen en ES-DE**: cada core de la carpeta portable tiene su
  `<command>` en `es_systems.xml`, así que puedes elegir **emulador alternativo por sistema**. El
  predeterminado (la primera opción) está curado a mano: **PSX → SwanStation**, **CPS1/2/3 →
  FinalBurn Neo**, **SNES → Snes9x**, **N64 → Mupen64Plus-Next**, **GBA → mGBA**… Las alternativas
  se generan con `tools/inserta-cores-es-de.py`.
- ⚠️ **Tres cores se quedan fuera a propósito** porque crashean: `mednafen_snes`,
  `nside_sfc_balanced` y `mame2015` (comprobado con ROM real y con el core suelto). El smoke test
  está en `tools/smoke-cores-geometry.sh`.

## Estructura del repo

```
deckstation-arm/
├── README.md
├── .gitignore
├── PKGBUILD                       # Paquete Arch (aarch64/armv7h)
├── deckstation-arm.install        # Hooks de instalación
├── scripts/
│   ├── deckstation-setup.sh        # Instalación INICIAL completa (emuladores + cores + configs + BIOS)
│   ├── deckstation-launcher.sh     # Launcher portable (auto-reparación + fija SDL_VIDEODRIVER)
│   ├── deckstation-update.sh       # Actualizador
│   ├── deckstation-configs.sh      # Despliega la config base en cada emulador
│   ├── deckstation-bios.sh         # Informe (--check) y reparto de las BIOS del usuario
│   ├── deckstation-cores.sh        # COPIA a DeckStation los cores que haya en el sistema
│   ├── deckstation-cores-fetch.sh  # DESCARGA los cores que falten (ArkOS + buildbot + release propio)
│   ├── deckstation-cores-sync.sh   # Poda de ES-DE los <command> sin core (y los resucita si vuelve)
│   ├── deckstation-steam.sh        # Añade DeckStation a Steam como acceso del modo juego
│   ├── deploy-lanzar-sh.sh         # Copia lanzar.sh a cada emulador (lo usan setup, launcher y Updater)
│   └── lanzar.sh                   # Wrapper portable por emulador (lo que lanza ES-DE)
├── updater/                       # Centro de Mando (GUI) + motor de descarga headless
│   ├── updater.py                 #   GUI y `--install-all` (mismo motor)
│   ├── git.txt                    #   31 emuladores aarch64 activos (y 12 sin build, comentados)
│   ├── launcher.sh                #   Arranque con el driver SDL del compositor
│   └── README.md                  #   Port a aarch64: qué se cambió y por qué
├── bios/                          # BIOS/firmware del usuario (los ficheros NO van en git)
│   ├── required.txt               #   Qué fichero espera cada sistema (+ alternativas + md5)
│   ├── deploy-bios.txt            #   A dónde va cada sistema
│   ├── README.md                  #   Versión larga: qué es cada BIOS y cómo conseguirla legalmente
│   └── <sistema>/                 #   Aquí dejas tus BIOS (psx/, dreamcast/, cdimono1/, ...)
│                                  #   40 sistemas soportados en el manifiesto
├── overlay/
│   └── usr/bin/deckstation        # Comando del sistema
├── configs/                       # Configs portable de emuladores (ver configs/README.md)
│   ├── retroarch/                 #   + autoconfig (610 configs de mandos)
│   ├── es-de/                     #   ES-DE: es_find_rules.xml, es_systems.xml, es_settings.xml
│   ├── deploy-manifest.txt        #   Mapa config -> destino (lo lee deckstation-configs.sh)
│   ├── duckstation/  azahar/  citron/  dolphin/
│   ├── pcsx2/  ppsspp/  flycast/  dosboxpure/  mame/
│   ├── rmg/  zsnes/  supermodel/  antimicrox/  vita3k/  rpcs3/  xemu/  xenia/
│   ├── amiberry/                  #   Amiga: conf + base SDL de mandos
│   └── es-de-home/
├── tools/                         # Herramientas de mantenimiento (no las usa el runtime)
│   ├── inserta-cores-es-de.py     #   Meter cada core instalado como alternativa en es_systems.xml
│   ├── smoke-cores-geometry.sh    #   Probar cores con ROM real (criterio: línea "Geometry")
│   └── auditoria-es-de.py         #   Auditar comandos muertos/duplicados del es_systems
└── docs/
    ├── INSTALACION.md
    └── PORTABILIDAD-DISTROS.md
```

## Estructura en ejecución (`/opt/deckstation/`)

```
/opt/deckstation/
├── DeckStation.AppImage        # La AppImage principal (ES-DE)
├── DeckStation.sh              # Script de lanzamiento
├── Apps/                       # Emuladores descargados (ARM64)
│   └── <Emulador>/
│       ├── <Nombre>.AppImage
│       ├── <Nombre>.AppImage.home/   # HOME portable del emulador (ver nota)
│       └── lanzar.sh                 # wrapper: limpia el entorno y fija HOME
├── saves/                      # Saves del usuario
├── logs/                       # Logs de ejecución
├── Media/                      # Assets multimedia
├── settings/                   # Configuraciones
├── scripts/                    # Scripts de gestión
└── configs/                    # Configs del sistema
```

> **Nota sobre las carpetas `.home`** — el `.home` de cada emulador **es su `$HOME`**: `lanzar.sh`
> hace `export HOME=<Emulador>.AppImage.home`, de modo que todo lo que el emulador escriba queda
> dentro de `/opt/deckstation` y la instalación es portable.
>
> Por eso **la carpeta parece vacía al mirarla**: las apps guardan en `.config/`, `.local/` y
> `.cache/`, que empiezan por punto y **Dolphin oculta por defecto**. Pulsa **`Ctrl+H`** para
> verlas.
>
> Y **los emuladores sin config de fábrica tienen el `.home` vacío a propósito**: es donde
> escribirán su configuración la primera vez que los abras. Que esté vacío no es un fallo.

## Cómo funciona

1. **Instalación**: El paquete Arch instala la estructura base (sin emuladores ni cores).
2. **Instalación inicial** (`deckstation-setup`): prepara el entorno (assets de RetroArch, libXss,
   **cores**), instala **los emuladores de `git.txt`** en modo headless, despliega `lanzar.sh` y
   las configs en cada uno, y reparte las BIOS que hayas puesto en `bios/`. Es **reejecutable**:
   lo que ya está, se salta.
   - **Los cores se traen aquí**: `deckstation-cores.sh` (copia los del sistema) +
     `deckstation-cores-fetch.sh` (descarga los que falten) → todo queda **dentro de DeckStation**.
3. **Uso**: `deckstation` lanza el sistema completo.
4. **Gestión**: el **Updater** (ES-DE → Updater) actualiza, añade emuladores sueltos y
   muestra el estado de las BIOS. Mismo motor que la instalación, pero con GUI.

> **Dos puertas, un motor**: la lógica de descarga vive en `updater/updater.py` y la de
> despliegue en los scripts. La GUI es una capa encima, para que una avería gráfica no
> te deje sin poder instalar.

## Instalación

### Requisitos

| | |
|---|---|
| **Sistema** | **ARM Linux con base Arch** (ALARM, ROCKNIX, ArkOS…). El paquete es un PKGBUILD y las dependencias usan nombres de pacman |
| **Arquitectura** | aarch64 (o armv7h) |
| **Paquetes** | `python`, `python-requests`, `python-pygame` (los trae el paquete) y **`7zip`** ⚠️ — **sin `7z` el Updater no extrae NINGÚN emulador**. Va en `optdepends`, así que instálalo a mano: `sudo pacman -S 7zip` |
| **Red** | Sí: se descargan ES-DE (~127 MB), los emuladores (~1,5 GB) y los **cores** (~2,5 GB en la primera instalación) |
| **Cores** | **Los trae DeckStation**: los copia del sistema si están y **descarga los que falten** a su propia carpeta. `curl` y `unzip` son suficientes |
| **Mando** | El mapeo lo pone tu sistema (InputPlumber o el suyo). DeckStation no lo toca |
| **BIOS** | Las tuyas (DeckStation **no** las incluye ni las descarga: tienen copyright). `deckstation-bios.sh --check` te dice qué falta |

### Arch Linux ARM
```bash
# Compilar e instalar
makepkg -si

# O instalar desde pre-compilado
sudo pacman -U deckstation-arm-*.pkg.tar.zst
```

### Post-instalación
```bash
# Instalación inicial completa: ES-DE + emuladores + cores + configs + BIOS
deckstation-setup

# Estado de tus BIOS (que falta y donde va cada una)
deckstation-bios.sh --check

# Lanzar
deckstation
```

### Otras distros ARM (Ubuntu, Fedora…)

Funciona **a medias y de forma honesta**: los pasos específicos de Arch **avisan y se omiten**
en vez de romper.

- El setup no puede auto-instalar dependencias (usa `pacman`) → **avisa** y sigue. Instala a
  mano `python3`, `python3-requests`, `python3-pygame` y `7z`.
- El aprovisionamiento de `libXss` baja de un mirror de ALARM → **avisa** y sigue; `lanzar.sh`
  tiene un respaldo en tiempo de ejecución (toma la lib del runtime de Steam).
- El resto (ES-DE, emuladores, **cores**, configs, wrappers, BIOS) es **independiente de la distro**.

Lo que **no** es portable hoy es el empaquetado: el paquete y el comando `deckstation`
(`/usr/bin` + entrada de escritorio) son de Arch. En otra distro habría que copiar el árbol a
`/opt/deckstation` y lanzar `scripts/deckstation-launcher.sh` a mano.

> 📋 **Soportar otras distros de verdad está analizado y documentado, pero NO implementado**:
> ver **`docs/PORTABILIDAD-DISTROS.md`**. Resume qué ya es portable (casi todo), los 4 puntos que
> atan a Arch (con fichero y línea) y cómo se haría (abstraer el gestor de paquetes + un
> `install.sh`). Son ~1 día de trabajo, pendiente de que alguien lo pida.

## Actualización
```bash
deckstation-update
```

## Licencia

GPL v2+

## Créditos

- **stshunz** — creador original de DeckStation (https://github.com/stshunz)
- **DeckStation ARM** — adaptación para arquitecturas ARM
- **Emuladores**: RetroArch, Dolphin, DuckStation, PPSSPP, etc. (versiones ARM64)
- **Batocera** — su colección de configuraciones (core options de RetroArch, secciones por juego de
  Supermodel, conf de Amiberry, base SDL de mandos) ha nutrido la configuración base de DeckStation
- **Cores que nadie publica**: compilados por el proyecto y publicados en
  [`arcadematicas/deckstation-cores`](https://github.com/arcadematicas/deckstation-cores)
  (Azahar — GPL-2.0-or-later; bsnes-hd — GPL-3.0-only)
