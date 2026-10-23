# `pocknix-install-internal` parcheado: `--exclude`

Copia del instalador de `pocknix-tools` (el del sistema, versión del 14/10) con **una** extensión:

```sh
pocknix-install-internal --exclude /opt --userdata-gib 1
```

- **`--exclude DIR`** (repetible): no clona `DIR` y **descuenta su tamaño** del cálculo de espacio.
  Sin esto el instalador exige que TODO el root de la SD quepa en la interna; con `/opt` fuera
  (325 GiB de juegos/ROMs: DeckStation + WProton) el clon baja a **94 GiB**.
- Los directorios excluidos se crean vacíos en el destino; luego se montan desde la SD
  (`/opt/deckstation`, `/opt/wproton`) con entradas de fstab.

## Contexto (Odin 3 de Fransis)
- Interna: 226 GB (modelo 256 GB) → **~196 GiB** útiles para Pocknix.
- SD: 1 TB, root con 419 GiB usados (325 de ellos en `/opt`).
- Sin `--exclude`: `mode=nofit` (faltan 244 GiB). Con `--exclude /opt`: `sd_used_gib=94` ✅.

## Después de instalar
1. Apagar, **quitar la SD**, arrancar (ya en interna).
2. Para seguir usando los juegos de la SD: neutralizar el arranque de la SD (borrar su partición
   FAT de boot, conservando la btrfs) y montar su `@` en `/mnt/sd-legacy`; luego:
   ```
   /mnt/sd-legacy/opt/deckstation  /opt/deckstation  none  bind  0 0
   /mnt/sd-legacy/opt/wproton      /opt/wproton      none  bind  0 0
   ```
3. Revertir: `pocknix-uninstall-internal` desde la SD.
