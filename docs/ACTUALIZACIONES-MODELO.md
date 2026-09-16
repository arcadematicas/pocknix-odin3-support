# Modelo de actualizaciones — análisis y propuesta (16/09/2026)

**Estado: PROPUESTA, pendiente de decidir.** Decisión provisional de Fransis (16/09): **de momento
NO montamos repo propio** — seguimos trabajando todo en GitHub. Este documento guarda el análisis
para cuando toque.

---

## Lo que Pocknix YA nos da (heredado, gratis)

| Pieza | Qué hace |
|---|---|
| `pocknix-snapshots` | **Snapshot btrfs automático antes de CADA transacción**, vía hook de alpm (`05-pocknix-snapshot.hook`, `PreTransaction`). Cubre todas las vías de actualización: QAM, `pocknix-update`, un `-Syu` por SSH. Guarda 5; lo salta si queda poco disco (`POCKNIX_SNAPSHOT_MIN_FREE_MIB`). Sin `AbortOnFail`: un snapshot que falle nunca bloquea el update. |
| `pocknix-rollback` | Vuelve a un snapshot con un **`btrfs set-default`** (un commit atómico). Funciona porque el fstab y el cmdline **no nombran subvolumen para `/`** → el kernel arranca el subvolumen por defecto. |
| Subvolúmenes aparte | `/home`, `/var/log`, `/.snapshots` y el caché de pacman → **sobreviven al rollback**. |
| `pocknix-rollback-repair` | Recupera los ficheros de arranque que un rollback interrumpido dejó como `/flash/*.new`. |
| `pocknix-update` | `pacman -Syu` (siempre `-Syu`, nunca `-Sy`: el `-Sy` sin `-u` es la trampa del *partial upgrade*). Con `pkexec` sin contraseña para `wheel` (regla `50-pocknix-deck.rules`). |
| Repo firmado | `https://pocknix.shuuri.net/repo` con GPG (`POCKNIX_REPO_SIGLEVEL=Required DatabaseOptional`), estructura `<base>/<soc>`. |
| Dos modos | Base **bloqueada** (`[pocknix-base]` congelada) o **rolling** (`/etc/pocknix/rolling-mode` = upgrade vivo de ALARM). |
| Publicación | `scripts/publish-repo.sh`, `scripts/stage-repo.sh`, `scripts/publish-image.sh`. |

**Conclusión**: pocknix ya usa "rolling + snapshots + rollback de un comando". Es prácticamente
atómico sin serlo.

---

## Qué hacen los demás (investigado 16/09)

| Proyecto | Modelo | Notas |
|---|---|---|
| **ROCKNIX** | **OTA por imagen completa** (descarga el `.tar` de la release → `/storage/.update` → reboot y se aplica). Sin repo pacman, sin A/B, sin rollback. | El más simple y el menos seguro: update fallido = reflashear. |
| **ArmadaOS** | **Fedora bootc** (imágenes OCI atómicas). `bootc update`, rollback por deployment (ostree), canales Beta/Preview desde los ajustes de Steam. Su `Containerfile` mete cada paquete propio como **capa OCI** (`ghcr.io/armada-os/armada-packages/kernel@sha256:…`), `bootc container lint`, `chunkah`, `system_files/` para las configs del dispositivo. | El caso más parecido al nuestro (handheld ARM, Odin 3) pero sobre Fedora. Avisan: *"Over-the-air updates are new and still being validated. You may need to reflash if an update fails."* |
| **SteamOS 3** | **Particiones A/B** (8 en total: esp, efi-A/B, rootfs-A/B, var-A/B, home) + **RAUC/casync**: el update escribe el nuevo rootfs en la partición inactiva y cambia el bootloader. `/etc` en **overlayfs** (upper en `/var/lib/overlays/etc/upper`); `/var/log`, `/root`, `/nix`… son bind-mounts desde `/home/.steamos/offload`. Updater moderno: `atomupd-manager`/`atomupd-daemon` (D-Bus). Software propio: Flatpak, distrobox/podman, Nix, `systemd-sysext` o `steamos-devmode` (desbloquea el rootfs y pierdes la inmutabilidad). | Referencia: https://iliana.fyi/blog/build-your-own-steamos-updates/ |
| **Bazzite / Universal Blue** | Imágenes **OCI construidas en CI**, publicadas en `ghcr.io`, firmadas con sigstore, **90 días de archivo** para rebase/rollback. `rpm-ostree`/`bootc`: se descarga en segundo plano y **aplica en el siguiente reinicio**. Rollback: `rpm-ostree rollback`, elegir `ostree:1` en GRUB, `ostree admin pin`, o **auto-rollback tras 3 arranques fallidos** (en handhelds). Aconsejan **NO** usar `rpm-ostree install` (capas en runtime): *"Layered packages can break system upgrades until removed"* → la vía es derivar tu propia imagen. | El mejor ejemplo de "base inmutable + capa propia + updates atómicos" mantenido por un equipo pequeño. |

---

## Propuesta: **híbrido** — rolling de Pocknix + nuestra capa en repo propio

**NO migrar a bootc/ostree** por ahora:
- No existe base `bootc` para **Arch ARM**; el ostree nativo de Arch es inmaduro y Pocknix no lo soporta.
- Habría que montar y mantener nosotros: pipeline OCI + registry + firmado + chunkah + CI.
- El BSP del SM8750 (kernel, firmware, bootloader) encaja **mucho mejor** con paquetes que con un
  pipeline de imágenes.
- SteamOS/A-B exige un particionado concreto desde fábrica.

### El modelo

```
        Base Pocknix  (repo firmado upstream — seguimos su rolling)
              +
        NUESTRA CAPA  (repo propio firmado)
          · pocknix-bsp-sm8750 + pocknix-device-sm8750
          · linux-pocknix-sm8750 + pocknix-bootloader-sm8750
          · deckstation-arm / wproton-arm / python-requests
          · pocknix-decky (MAKO) / pocknix-tools / pocknix-steamos-shim
          · nuestras versiones de gamescope / pocknix-desktop / pocknix-bsp-common
              +
        RED DE SEGURIDAD (ya en la base)
          · snapshot automático pre-transacción  →  rollback de un comando
```

### Hoja de ruta

| # | Qué | Por qué |
|---|---|---|
| 1 | **Meter el `overlay/` en un paquete** | Hoy `pocknix-diag.timer` y `pocknix-oobe-marker` van por el overlay de la **imagen** (los copia `build-sd-image.sh`) → **no se actualizan por OTA**. Es el bloqueante de que todo lo nuestro sea actualizable. |
| 2 | **Repo pacman propio firmado** (con `publish-repo.sh`, que ya existe) en un host estático | Es lo único que hay que montar de verdad. Candidatos: Cloudflare R2 (como upstream), un VPS, o cualquier host estático. |
| 3 | **Dos canales**: `stable` (probado) y `testing` (día a día) | Que un cambio no llegue a todos a la vez. |
| 4 | **Pinning** de la capa propia (kernel/BSP atados a versiones) | Un rolling de upstream no debe romper el BSP. Se puede usar el mecanismo de "base bloqueada" que ya existe. |
| 5 | **Imagen de fábrica reproducible** (lo que ya hacemos) | Para instalar de cero y para distribuir. |
| 6 | **Comprobación post-update** | Tras cada `-Syu`, verificar que arranca y que Decky/DeckStation cargan; si no, avisar (o auto-rollback). |

### ⚠️ Los tres riesgos honestos

1. **pacman no es atómico**: un update a medias puede romper. Lo cubre el snapshot — pero hay que
   ejecutar el update por una vía que lo dispare (el hook de alpm lo hace en todas).
2. **El kernel y el bootloader viven en `/flash`, FUERA del snapshot btrfs**: ahí está el riesgo real.
   Pocknix lo mitiga con ficheros `.new` + `pocknix-rollback-repair`, pero un fallo ahí exige
   intervención.
3. **La Odin 3 no tiene menú de arranque** (ABL, no GRUB): el rollback funciona **desde el sistema en
   marcha**. Si no arranca, no hay "elige la entrada anterior".

> **Por eso: tener SIEMPRE una SD de rescate preparada.** Nuestro equivalente al menú de GRUB.
> La SD de 128 GB con la imagen que ya funciona sirve perfectamente.
