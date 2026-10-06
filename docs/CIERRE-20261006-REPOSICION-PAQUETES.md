# CIERRE 2026-10-06 — Reposición de los 6 paquetes retirados + estructura de metapaquetes

## Qué se hizo
1. Se repusieron y PUBLICARON los 6 paquetes que habían sido retirados de `[pocknix-shared]`:
   `plutovg 1.3.3-1`, `plutosvg 0.0.8-1`, `pocknix-soname-compat 1.3.4-1`,
   `pocknix-vk-valve 20260927-1`, `pocknix-steam-full 0.1.0-4`, `libretro-cores-pocknix 0.1.0-7`.
2. Se arregló la estructura de metapaquetes para que TODO lo nuestro sea alcanzable desde las
   raíces del stage-check (metapaquetes) — los 10 warns "no root reaches it" quedaron en 0.

## Metapaquetes tocados (y por qué)
| Paquete | Edición | Por qué |
|---|---|---|
| `pocknix-steam-full` 0.1.0-3 → **-4** (centro) | depends += `gamescope-session-steam` | cubre gamescope-session y gamescope-session-steam (sesión Steam en gamescope) |
| `deckstation-arm` 1.0.0-13 → **-14** (centro) | depends += `wproton-arm` | WProton es el compañero de DeckStation; con su edge alcanza también python-requests y python-pygame-ce (ya son depends suyos) |
| `pocknix-emulation-full` 0.1.0-3 → **-5** (árbol, solo árbol) | depends += `suyu-libretro` `deckstation-arm`; **`armsx2-bin`/`rpcs3-bin`/`xemu-bin`/`vita3k-bin` movidos de depends a optdepends**; marcador `nodeps` | suyu y deckstation son paquetes reales publicados; los 4 emuladores NUNCA existen en ningún repo (fuentes fuera / no build qemu — ver guard `POCKNIX_EMULATION_PKGS` en build-packages.sh): como depends rompían el resolve del stage-check y el build (`makepkg -s`); como optdepends son "bring your own" (mismo patrón que dolphin/azahar/cemu) y el gate los tolera |
| `pocknix-desktop-full` 0.1.0-2 → **-3** (árbol, solo árbol) | depends += `pocknix-gamepad-calibration` `pocknix-wsquashfs` | calibración de mando en modo desktop; wsquashfs = menús de Dolphin/KDE (capa desktop); gamepad-calibration cubre además python-pyxel |

`pocknix-emulation-full` y `pocknix-desktop-full` no tienen copia en el centro: se editaron en el
árbol (`pocknix-os`) y se commitean allí (y también el fix real del resolve: optdepends).

## Hallazgo / decisión importante
`pocknix-emulation-full` traía en `depends=` 4 paquetes que **no existen en ningún repo**
(`armsx2-bin`, `rpcs3-bin`, `xemu-bin`, `vita3k-bin`). Consecuencias: el build fallaba
(`makepkg -s` no podía resolverlos) y el resolve del stage-check fallaba igual. Se movieron a
`optdepends` con comentario (patrón ya documentado en el PKGBUILD: "a failed optional build
cannot block the layer"). Nota: por eso `make packages PKG="pocknix-emulation-full"` exige
`POCKNIX_EMULATION=1` (guard `POCKNIX_EMULATION_PKGS`) y ahora el marcador `./nodeps`.

## Stage-check
- `make stage-shared PKG="plutovg plutosvg pocknix-soname-compat pocknix-vk-valve
  pocknix-steam-full libretro-cores-pocknix pocknix-emulation-full pocknix-desktop-full
  deckstation-arm"` → **EXIT 0, 45 staged, delta +9 -3, 0 FAIL, 0 warns**.
- Se publicó con `make publish-shared` (nunca `POCKNIX_PUBLISH_FROM=localrepo`); staging re-hecho
  desde live (swap del marker; el intento previo con `-4/armsx2` en depends quedó con el marker
  retirado por el propio gate, como debe ser).

## Publicación y verificación
- Publicado: `r2:pocknix/shared` = 45 paquetes + `pocknix-shared.db(.tar.gz)` + `pocknix-repo.gpg`
  + sigs. Fuera: `steam-full-3`, `emulation-full-3`, `desktop-full-2`, `deckstation-arm-10`
  (el delta -3 vino del live viejo, prunado por publish).
- Verificación por URL pública (`https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev/shared`):
  - HTTP 200 en db, gpg, los 4 metapaquetes nuevos y sus `.sig`.
  - `gpg --verify` de `pocknix-shared.db.tar.gz` y de `pocknix-steam-full-0.1.0-4`:
    "Firma correcta de pocknix-repo@arcadematicas" (clave 80BE5B…).
  - pacman (dbpath desechable, Architecture=aarch64, repo → URL pública): 45 paquetes parseados;
    `-Si pocknix-emulation-full` muestra depends reales (suyu-libretro, deckstation-arm) y los 4
    emuladores en OptDepends.
- La Odin sigue inaccesible: la verificación real de instalación queda pendiente de la Odin.

## No se rompió nada publicado
- `pocknix-base 0.2.0-7` y `pocknix-decky 0.1.0-48` NO se tocaron (siguen en live, intactos).

## Commits
- Centro (`pocknix-odin3-support`, master): 2 PKGBUILD (`pocknix-steam-full` -4,
  `deckstation-arm` -14) + este doc.
- Árbol (`pocknix-os`, rama `odin3-sm8750`): `9ba1db1` — re-add 6 paquetes retirados +
  metapaquetes alcanzables; pusheado a `arcadematicas/pocknix-os` (fast-forward 7e2dff1..9ba1db1).
  La rama local se realineó a la punta del fork (`git reset --mixed arcadematicas/odin3-sm8750`
  descartó el commit local viejo 90e4686, cuyo contenido ya está canónico en el fork).

## Abierto / notas
- El fix `declare -A added=() dropped=()` de stage-check.sh queda como WIP sin commitear en el
  árbol (no es nuestro; el fork funciona sin él en bash del PC).
- Verificación de instalación real en la Odin pendiente (host inaccesible).
