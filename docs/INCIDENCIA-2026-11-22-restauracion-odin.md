# Puesta a punto de la Odin reparada — 22/11/2026 (noche)

Instalación interna desde SD + restauración desde la Odin antigua. Fallos encontrados y arreglados.

## 1. El instalador interno dejaba la consola en un cursor parpadeando
`pocknix-install-internal` copia `KERNEL` (estilo qcom-abl), pero con **OpenABL** el arranque es
**BLS**: si no hay `/Image`, `/dtbs` y `/loader/entries/*.conf`, OpenABL no tiene qué arrancar.
- **Arreglado a mano** en esta unidad: `FLASH=/flash-interno ROOT_PARTUUID=<uuid interno> SRCROOT=/ /usr/lib/pocknix/pocknix-bls-deploy`.
- **Arreglado en el código**: el instalador ahora ejecuta `pocknix-bls-deploy` al terminar y avisa
  si no puede. Publicado en `pocknix-tools` (pendiente de número final).
- Los títulos del menú decían `Pocknix`; ahora `CalvOS` / `CalvOS (previous kernel)`.

## 2. `plasma-mobile` roto con Qt 6.12 → modo escritorio solo con fondo
`pocknix-desktop` arrancaba Plasma Mobile por defecto. Corregido en `pocknix-desktop 0.1.0-36`
(`DEFAULT=plasma`). En la SD se fijó además `~deck/.config/pocknix/desktop-session` = `plasma`.

## 3. Clave del repo desconocida en un sistema recién instalado
Al primer `pacman -Su`: `signature ... is unknown trust`.
- La clave del repo (`1B4CC22B5E95A4E28B001D7CC763314C4BBBAEF0`, `pocknix-repo@arcadematicas`)
  **no existe** en una instalación nueva hasta que se importa y se firma localmente.
- Arreglo aplicado: `pacman-key --lsign-key 1B4CC22B5E95A4E28B001D7CC763314C4BBBAEF0`.
- **Pendiente para imágenes**: incluir la clave y su firma local en la imagen (o en el hook de
  primer arranque), para que `pacman -Syu` funcione sin intervención.

## 4. Stack pipewire partido entre `pocknix-base` (-1) y `extra` (-2)
Igual que en la Odin antigua: instalar `gst-plugin-pipewire`/`gst-plugins-base` desde `extra`
choca con `pipewire-alsa`/`pipewire-pulse` de `pocknix-base` (-1).
- Arreglo puntual: forzar el stack completo desde `extra` en el mismo `pacman -S`.
- **Pendiente**: congelar `pipewire 1.6.11-2` en `pocknix-base` en la próxima base.

## 5. `deckard-vulkan-layers-linux-aarch64` no está en ningún repo
La Odin antigua lo tenía instalado, pero no existe en `pocknix*` ni en `alarm/core/extra`.
Debe de ser una instalación manual (AUR o binario suelto). No se ha restaurado; confirmar si se usa.

## 6. Restauración de datos
Canal SSH directo entre consolas (clave del usuario `deck` de la nueva autorizada en la vieja) y
`rsync` con exclusiones: `.cache`, `Downloads` (46 G de archivos ya extraídos), `.ssh`,
`.config/pocknix`, backups `*.pkg.tar.*`, `abl-rollback-*`, `branding-backup-*`, `backup-*`.
Se conserva el fix del escritorio (`.config/pocknix` no se sobrescribe).
