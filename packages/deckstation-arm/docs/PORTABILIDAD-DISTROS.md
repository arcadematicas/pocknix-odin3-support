# Portabilidad de DeckStation a otras distros ARM — trabajo pendiente

**Estado**: **documentado, NO implementado** (decisión de Fransis, 21/09/2026).
**Conclusión del análisis**: el motor **ya es portable**; lo que no lo es es el **envoltorio**.
Es **~1 día de trabajo**, y la pieza mayor es un `install.sh`. No se hace todavía porque **no hay
demanda** y **no se puede probar** sin una Ubuntu ARM y una Fedora ARM delante.

> Si algún día alguien pide instalarlo fuera de Pocknix, **este es el mapa**. No hace falta
> reinvestigar nada: está todo localizado con fichero y línea.

---

## 1. Lo que YA es portable (NO rehacer)

Comprobado, no supuesto:

| Pieza | Por qué ya funciona en cualquier distro |
|---|---|
| **ES-DE** | Se descarga del **AppImage oficial ARM64** de ES-DE (`setup_esde()`), no de un binario local |
| **Emuladores** | Se bajan de upstream (PkgForge, releases oficiales) igual para cualquier ARM |
| **libXss** | `lanzar.sh` la **cosecha del runtime de Steam** (`~/.local/share/Steam`, `aarch64-linux-gnu/libXss.so.1.0.0`) y la deja en `<deckstation>/lib`. Funciona en cualquier distro con Steam. La descarga del mirror de ALARM es solo un atajo |
| **`$HOME`** | `lanzar.sh` lo resuelve con `getent passwd "$(id -u)"`, no está hardcodeado |
| **Configs / wrappers / BIOS** | Independientes de la distro |
| **Arquitectura** | El Updater detecta `aarch64` vs `x86_64` solo (`IS_AARCH64`) |
| **Rutas de DeckStation** | `DECKSTATION_ROOT` es overridable; el valor por defecto es `/opt/deckstation` |

---

## 2. Lo que ata a Arch (los 4 bloqueadores)

| # | Qué | Dónde | Gravedad |
|---|---|---|---|
| 1 | `sudo pacman -S` para instalar dependencias | `scripts/deckstation-setup.sh:85` (`check_dependencies`) | 🔴 **la única dura** |
| 2 | Rutas de cores fijas | `scripts/deckstation-cores.sh:30-31` (`SYS_CORES=/usr/lib/libretro`, `SYS_INFO=/usr/share/libretro/info`) | 🟡 Debian usa `/usr/lib/aarch64-linux-gnu/libretro`; Fedora `/usr/lib64/libretro` |
| 3 | El empaquetado: PKGBUILD + `/usr/bin/deckstation` + `.desktop` | `PKGBUILD` | 🟡 capa de empaquetado, no de código |
| 4 | El mensaje de error del Updater sugiere `pacman` | `updater/updater.py:1181` | 🟢 cosmético |

---

## 3. Cómo se haría

### 3.1 Abstraer el gestor de paquetes (el 80% del trabajo)

Añadir a `deckstation-setup.sh` y usar desde `check_dependencies()`:

```bash
# Instala paquetes con el gestor de la distro. Devuelve 1 si no hay ninguno
# conocido; el setup AVISA y SIGUE (nunca debe romper por esto).
pkg_install() {
    if   command -v pacman  >/dev/null 2>&1; then sudo pacman  -S --needed --noconfirm "$@"
    elif command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y "$@"
    elif command -v dnf     >/dev/null 2>&1; then sudo dnf     install -y "$@"
    elif command -v zypper  >/dev/null 2>&1; then sudo zypper  install -y "$@"
    else return 1
    fi
}

# El mismo paquete se llama distinto en cada familia. Esta tabla es lo único
# que hay que mantener cuando cambie un nombre.
pkg_name() {   # pkg_name <clave-canonica>  ->  nombre para ESTA distro
    local clave="$1"
    if   command -v pacman  >/dev/null 2>&1; then
        case "$clave" in 7z) echo 7zip ;; pygame) echo python-pygame ;; requests) echo python-requests ;; libxss) echo libxss ;; *) echo "$clave" ;; esac
    elif command -v apt-get >/dev/null 2>&1; then
        case "$clave" in 7z) echo p7zip-full ;; pygame) echo python3-pygame ;; requests) echo python3-requests ;; libxss) echo libxss1 ;; *) echo "$clave" ;; esac
    elif command -v dnf >/dev/null 2>&1; then
        case "$clave" in 7z) echo p7zip ;; pygame) echo python3-pygame ;; requests) echo python3-requests ;; libxss) echo libXScrnSaver ;; *) echo "$clave" ;; esac
    elif command -v zypper >/dev/null 2>&1; then
        case "$clave" in 7z) echo p7zip ;; pygame) echo python3-pygame ;; requests) echo python3-requests ;; libxss) echo libXScrnSaver ;; *) echo "$clave" ;; esac
    else
        echo "$clave"
    fi
}
```

Tabla de equivalencias (para mantener a mano):

| Canónico | Arch | Debian/Ubuntu | Fedora | openSUSE |
|---|---|---|---|---|
| `7z` | `7zip` | `p7zip-full` | `p7zip` | `p7zip` |
| `pygame` | `python-pygame` | `python3-pygame` | `python3-pygame` | `python3-pygame` |
| `requests` | `python-requests` | `python3-requests` | `python3-requests` | `python3-requests` |
| `libxss` | `libxss` | `libxss1` | `libXScrnSaver` | `libXScrnSaver` |

⚠️ **`check_dependencies()` no debe abortar nunca** si no hay gestor conocido: **avisa y sigue**.
El resto de la instalación funciona sin esas dependencias en la mayoría de casos (libXss tiene el
respaldo de Steam; 7z solo hace falta para el Updater).

### 3.2 Buscar los cores en varias rutas

En `deckstation-cores.sh`, sustituir las dos rutas fijas por una búsqueda:

```bash
SYS_CORE_DIRS="/usr/lib/libretro /usr/lib64/libretro /usr/lib/aarch64-linux-gnu/libretro /usr/local/lib/libretro"
SYS_INFO_DIRS="/usr/share/libretro/info /usr/local/share/libretro/info"
```
Recorrerlas todas y enlazar los `.so` que aparezcan (deduplicando por nombre).

### 3.3 `install.sh` portable (la pieza que falta)

Un script que haga lo que hoy hace el paquete:

1. Detectar la distro y la arquitectura; abortar con un mensaje claro si no es ARM.
2. `pkg_install` de las dependencias (con `pkg_name`).
3. Copiar el árbol a `/opt/deckstation` si hay root; si no, a `~/.local/share/deckstation`
   (y exportar `DECKSTATION_ROOT` en un perfil del shell).
4. Crear el comando `deckstation` (`/usr/local/bin` o `~/.local/bin`) y el `.desktop`
   (`/usr/share/applications` o `~/.local/share/applications`).
5. Llamar a `deckstation-setup` para la instalación inicial.

Y **mantener el PKGBUILD** para Arch, que ahí ya es la mejor experiencia. `.deb`/`.rpm` solo si
alguien los pide.

### 3.4 Cosmético

`updater/updater.py:1181` sugiere `pacman`. Mejor: *"instala 7zip/p7zip para tu distro"*.

---

## 4. Cómo verificarlo (⚠️ el problema)

**Hace falta una máquina real de cada distro.** No se puede validar escribiendo código "que
debería funcionar" — con la lógica de descarga ya nos pasó (los 5 fallos del 21/09 salieron solo
al instalar los 29 emuladores de verdad).

Mínimo razonable para decir "soportado":
- **Ubuntu/Debian ARM** (probablemente en una VM con `qemu-system-aarch64`)
- **Fedora ARM** (idem)
- **Arch ARM** ya está cubierto por el paquete

Y probar el ciclo completo: `install.sh` → `deckstation-setup` → **los 29 emuladores** →
lanzar un emulador concreto desde ES-DE. No basta con que el script termine sin error.

---

## 5. Recomendación

**No hacerlo hasta que alguien lo pida.** Razones, en orden de peso:

1. **No hay demanda**: hoy nadie ha pedido instalarlo fuera de Pocknix.
2. **No se puede probar** sin las máquinas; escribiríamos código no verificado.
3. **El riesgo es asimétrico**: ramas que nadie usa se pudren y hay que mantenerlas en cada
   cambio (y aquí ya hemos visto lo caro que sale una desincronización).

**Lo barato y sin riesgo, si alguna vez se toca**: los puntos **3.2** (rutas de cores) y **3.4**
(el mensaje). Son ~10 líneas, no pueden romper nada, y dejan el terreno preparado.
