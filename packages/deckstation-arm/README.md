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

---

## ¿Qué es?

DeckStation ARM es un sistema de emulación portable que transforma cualquier
dispositivo **ARM64** (AYN Odin 3, Raspberry Pi, tablets, etc.) en una consola de
emulación completa. Está inspirado en Steam Deck y DeckStation, pero diseñado para
funcionar en hardware ARM.

Es un proyecto **independiente de cualquier sistema operativo**: no depende de
ninguna distribución concreta y todo queda autocontenido en su propia carpeta.

## Filosofía

- **Todo autocontenido**: Todo vive dentro de `/opt/deckstation/`
- **Nada en el sistema host**: No toca `/home/`, `/etc/` ni configs del usuario
- **Portable**: Mover el directorio funciona en otro dispositivo
- **Sin dependencias del sistema**: Se auto-descarga todo lo necesario
- **Modular**: Cada emulador es independiente

## Arquitecturas

| Arquitectura | Estado |
|---|---|
| **aarch64 (ARM64)** | ✅ Este repo — adaptación ARM |
| **armv7h (ARM32)** | ⚠️ Parcial (depende del emulador) |
| **x86_64** | ❌ Ver repo `deckstation-x86_64` (proyecto original) |

## Estructura del repo

```
deckstation-arm/
├── README.md
├── .gitignore
├── PKGBUILD                       # Paquete Arch (aarch64/armv7h)
├── deckstation-arm.install        # Hooks de instalación
├── scripts/
│   ├── deckstation-setup.sh       # Instalación INICIAL completa (los 30 emuladores) + configs + BIOS
│   ├── deckstation-launcher.sh    # Launcher portable (auto-reparación + fija SDL_VIDEODRIVER)
│   ├── deckstation-update.sh      # Actualizador
│   ├── deckstation-configs.sh     # Despliega la config base en cada emulador
│   ├── deckstation-bios.sh        # Informe (--check) y reparto de las BIOS del usuario
│   ├── deckstation-cores.sh       # Enlaza los cores del sistema a la carpeta portable
│   ├── deploy-lanzar-sh.sh        # Copia lanzar.sh a cada emulador (lo usan setup, launcher y Updater)
│   └── lanzar.sh                  # Wrapper portable por emulador (lo que lanza ES-DE)
├── updater/                       # Centro de Mando (GUI) + motor de descarga headless
│   ├── updater.py                 #   GUI y `--install-all` (mismo motor)
│   ├── git.txt                    #   30 fuentes aarch64 (y 16 comentadas sin build)
│   ├── launcher.sh                #   Arranque con el driver SDL del compositor
│   └── README.md                  #   Port a aarch64: qué se cambió y por qué
├── bios/                          # BIOS/firmware del usuario (los ficheros NO van en git)
│   ├── required.txt               #   Qué fichero espera cada sistema (+ alternativas)
│   ├── deploy-bios.txt            #   A dónde va cada sistema
│   └── <sistema>/                 #   Aquí dejas tus BIOS (psx/, dreamcast/, ...)
├── overlay/
│   └── usr/bin/deckstation        # Comando del sistema
├── configs/                       # Configs portable de emuladores (ver configs/README.md)
│   ├── retroarch/                 #   + autoconfig (610 configs de mandos)
│   ├── es-de/                     #   ES-DE: es_find_rules.xml, es_systems.xml, es_settings.xml
│   ├── duckstation/  azahar/  citron/  dolphin/
│   ├── pcsx2/  ppsspp/  flycast/  dosboxpure/
│   ├── rmg/  zsnes/  supermodel/  antimicrox/  vita3k/
│   └── es-de-home/
└── docs/
    └── INSTALACION.md
```

## Estructura en ejecución (`/opt/deckstation/`)

```
/opt/deckstation/
├── DeckStation.AppImage        # La AppImage principal (ES-DE)
├── DeckStation.sh              # Script de lanzamiento
├── Apps/                       # Emuladores descargados (ARM64)
├── saves/                      # Saves del usuario
├── logs/                       # Logs de ejecución
├── Media/                      # Assets multimedia
├── settings/                   # Configuraciones
├── scripts/                    # Scripts de gestión
└── configs/                    # Configs del sistema
```

## Cómo funciona

1. **Instalación**: El paquete Arch instala la estructura base (sin emuladores).
2. **Instalación inicial** (`deckstation-setup`): prepara el entorno (assets, cores,
   libXss), instala **los 30 emuladores** de `git.txt` en modo headless, despliega
   `lanzar.sh` y las configs en cada uno, y reparte las BIOS que hayas puesto en `bios/`.
   Es **reejecutable**: lo que ya está, se salta.
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
| **Red** | Sí: se descargan ES-DE (~127 MB) y los emuladores (~1,5 GB) |
| **RetroArch + cores** | Los aporta el sistema. El setup enlaza los cores que encuentre; sin ellos RetroArch no arranca juegos |
| **Mando** | El mapeo lo pone tu sistema (InputPlumber o el suyo). DeckStation no lo toca |
| **BIOS** | Las tuyas (DeckStation **no** las incluye ni las descarga: tienen copyright) |

### Arch Linux ARM
```bash
# Compilar e instalar
makepkg -si

# O instalar desde pre-compilado
sudo pacman -U deckstation-arm-*.pkg.tar.zst
```

### Post-instalación
```bash
# Instalación inicial completa: ES-DE + los 29 emuladores + configs + BIOS
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
- El resto (ES-DE, emuladores, configs, wrappers, BIOS) es **independiente de la distro**.

Lo que **no** es portable hoy es el empaquetado: el paquete y el comando `deckstation`
(`/usr/bin` + entrada de escritorio) son de Arch. En otra distro habría que copiar el árbol a
`/opt/deckstation` y lanzar `scripts/deckstation-launcher.sh` a mano.

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
