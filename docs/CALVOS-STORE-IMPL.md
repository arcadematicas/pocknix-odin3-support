# CalvOS Store — motor, catálogo y cómo seguir construyendo sobre él

Documento de trabajo. La idea de producto (tienda + asistente) está en
[`CALVOS-STORE-Y-SETUP.md`](CALVOS-STORE-Y-SETUP.md); esto es la **implementación**.

## 1. Qué hay montado

| Pieza | Dónde | Estado |
|---|---|---|
| `pocknix-ui` (motor QML/C++, `pocknix-job`, `pocknix-pacman`) | repo `shared` (0.1.0-1) | de upstream, **sin tocar** |
| `pocknix-store` (app) | **centro**: `packages/pocknix-store` | fork nuestro: branding CalvOS + catálogo propio |
| Catálogo | `catalogue.d/*.conf` | 9 entradas nuestras |
| `sync-to-os.sh` / `check-sync.sh` | centro | mapean `packages/pocknix-store` → árbol |

Regla de oro del proyecto: **el centro manda**. La app se edita en
`pocknix-odin3-support/packages/pocknix-store` y baja al árbol con `tools/sync-to-os.sh`.

## 2. Branding: qué se cambia y qué no

**Se cambia (visible):** título de ventana (`CalvOS Store`), `Name=`/`Comment=` del `.desktop`,
textos de la UI, mensajes de error, referencias a “Pocknix Tools” → “CalvOS Tools”.

**No se toca (identificador):**
- `import Pocknix.Ui` (nombre del módulo QML del motor).
- Rutas `/usr/share/pocknix-store`, `/usr/lib/pocknix-ui`.
- Binarios `pocknix-store`, `pocknix-ui`, `pocknix-job`, `pocknix-pacman`.
- El prefijo **`POCKNIX:`** de las líneas de progreso: es el protocolo que parsea el QML.
- `pkgname` y los ids de catálogo (son la allowlist de polkit).

## 3. Añadir una entrada al catálogo (sin tocar código)

Crear `catalogue.d/<id>.conf` con líneas `clave=valor`:

| Clave | Obligatoria | Significado |
|---|---|---|
| `name` | sí | nombre que se ve en la tarjeta |
| `section` | sí | `emulation`, `compatibility`, `network`, `streaming`, `desktop` |
| `description` | sí | una línea bajo el nombre |
| `icon` | sí | fichero de `icons/` o nombre de icono del tema |
| `packages` | sí | paquetes que instala (y quita) |
| `variants` | no | builds por GPU; la store elige según el `optdepends` de `pocknix-device-<soc>` |
| `services` | no | servicios/sockets a habilitar `--now` tras instalar |
| `note` | no | línea que aparece al terminar (“dónde se enciende”) |
| `setup` | no | paso integrado en la CLI (hoy solo `tailscale-operator`) |
| `tile` | no | manifest de tile de Steam (sin `pocknix-tiles` se ignora solo) |

**Visibilidad:** una entrada solo aparece si **todos** sus paquetes están en la base de datos
sincronizada o instalados. Es lo que hace que el catálogo de upstream no ensucie el nuestro.

### Entradas actuales
| id | Sección | Paquete(s) |
|---|---|---|
| `deckstation` | emulation | `deckstation-arm` |
| `suyu` | emulation | `suyu-libretro` |
| `esde` | emulation | `es-de` |
| `wproton` | compatibility | `wproton-arm` |
| `proton-ge` | compatibility | `proton-ge` |
| `proton-cachyos` | compatibility | `proton-cachyos` |
| `tailscale` | network | `tailscale` (+ `setup=tailscale-operator`) |
| `wireguard` | network | `wireguard-tools` |
| `moonlight` | streaming | `moonlight-qt` |

## 4. Ciclo de trabajo (y las dos trampas que ya hemos pagado)

```
# editar SIEMPRE en el centro
cd pocknix-odin3-support
tools/sync-to-os.sh && tools/check-sync.sh
# subir pkgrel si cambian bytes (¡obligatorio!)
# compilar y probar
cd ../pocknix-os
sudo env DEVICE=sm8750 make packages PKG="pocknix-store"
# instalación de prueba puntual en la consola
scp build/localrepo/shared/pocknix-store-*.pkg.tar.xz deck@<odin>:/tmp/
ssh deck@<odin> 'sudo pacman -U /tmp/pocknix-store-*.pkg.tar.xz'
```

1. **`pkgrel`**: si cambia cualquier byte del paquete, hay que subirlo o el build lo salta.
2. **Mapeo en sync**: un paquete nuevo del centro **no llega al árbol** hasta que se añade a
   `tools/sync-to-os.sh` (overlay) y a `tools/check-sync.sh` (`cmp_tree`). El overlay **no borra**
   ficheros que ya no están en el centro: si se sustituye un catálogo, hay que podar el árbol.

## 5. Publicación (pendiente de decisión)

El gate de `make stage-shared` **rechaza paquetes nuevos sin raíz**: exige que algún metapaquete
(`pocknix-core`, `pocknix-desktop-full`, `pocknix-emulation-full`, `pocknix-device-<soc>`) dependa
de ellos. Opciones:
1. Añadir `pocknix-store` a `pocknix-desktop-full` (se instala de serie; es lo coherente si la
   tienda va a ser parte del producto).
2. Crear un metapaquete `pocknix-extras` que los ate (permite imagen sin tienda).
Mientras se decide, la prueba se hace con `pacman -U` local.

## 6. Fase 2 — Asistente (CalvOS Setup)

Mismo motor (`pocknix-ui <path>/Main.qml`). Pasos propuestos, todos omitibles y repetibles:

1. Bienvenida (modelo, batería, aviso de que se puede salir).
2. Escritorio (Plasma por defecto; hoy ya lo es).
3. Emulación: DeckStation + WProton + Suyu (con espacio estimado).
4. Mando: lanzar `pocknix-gamepad-calibration`.
5. Almacenamiento: montar SD / comprobar expansión de la raíz.
6. Red: SSH, Samba, Tailscale (reutiliza `setup=tailscale-operator`).
7. Actualizaciones: primera pasada y canal.
8. Energía: perfil `bajo`/`medio`/`alto`.
9. Fin: marcador de completado.

Disparadores: marcador de primer arranque (reutilizar el del OOBE) y, opcionalmente, al cerrar el
asistente de Steam. **Nunca bloquea**: si falla, se registra y se relanza desde CalvOS Tools.

## 7. Variables que quedan abiertas
- ¿La tienda va de serie (metapaquete) o es opcional?
- ¿Qué más entra en el catálogo? (candidatos: RetroArch autocfg/shaders, Samba, Decky, ES-DE themes)
- ¿El asistente comparte catálogo con la tienda o tiene sus propias acciones?

## Publicacion en el repo (2026-11-23)

`pocknix-ui` y `pocknix-store` cuelgan ahora de la raiz **`pocknix-desktop-full`** (pkgrel 4), que es
lo que exige el gate para nombres nuevos. Asi entran en cualquier instalacion de escritorio y el
`stage-check` las resuelve sin tocar la lista de raices.

- `pocknix-store 0.1.0-3`: navegacion por foco (flechas entre tiles, RePag/AvPag por seccion) y
  seccion **Herramientas** (SSH, SMB, Flatpak/Flathub). Catalogo: 12 entradas, 5 secciones.
- Ojo: `flatpak` ya entra como dependencia de `pocknix-desktop-full`, asi que esa entrada aparece
  como instalada aunque el servicio `pocknix-flathub` no este activo.

### Trampa del dia
`make packages` regenera el indice completo del repo bajo qemu (varios minutos) y **deja `.db.tar.gz.lck`**
si se interrumpe. Dos builds a la vez = dos repo-add peleando por el lock y DB a medias. Antes de
relanzar: `pgrep -af repo-add` vacio y borrar los `.lck` a mano (la DB se comprueba con
`bsdtar -tf pocknix-*.db.tar.gz`).
