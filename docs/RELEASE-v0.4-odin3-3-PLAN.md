# Plan de release **v0.4-odin3-3** (Odin 3) — borrador (09-oct-2026)

> Objetivo: una imagen nueva que nazca **con todo lo nuestro actualizado y funcionando**.

## ✅ Lo que YA entra (integrado, verificado)
- **Repos propios en R2** (`sm8750` + `shared` + `base`), firmados y en uso → las Odin se actualizan solas.
- Config: `POCKNIX_REPO_URL` = r2.dev, `SHIP_SOC_REPO=1` (stanza `[pocknix]`), tarball ALARM propio.
- **Kernel 7.2.9**.
- **CSS Loader + tema Hooandee Eclipse** de serie (pkgrel 49; auto-install del tema del catálogo oficial).
- **Panel de Control** de serie (pkgrel 50; seed-once para que se autoactualice).
- `pacman.conf` sin `[aur]`, con `[pocknix]`/`[pocknix-shared]`/`[pocknix-base]`.

## ⏳ Pendiente de cerrar ANTES del build
- **Deckard `release/0.5.x`**: decide si entra la **Turnip de Valve** (`gite07916b4`) — per-game (`VK_ICD_FILENAMES`)
  o sustituyendo la nuestra (riesgo). Las **layers Vulkan** (RPO/FDM) sí son fáciles de hornear.
  → Pruebas de estabilidad/FPS con Fransis. Ver `docs/DECKARD-0.5.x-INTEGRACION-2026-10-09.md`.

## Pasos del build
```bash
cd ~/pocknix-odin3-project/pocknix-os
tools/check-sync.sh                       # debe decir OK (centro == árbol)
DEVICE=sm8750 ./scripts/build-kernel.sh   # (si hace falta) kernel
sudo DEVICE=sm8750 make packages          # paquetes -> localrepo
sudo DEVICE=sm8750 make build             # -> build/image/sm8750/pocknix-sm8750-sd.img
sudo DEVICE=sm8750 make sd-image          # (si aplica)
```
- **Publicar** los paquetes actualizados en R2 antes/después: `make stage` + `make publish` (DEVICE=sm8750).
- **Verificar** la imagen montada (config/pacman, paquetes clave: kernel 7.2.9, mesa, gamescope, css-loader, panel).
- **Release notes** + GitHub release + partes para Telegram.

## Decisiones de Fransis
- **Nombre**: ¿`v0.4-odin3-3`?
- **Alcance**: solo Odin 3 (¿algo para Davidusky?).
- **Cuándo**: el build es pesado → PC libre.
