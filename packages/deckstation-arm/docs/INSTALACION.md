# Guía de Instalación — DeckStation ARM

## Requisitos previos

- **Sistema**: Arch Linux ARM (aarch64/armv7h) o compatible
- **Espacio**: ~5 GB libres para emuladores base
- **Conexión**: Internet para descargar emuladores
- **Dependencias**:
  - `python` y `python-requests`
  - `gamemode` (opcional pero recomendado)
  - `curl` o `wget`

## Instalación del paquete

### Opción 1: Compilar desde PKGBUILD

```bash
# Clonar el repo
git clone https://github.com/stshunz/deckstation-arm.git
cd deckstation-arm

# Compilar el paquete
makepkg -si
```

Esto instalará:
- `/opt/deckstation/` — Directorio base
- `/usr/bin/deckstation` — Comando del sistema
- Scripts de gestión en `/opt/deckstation/scripts/`

### Opción 2: Instalación manual

Si no usas Arch Linux:

```bash
# Crear directorio base
sudo mkdir -p /opt/deckstation

# Copiar archivos
sudo cp -r scripts/ /opt/deckstation/
sudo cp -r configs/ /opt/deckstation/
sudo cp -r overlay/usr/bin/ /opt/deckstation/

# Hacer ejecutables los scripts
sudo chmod +x /opt/deckstation/scripts/*.sh

# Crear comando del sistema
sudo ln -sf /opt/deckstation/scripts/deckstation-launcher.sh /usr/local/bin/deckstation
```

## Instalación de los emuladores

Una vez instalado el paquete, la instalación inicial los pone **todos**:

```bash
deckstation-setup
```

Esto hace, en orden:

1. Prepara el entorno: assets de RetroArch, cores del sistema, `libXss`.
2. **Instala los 30 emuladores** de `updater/git.txt` en modo headless
   (`updater.py --install-all`), con progreso y un resumen de los que fallen.
3. Despliega `lanzar.sh` y las configs de fábrica en cada emulador. **Imprescindible**:
   el `es_find_rules.xml` de ES-DE apunta a `Apps/<Emulador>/lanzar.sh`, no al AppImage.
4. Reparte las BIOS que hayas puesto en `bios/`.

Es **reejecutable**: lo que ya está instalado se salta. Son ~1,5 GB.

### Opciones del setup

```bash
deckstation-setup           # instalación normal (omite lo que ya existe)
deckstation-setup --force   # re-descargar también lo que ya existe
deckstation-setup --help    # ayuda
```

### Actualizar o añadir emuladores sueltos

Para eso está el **Updater** (ES-DE → Updater): lista los 30 con su estado, permite
instalar/actualizar de uno en uno, tiene una entrada "Instalación completa inicial" y
muestra el estado de las BIOS. Desde la terminal usa el mismo motor:

```bash
python3 /opt/deckstation/Apps/Updater/updater.py --install-all   # instala lo que falte
```

#### AetherSX2 (PS2)
```bash
# No hay builds oficiales para ARM
# Opciones:
# 1. Compilar desde fuente
# 2. Usar versiones alternativas
# Ver: https://github.com/AetherSX2/... para más info
```

## Configuración base y BIOS

### Configuración base (automática)

La carpeta `configs/` **es** la configuración de fábrica de DeckStation (ES-DE con sus
sistemas y reglas, RetroArch saneado, DuckStation, Dolphin, Flycast, ...). Se despliega
sola en el `.AppImage.home` de cada emulador:

- `deckstation-setup.sh` la aplica al terminar de instalar.
- `deckstation-launcher.sh` la reaplica en cada arranque (auto-reparación: es no-op
  cuando ya está todo).

A mano:

```bash
deckstation-configs.sh            # despliega lo que falte (no destructivo)
deckstation-configs.sh --dry-run  # ver qué haría, sin tocar nada
deckstation-configs.sh --force    # resetear a los valores de fábrica
```

El mapa de qué config va a dónde está en `configs/deploy-manifest.txt`.

### BIOS y firmware

Las BIOS tienen copyright: DeckStation **no las incluye ni las descarga**. Deja las tuyas
(extraídas de tus propias consolas) en `/opt/deckstation/bios/<sistema>/` — ver
`bios/README.md` para saber qué fichero necesita cada sistema — y se reparten solas a
donde cada emulador las espera:

```bash
deckstation-bios.sh --check    # INFORME: qué falta y dónde va cada una
deckstation-bios.sh            # reparte lo que falte (no destructivo)
deckstation-bios.sh --dry-run  # ver qué haría
```

El informe compara lo que tienes en `bios/<sistema>/` con `bios/required.txt` (qué
fichero espera cada sistema, con alternativas) y muestra el destino de cada uno. También
se ve **desde el salón**: ES-DE → Updater → **BIOS / Firmware**, y desde
**Pocknix Tools → DeckStation BIOS**.

También se ejecuta en cada arranque desde el launcher, así que basta con dejar los
ficheros y abrir DeckStation. El mapa está en `bios/deploy-bios.txt`.

## Uso básico

### Lanzar DeckStation

```bash
deckstation
```

Esto:
1. Verifica la estructura de directorios
2. Configura symlinks de compatibilidad
3. Detecta GPU y GameMode
4. Lanza el sistema de emulación

### Actualizar emuladores

```bash
# Actualizar a últimas versiones
deckstation-update

# Forzar actualización completa
deckstation-update --force
```

El actualizador:
- Crea backups antes de actualizar
- Mantiene los últimos 3 backups
- No sobrescribe configs del usuario

### Estructura de directorios

```
/opt/deckstation/
├── Apps/           # Emuladores (se auto-generan)
├── saves/          # Saves del usuario
├── logs/           # Logs de ejecución
├── configs/        # Configuraciones
├── settings/       # Settings del sistema
├── Media/          # Assets multimedia
├── backups/        # Backups de actualización
└── scripts/        # Scripts de gestión
```

### Archivos del usuario

Los saves y configs del usuario están en:
- **Saves**: `/opt/deckstation/saves/` o `~/DeckStation/`
- **Configs**: `/opt/deckstation/configs/`
- **Logs**: `/opt/deckstation/logs/`

## Troubleshooting

### "deckstation: command not found"

El comando no está en tu PATH. Soluciones:

```bash
# Verificar instalación
ls -la /usr/bin/deckstation

# Si no existe, crear symlink manual
sudo ln -sf /opt/deckstation/scripts/deckstation-launcher.sh /usr/local/bin/deckstation

# O agregar /usr/bin al PATH
export PATH="/usr/bin:$PATH"
```

### "No se encontró ningún launcher"

Los emuladores no están instalados:

```bash
# Ejecutar setup
deckstation-setup

# Verificar que se instalaron
ls -la /opt/deckstation/Apps/
```

### Problemas de permisos

```bash
# Reparar permisos
sudo chown -R $(whoami) /opt/deckstation/
sudo chmod -R 755 /opt/deckstation/

# Para usar sin sudo
sudo usermod -aG video $(whoami)
sudo usermod -aG input $(whoami)
```

### Emulador específico no funciona

1. **RetroArch**:
   ```bash
   # Verificar cores instalados
   ls /opt/deckstation/Apps/retroarch/cores/

   # Actualizar cores desde el menú
   # Online Updater -> Core Updater
   ```

2. **Dolphin**:
   ```bash
   # Verificar que está instalado
   which dolphin-emu

   # Instalar si falta
   sudo pacman -S dolphin-emu
   ```

### Logs para diagnóstico

```bash
# Ver log del launcher
cat /opt/deckstation/logs/launcher.log

# Ver log de setup
cat /opt/deckstation/logs/setup.log

# Ver log de actualización
cat /opt/deckstation/logs/update.log
```

### GameMode no activa

```bash
# Verificar instalación
which gamemoded

# Activar servicio
sudo systemctl enable --now gamemoded

# Verificar que funciona
gamemoded -s
```

## Desinstalación

### Solo emuladores
```bash
rm -rf /opt/deckstation/Apps/
```

### Todo el sistema
```bash
sudo rm -rf /opt/deckstation/
sudo rm /usr/bin/deckstation
```

### Con el gestor de paquetes
```bash
sudo pacman -R deckstation-arm
```

## Notas finales

- **No toca el sistema**: DeckStation es completamente portable
- **Configs persistentes**: Se mantienen entre actualizaciones
- **Backups automáticos**: El actualizador siempre respalda antes de cambiar
- **Multi-usuario**: Cada usuario puede tener su propio `/opt/deckstation/`
