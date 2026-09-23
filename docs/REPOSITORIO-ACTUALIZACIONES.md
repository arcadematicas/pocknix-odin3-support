# Repositorio y actualizaciones — GUÍA COMPLETA (releases, paquetes, updates)

> Estado: 23/09/2026 · Decisión tomada: **alojar todo en nuestro GitHub (GitHub Releases, 0 €)**.
> Esta guía es la referencia para gestionar: (1) nuestros paquetes, (2) las releases,
> (3) las actualizaciones de la Odin. Pensada para retomarla mañana sin contexto previo.

---

## 0. El modelo en 30 segundos

- Pocknix ya tiene **3 repos pacman** y un flujo de publicación construido en `pocknix-os`.
- **`[pocknix]`** (per-SoC, paquetes tuneados) y **`[pocknix-shared]`** (SoC-neutral) son los
  que publicamos **NOSOTROS** → irán a **GitHub Releases** (gratis).
- **`[pocknix-base]`** (base ALARM congelada) lo publica **upstream** (shuuri-labs) en
  `pocknix.shuuri.net` → lo usamos tal cual, no lo tocamos.
- La Odin actualiza con `pacman -Syu` (el "Pocknix Updater" de Plasma). Seguridad ya montada:
  snapshots btrfs + rollback + base congelada.
- **Regla de oro**: se edita SIEMPRE en el **centro** (`pocknix-odin3-support`); el árbol
  (`pocknix-os`) es solo compilación y se regenera con `tools/sync-to-os.sh`.

| Repo pacman | Contenido | Quién publica | Dónde (futuro) |
|---|---|---|---|
| `[pocknix]` | Per-SoC sm8750: kernel, BSP, bootloader, device, soc-overrides, gamescope, mesa tuneado | **Nosotros** (y upstream cuando fusione el PR #81) | GitHub Releases |
| `[pocknix-shared]` | SoC-neutral: `pocknix-*`, deckstation-arm, emuladores del árbol, plasma-mobile... | **Nosotros** | GitHub Releases |
| `[pocknix-base]` | Base ALARM congelada (snapshot `20260826.2`) | Upstream | `pocknix.shuuri.net/repo/base` |

---

## 1. Gestión de NUESTROS paquetes

### 1.1 Dónde vive cada paquete

| Tipo de paquete | Vive en el centro | Se compila a | Va al repo |
|---|---|---|---|
| Per-SoC (kernel, BSP, bootloader, device, soc-overrides, gamescope, mesa) | `pocknix-odin3-support/packages/<nombre>` | `build/localrepo/sm8750` → `[pocknix]` | `pocknix.db.tar.gz` |
| SoC-neutral (`pocknix-*`, deckstation-arm, emuladores...) | `pocknix-os/packages/shared/<nombre>` (algunos se editan en el centro y se sincronizan) | `build/localrepo/shared` → `[pocknix-shared]` | `pocknix-shared.db.tar.gz` |

- **Los per-SoC del centro** se sincronizan al árbol con `sync-to-os.sh` (mirror de
  `packages/pocknix-bsp-sm8750`, `pocknix-device-sm8750`, `linux-pocknix-sm8750`,
  `pocknix-bootloader-sm8750`, `soc-overrides/...`).
- **Los shared** se editan directamente en el árbol (p. ej. `pocknix-branding`), salvo los
  que el centro sobrescribe (deckstation-arm, pocknix-desktop, pocknix-bsp-common, gamescope).
- **`check-sync.sh` aborta el build si el árbol no coincide con el centro** — nunca edites
  en el árbol algo que el centro posee.

### 1.2 Estructura de un paquete (PKGBUILD)

Cada paquete es un directorio con un `PKGBUILD` + los archivos que instala. Ejemplo real
(`pocknix-decky`, centro):

```
packages/pocknix-decky/
├── PKGBUILD              # pkgname, pkgver, pkgrel, depends, source, package()
├── pocknix-decky-run     # scripts/binarios que instala
├── pocknix-decky-sync
├── *.service
├── PluginLoader.json
├── mako/                 # subcontenido que copia al pkgdir
└── mako-aarch64.patch
```

Puntos clave de un PKGBUILD propio:
- `pkgname`, `pkgver`, `pkgrel` — **pkgrel es el contador de revisiones**: cada cambio
  sube `pkgrel` en 1 (o `pkgver` si cambia la versión del software).
- `arch=('any')` para scripts/configs; `('aarch64')` para binarios.
- `source=()` con rutas relativas al dir del paquete (se referencian con `${startdir}`).
- `package()` instala con `install -Dm755/-Dm644` a `${pkgdir}/...`.
- `sha256sums=('SKIP' ...)` para archivos locales; hash real para descargas externas.

### 1.3 Versionado — LA REGLA CRÍTICA

> **NUNCA republicar el mismo nombre de archivo con bytes distintos.**
> pacman cachea por nombre de archivo; si re-subes `pocknix-tools-0.1.0-12-any.pkg.tar.zst`
> con contenido distinto, los clientes con caché se rompen (y las firmas no cuadran).
> **Siempre se sube `pkgrel`** (o `pkgver`) antes de publicar.

### 1.4 Compilar los paquetes

```bash
cd pocknix-os
make packages PKG="pocknix-branding deckstation-arm"   # compila solo esos (sudo)
make packages                                           # todo (lento)
```

- Los paquetes `packages/soc/*` se compilan en el chroot per-SoC → `[pocknix]`.
- Los `packages/shared/*` se compilan UNA vez → `[pocknix-shared]` (byte-idénticos entre SoCs).
- Los paquetes de emulación pesada (`dolphin-emu`, `azahar`, `es-de`, `rpcs3-bin`...) solo se
  compilan con `POCKNIX_EMULATION=1` (guard en `build-packages.sh`).
- Resultado: `build/localrepo/sm8750/*.pkg.tar.zst` + `build/localrepo/shared/*.pkg.tar.zst`
  con sus `pocknix.db` / `pocknix-shared.db`.

---

## 2. Gestión de RELEASES (publicar a GitHub)

### 2.1 El modelo con GitHub Releases

- **Un repo GitHub por árbol pacman** (para que `latest/download` sea estable y no haya
  colisiones de nombres entre SoCs):
  - `arcadematicas/pocknix-repo` → árbol `[pocknix]` de sm8750 (db `pocknix.db.tar.gz`)
  - `arcadematicas/pocknix-repo-shared` → árbol `[pocknix-shared]` (db `pocknix-shared.db.tar.gz`)
- **Un ÚNICO release "repo" por repo GitHub**, actualizado en cada publicación con
  `gh release upload --clobber` (reemplaza archivos). Nunca crear releases nuevos acumulativos.
- **URL estable** que usa la Odin:
  `https://github.com/arcadematicas/pocknix-repo/releases/latest/download/<archivo>`
- Límites que nos valen: 2 GB/archivo (el mayor, fex-rootfs ~1,1 GB), 100 GB/repo
  (nuestro repo completo ~2,6 GB), ancho de banda sin límite duro. **Coste: 0 €.**

### 2.2 Flujo de publicación (paso a paso)

```bash
# 1. Editar en el CENTRO (fuente de verdad) y sincronizar al árbol
cd pocknix-odin3-support
tools/sync-to-os.sh
tools/check-sync.sh                    # debe decir OK

# 2. Compilar los paquetes tocados
cd ../pocknix-os
make packages PKG="pocknix-branding deckstation-arm ..."

# 3. Stage: espeja el repo LIVE y mete SOLO lo nuevo (validación)
make stage DEVICE=sm8750 PKG="pocknix-branding deckstation-arm ..."
make stage-shared PKG="..."            # para el árbol shared

# 4. Publish: firma + repo-add + subida
make publish DEVICE=sm8750             # -> [pocknix] (adaptado a GitHub Releases)
make publish-shared                    # -> [pocknix-shared] (adaptado)
```

**Adaptación pendiente de `publish-repo.sh`** (tarea de mañana): en vez de `rclone sync`
al bucket, subir con `gh release upload --clobber` al release "repo" del repo GitHub
correspondiente. El resto (stage → firmar → repo-add) se reutiliza intacto.

### 2.3 Firma GPG — clave NUESTRA

- La clave "Pocknix Packaging" es de upstream y **su privada NO está en este PC**.
- **Tarea de mañana**: generar nuestra propia clave (`gpg --full-generate-key`, p. ej.
  "calvOS Packaging"), exportar la pública y **commitearla en `pocknix-os/config/pocknix-repo.gpg`**
  (la imagen la hornea y la lsigna → los dispositivos confían de fábrica).
- `POCKNIX_REPO_GPG_KEY` en `config/pocknix.conf` apunta a la identidad que firma.
- Las imágenes construidas ANTES del cambio de clave no confiarán en el repo nuevo (no
  importa: no hay repo sm8750 publicado aún; la próxima imagen ya llevará la clave nueva).

### 2.4 Stanza en la Odin (adaptación pendiente)

`build-image.sh` escribe la stanza con `Server = ${POCKNIX_REPO_URL}/${SOC}` y
`.../shared`, pero GitHub Releases es **plano** (sin subdirectorios). Pendiente:
- Ajustar `build-image.sh` (o el overlay) para que la Odin use:
  ```
  [pocknix]
  SigLevel = Required DatabaseOptional
  Server = https://github.com/arcadematicas/pocknix-repo/releases/latest/download

  [pocknix-shared]
  SigLevel = Required DatabaseOptional
  Server = https://github.com/arcadematicas/pocknix-repo-shared/releases/latest/download
  ```
- `[pocknix-base]` sigue apuntando a `pocknix.shuuri.net/repo/base` (upstream).

---

## 3. Gestión de ACTUALIZACIONES (en la Odin)

### 3.1 Qué actualiza cada cosa

| Qué | Cómo se actualiza | Quién lo gestiona |
|---|---|---|
| Sistema base (kernel, BSP, pocknix-*, emuladores del árbol) | `pacman -Syu` (Pocknix Updater de Plasma) | Nuestro repo GitHub |
| Base ALARM congelada | `pacman -Syu` (desde `[pocknix-base]`) | Upstream (shuuri) |
| Emuladores de terceros (rpcs3, duckstation, ppsspp, shadps4, eden...) | Centro de Mando DeckStation (baja releases de GitHub/Gitea) | Independiente del sistema |
| Imagen SD completa | Reflash (solo 1ª instalación o cambios no actualizables) | `make publish-image` |

### 3.2 Seguridad ya montada (no hay que hacer nada)

- **Snapshots btrfs automáticos** antes de cada transacción (hooks alpm de
  `pocknix-snapshots`) + `pocknix-rollback` para volver atrás.
- **Base congelada**: `pocknix-base-lock` evita que un rolling de ALARM rompa el sistema.
- El Updater de Plasma siempre hace `-Syu` (nunca `-Sy` solo — trampa de actualización parcial).

### 3.3 Flujo de una actualización típica

1. En el PC: editar centro → `sync-to-os.sh` → `make packages` → `make stage` → `make publish`.
2. En la Odin: el usuario abre **Pocknix Updater** (o `sudo pacman -Syu`).
3. Si algo falla: `pocknix-rollback` restaura el snapshot previo.

---

## 4. PLAN PARA MAÑANA (checklist concreto)

### Fase 1 — Infraestructura (una vez)
- [ ] Generar clave GPG propia: `gpg --full-generate-key` (p. ej. "calvOS Packaging").
- [ ] Exportar la pública y commitearla en `pocknix-os/config/pocknix-repo.gpg`.
- [ ] Crear repos GitHub: `arcadematicas/pocknix-repo` y `arcadematicas/pocknix-repo-shared`.
- [ ] Crear el release "repo" inicial en cada uno (vacío o con el primer contenido).
- [ ] Adaptar `publish-repo.sh`: subir con `gh release upload --clobber` en vez de rclone
      (según scope: `[pocknix]` → `pocknix-repo`, `[pocknix-shared]` → `pocknix-repo-shared`).
- [ ] Adaptar `build-image.sh` (o overlay) para el stanza plano de GitHub Releases
      (sin `/sm8750` ni `/shared` en la URL).

### Fase 2 — Primera publicación real
- [ ] `make packages` (todo lo necesario) + `make stage DEVICE=sm8750` + `make stage-shared`.
- [ ] `make publish DEVICE=sm8750` + `make publish-shared` → subir a GitHub Releases.
- [ ] Verificar desde un PC: `curl -I .../releases/latest/download/pocknix.db.tar.gz` → 200.

### Fase 3 — Validar en la Odin
- [ ] Reconstruir la imagen (v0.4-odin3-2) con la clave nueva + el stanza nuevo.
- [ ] En la Odin: `sudo pacman -Syu` → debe sincronizar los 3 repos sin errores.
- [ ] Probar una actualización real de un paquete nuestro (p. ej. bump de `pocknix-branding`).

### Fase 4 — Cuando upstream fusione el PR #81
- [ ] Decidir: ¿la Odin usa `[pocknix]` de upstream (pocknix.shuuri.net) para el SoC, o
      seguimos con el nuestro? (calvOS independiente = el nuestro; fork = el de upstream).
- [ ] Si calvOS se independiza: el PR #81 queda como regalo a la comunidad.

---

## 5. Referencias rápidas

- `pocknix-os/Makefile` — targets `packages/stage/publish/publish-shared/publish-image/snapshot`.
- `pocknix-os/scripts/build-packages.sh` — compila (chroot aarch64, `[pocknix]` vs `[pocknix-shared]`).
- `pocknix-os/scripts/stage-repo.sh` / `publish-repo.sh` — validación + firma + subida.
- `pocknix-os/scripts/build-image.sh` — stanza pacman en el dispositivo + guard `POCKNIX_SHIP_SOC_REPO`.
- `pocknix-os/config/pocknix.conf` — `POCKNIX_REPO_URL`, `POCKNIX_REPO_GPG_KEY`,
  `POCKNIX_REPO_PUBKEY`, `POCKNIX_REPO_RCLONE_REMOTE`, `POCKNIX_BASE_SNAPSHOT`.
- `pocknix-odin3-support/tools/sync-to-os.sh` / `check-sync.sh` — centro → árbol.
- `pocknix-odin3-support/docs/PR-DESCRIPTION.md` — qué lleva el PR #81 (lo que publicará upstream).
- `pocknix-os/packages/shared/pocknix-snapshots/` — snapshots btrfs + rollback.
- `pocknix-os/packages/shared/pocknix-base/` — `pocknix-update` (Updater de Plasma).
- Datos medidos: repo completo ~2,6 GB (`build/localrepo`); paquete mayor fex-rootfs ~1,1 GB.