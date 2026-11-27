# PENDIENTES — 03/10/2026 (noche)

Relevo para la sesión de mañana. Nada de esto es urgente ni ha roto nada: son cosas **a medio
cerrar** y trabajo ya diagnosticado que solo falta **ejecutar**.

---

## 1. ⚠️ EL BUG DEL UPDATER DEL QAM (lo primero)

### Síntoma
En el QAM → **Pocknix control → actualizar** (un usuario normal, sin terminal) el updater lanza
`pacman -Syu --noconfirm --noprogressbar` y **falla entero**:

```
error: no se pudo realizar la operación (archivos en conflicto)
plutovg: /usr/include/plutovg/plutovg.h existe en el sistema de archivos
plutosvg: /usr/include/plutosvg/plutosvg.h existe en el sistema de archivos
pocknix-soname-compat: /usr/lib/libFLAC.so.8 existe en el sistema de archivos
pocknix-vk-valve: /usr/share/pocknix/vk-arm/26.3.0-valve/icd.json existe en el sistema de archivos
Ocurrieron errores, por lo que no se actualizarán los paquetes
POCKNIX_UPDATE_EXIT:1
```

**NO rompe nada**: pacman aborta **la transacción completa** y descarta lo descargado. El sistema
queda intacto (0 unidades systemd caídas, UI y WiFi arriba). Log completo del intento:
`/run/pocknix-update.log` en la Odin.

### Causa
La **imagen** dejó en el disco ficheros de esos paquetes **que no pertenecen a ningún paquete**
(huérfanos). Pacman, ante un fichero existente sin dueño, **aborta por diseño**. Por eso los
paquetes salen como "nuevos" en el `-Su` aunque sus ficheros ya estén ahí.

⚠️ **Es un bug de Pocknix, no nuestro**: le pasa a **cualquier** usuario que tenga ficheros
huérfanos. Nosotros lo hemos destapado al meter paquetes nuevos en nuestro repo.

### Quién es quién
- `/usr/bin/pocknix-update` → paquete **`pocknix-base`** (hace `exec pacman -Syu`, sin `--overwrite`)
- El comando del QAM se construye en
  `/usr/share/decky-plugins/PocknixControl/py_modules/pocknix_control/updates.py`
- **Los dos están en NUESTRO árbol** (`~/pocknix-odin3-project/pocknix-os`) → **los podemos
  arreglar y publicar**. (Comprobar en qué `packages/...` vive cada uno al empezar.)

### Plan (mañana)
1. **Investigar** en el árbol: qué PKGBUILD trae cada uno, y **por qué paso del build**
   (`build-image.sh`, `install_local_packages`, algún rsync…) los ficheros quedan sin dueño —
   esa es la causa raíz y hay que arreglarla para que las imágenes nuevas no lo repitan.
2. **Parchear** el updater/plugin para que la actualización no se caiga: añadir `--overwrite` con
   **lista acotada de rutas nuestras** (mejor que `--overwrite '*'`), y que sea **robusto** si
   mañana aparece otro huérfano. Subir `pkgrel`.
3. **Publicar** en nuestro repo (ver §2).
4. **Probar Fransis desde el QAM** — no por terminal.
5. **Si va bien → reportar a `shuuri-labs/pocknix-os`** (mira si PR #81 vale o hace falta un issue
   nuevo). Texto a preparar: el fallo, la causa y el arreglo.

### ⚠️ El huevo y la gallina (no olvidarlo)
El actualizador arreglado **viaja dentro de una actualización**… que es la que falla. Para que
**el primer intento de Fransis desde la interfaz funcione**: publicar temporalmente **sin** los
paquetes que provocan el conflicto (para que ese `-Syu` pase e instale el updater arreglado) y
**después** volver a publicarlos, de modo que la **segunda** prueba ya sea la del arreglo.

**No tocar la Odin a mano para esto** — el `--overwrite` de transición lo hará Fransis desde la
interfaz, que es justo lo que quiere validar.

### Mientras tanto (si Fransis tiene prisa)
`sudo pacman -Syu --overwrite` con las rutas del log, a mano. **Eso no arregla el bug**, solo
desbloquea el día. El arreglo de verdad es el de arriba.

---

## 2. NUESTRO REPOSITORIO (operativo — datos para no buscarlos)

```
URL pública : https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev
              ├── /sm8750   11 paquetes · 160 MB   (índice: pocknix.db)
              └── /shared   45 paquetes · 2,5 GB   (índice: pocknix-shared.db)
Bucket      : r2:pocknix   (rclone remote `r2:` configurado en el PC)
Clave firma : pocknix-repo@arcadematicas · fpr 80BE5B786B89FF85F10F62DE85C433EE12621EED
              (la pública se sirve en /sm8750/pocknix-repo.gpg)
Cuenta CF   : bef98237407494c86d368d3ab4ce5cd4
```

**Publicar** (en el PC, dentro de `~/pocknix-odin3-project/pocknix-os`):
```sh
export POCKNIX_REPO_RCLONE_REMOTE="r2:pocknix"
export POCKNIX_REPO_GPG_KEY="80BE5B786B89FF85F10F62DE85C433EE12621EED"
export POCKNIX_REPO_URL="https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev"

# primera publicación de un árbol (o reposición desde el localrepo):
POCKNIX_PUBLISH_FROM=localrepo make publish DEVICE=sm8750
POCKNIX_PUBLISH_FROM=localrepo make publish-shared
# ⚠️ ese modo PURGA el bucket con lo que haya en el directorio: comprobar ANTES
#    que el localrepo contiene todos los paquetes ya publicados, o se borrarán.

# flujo normal (cuando ya hay árbol staged):
make stage PKG="..."   &&   make publish DEVICE=sm8750     # por SoC
make stage-shared PKG="..." && make publish-shared         # neutral
```
**Verificar** siempre por la URL pública (`curl -I`) y con `pacman -Sy` contra un `pacman.conf` de
prueba — como hará una consola.

**La Odin ya apunta a nuestro repo** (aplicado hoy): `[pocknix]` → `/sm8750` y
`[pocknix-shared]` → `/shared`, **primero en la lista**; `[pocknix-base]` y ALARM intactos.
Reverso: `sudo cp /etc/pacman.conf.bak-nuestro-repo /etc/pacman.conf` + `pacman -Sy` +
`pacman-key --delete 80BE5B786B89FF85F10F62DE85C433EE12621EED`.

---

## 3. PENDIENTE DE SUBIR / HACER

| # | Qué | Dónde |
|---|---|---|
| 1 | **El arreglo del updater** (§1) — lo único que bloquea a un usuario normal | nuestro repo |
| 2 | **Aplicar la actualización pendiente** en la Odin (3 paquetes: `f2fs-tools`, `libretro-cores-pocknix 0.1.0-7`, `pocknix-steam-full 0.1.0-3`) | Odin |
| 3 | **Regenerar el Secret de R2** (el actual se compartió por chat) | Cloudflare |
| 4 | **Dominio propio** en vez de `r2.dev` (que es de pruebas) | Cloudflare |
| 5 | **`nodatacow`** (aparcado por decisión de Fransis) | Odin |
| 6 | **Wind Waker HD**: esperando arreglo upstream del `nn_olv`; el issue #6 está abierto y hay vigilante | upstream |
| 7 | **`libretro-cores-pocknix` 0.1.0-6 → 0.1.0-7** y demás: comprobar que nuestro `localrepo` está al día antes del próximo publish | PC |

---

## 4. LO HECHO HOY (contexto, para no repetirlo)

- **Odin**: mando, Xenia, MSX2 (`fmsx`), 3DS (core libretro), aviso de ES-DE, Baloo, reglas udev,
  y el **WiFi arreglado** con el parche de Valve (ath12k, IOMMU `DMA-FQ`, `0x110e`).
- **Firmware del SM8750 como PAQUETE** (`pocknix-firmware-sm8750`): en `/usr/lib/firmware/updates/`,
  compilado, instalado en la Odin, **probado tras reinicio**, y **reportado a shuuri**
  (PR #81, comment `5971918567`).
- **ES-DE** ya no muestra sistemas sin emulador (`<system>` vacíos fuera, commit `1cbb607`).
- **Nuestro repositorio propio**: creado, firmado y publicado; la Odin bebe de él.
- **Wind Waker HD**: extraído, recompilado y compilado en el PC; se queda en un SIGSEGV por
  `nn_olv` sin implementar → issue #6 + doc en `arcadematicas/wind-waker-recomp-tools`.

Docs relacionados: `FIRMWARE-SM8750-PACKAGE.md`, `ATH12K-ODIN3.md`, `ES-DE-EMULADORES-AUSENTES.md`.
