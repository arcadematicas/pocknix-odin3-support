# Lepton — evaluación para CalvOS (4/11/2026)

> Se llama **Lepton**, no Lipton. Es el fork de **Waydroid** que Valve mantiene para
> **Deckard / Steam Frame**. Anunciado a finales de 2025; hoy (11/2026) sigue siendo
> infraestructura interna de SteamOS.

## Qué es

- Android en un **contenedor LXC** sobre el kernel de Linux (igual que Waydroid): no es una VM.
- **Minimal**: sin GApps, sin tienda; “lo mínimo para lanzar juegos/APKs”. En Steam Frame se usa
  para ejecutar juegos de Quest (que son APKs) y apps Android desde Steam.
- La gracia frente a Waydroid no es la tecnología (es el mismo árbol), sino la **integración con
  Steam**: cada app es una entrada de Steam con su propio rootfs, overlays y shaders.

## Cómo funciona (lo que se ve en `lepton-compat`)

El único paquete público hoy es `lepton-compat` (repo `archlinux-deckard-hotfixes`, arm64,
MIT, 237 KB). Contiene el “pegamento”:

- `lepton-setup_mounts.sh`: monta el rootfs de la app y sus overlays. La app vive **dentro de una
  biblioteca de Steam** (`steamapps/...`): `images/rootfs`, `images/rootfs_overlay`, capas de datos
  y de app, directorio de shaders y el **APK base**. Todo con comprobaciones de ruta.
- `lepton-binder_mount.aarch64`: abre `/dev/binderfs/binder-control` y **asigna un binder device**
  por app (Android necesita binder; por eso el kernel debe traer `binderfs`).
- `lepton-ensure_permissions_ok.sh` / `lepton-cleanup_mounts.sh` + política **polkit**
  (`org.valve.steamos.lepton`) para montar/desmontar con privilegios sin pedir contraseña.
- El repo de Deckard también trae `android-aarch64-*` (herramientas/plataforma), pero **no** el
  runtime de Lepton ni las imágenes de Android.

Es decir: Steam lanza una “app Lepton”; los scripts preparan binder + montajes + overlays y se
arranca el APK dentro del contenedor Android.

## Estado público (importante)

- Solo está publicado **`lepton-compat`**. El runtime y los rootfs de Android **no** están como
  paquetes sueltos: vienen dentro de las imágenes de SteamOS/Deckard (Holo Core).
- Es muy pronto: sin documentación pública de instalación fuera de SteamOS, y atado a rutas y
  servicios de Steam/SteamOS (`steamapps`, polkit, `devkit`).

## ¿Nos sirve en la Odin 3?

- **Kernel**: ya tenemos lo necesario (`CONFIG_ANDROID_BINDER_IPC=y`, `CONFIG_ANDROID_BINDERFS=y`).
  `ashmem` no hace falta en kernels modernos (memfd).
- **Ventaja real en ARM**: un APK **arm64** corre nativo (en Waydroid sobre x86 hay que emular ARM;
  en la Odin no). Eso ya lo daría Waydroid igual.
- **Problema**: sin runtime/imágenes publicadas, no se puede instalar hoy en pocknix sin
  extraerlo de una imagen de Deckard (trabajo de ingeniería inversa, no soportado).
- **Coste**: rootfs de Android (varios GB), integración con Steam (entradas, overlays), polkit,
  binder por app… y todo atado a un proyecto en pañales que puede cambiar sin avisar.

## Comparación rápida

| | Lepton | Waydroid |
|---|---|---|
| Base | Fork de Waydroid (LXC) | LXC + Android |
| GApps | No (minimal) | Opcional (GAPPS) |
| Integración Steam | Nativa (apps como entradas) | Manual (scripts/shortcuts) |
| Distribución | Solo SteamOS/Deckard | Paquetes en distros (AUR/Arch ARM) |
| Madurez | Muy temprana, interna | Comunidad, años de uso |
| En nuestra imagen | No | **No la llevamos** (no hay Waydroid instalado) |

## Cómo se probaría (si Valve publica las piezas)

1. Instalar `lepton-compat` + runtime y una imagen de Android arm64.
2. Comprobar `binderfs` montado (`/dev/binderfs/binder-control`) y que el helper crea devices.
3. Crear el layout en `steamapps/...`: `images/rootfs`, `images/rootfs_overlay`, APK base.
4. Añadir la app a Steam y lanzarla; mirar el log (mounts + binder + arranque del contenedor).
5. Probar un APK arm64 real (p. ej. una app de streaming) y medir consumo/rendimiento.

## Veredicto

**No implementar ahora.** No es que no nos guste: es que **no hay nada instalable fuera de SteamOS**;
solo el pegamento. Y no llevamos Waydroid, así que tampoco hay nada que “sustituir” todavía.

Plan sensato: seguirlo (repo de Deckard, en busca de más paquetes `lepton-*` y de la imagen de
Android), y si Valve lo abre o sale en Holo Core, se reevalúa con una prueba real. Mientras, si
algún día queremos apps Android en la Odin, el camino soportado hoy es **Waydroid** (APKs arm64
nativos), no Lepton.
