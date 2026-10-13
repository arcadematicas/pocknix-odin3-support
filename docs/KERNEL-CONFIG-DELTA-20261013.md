# DELTA DE CONFIG DEL KERNEL — cfg80211/mac80211 a módulo (13/10/2026)

## En una línea
`CONFIG_CFG80211=y` → `=m` y `CONFIG_MAC80211=y` → `=m` en **`pocknix-os/kernel/sm8750/config/linux.aarch64.conf`** (rama `odin3-sm8750`), para que el **regulatory domain del WiFi** se cargue desde `regulatory.db` en el arranque (dominio **ES** en 5 GHz / DFS).

## Fichero y líneas exactas

| Fichero | Línea | Antes | Después |
|---|---|---|---|
| `kernel/sm8750/config/linux.aarch64.conf` | **1708** | `CONFIG_CFG80211=y` | `CONFIG_CFG80211=m` |
| `kernel/sm8750/config/linux.aarch64.conf` | **1717** | `CONFIG_MAC80211=y` | `CONFIG_MAC80211=m` |

No se ha tocado NINGÚN otro `CONFIG_CFG80211_*` / `CONFIG_MAC80211_*` (verificado con grep: el único driver WLAN es `CONFIG_ATH12K=m`; `CONFIG_WLAN_VENDOR_ATH=y` es el gate; nada que dependa de estos dos quedó en `=y`). `sm8250`/`sm8550` siguen con `=y` (sin cambios).

md5 del fichero: antes `c9a429f1696e407a27153757c94ed59d` → después `92bfbf80037c119702c9363cb8ce7d0c`.

## Por qué
- Con **cfg80211 built-in** (`=y`), el kernel NO busca los **regulatory rules** en `regulatory.db` al arrancar (el `regdb` se carga vía `request_firmware`, que solo funciona para **módulos** sin initramfs): el dominio se quedaba en el **world domain** restrictivo → los canales 5 GHz salían `(no IR)` y no se podía asociar al AP (canal 116).
- En Arch/Pocknix el paquete `wireless-regdb` (ya en `config/packages/base.list`) instala `/etc/conf.d/wireless-regdom`, `/usr/bin/set-wireless-regdom` y `/usr/lib/udev/rules.d/85-regulatory.rules` (`ACTION=="add", SUBSYSTEM=="module", DEVPATH=="/module/cfg80211"` → ejecuta `set-wireless-regdom`). Ese udev rule **solo se dispara cuando cfg80211 es un módulo** que se carga → con `=m` el dominio ES se aplica en cada arranque.
- **`CONFIG_MAC80211=m` es imprescindible, no opcional**: un módulo (ath12k/cfg80211) **no puede depender de un símbolo built-in**; si cfg80211 fuera `=m` y mac80211 quedara `=y`, el build del módulo de cfg80211 fallaría. Ambos van a `=m`.
- El 85-regulatory.rules ya está en la imagen desde antes; lo único que faltaba era que **cfg80211 fuera módulo**.

## ⚠️ No se pierde en el próximo `make sync`
`make sync` (árbol: `scripts/sync.sh`) **sobrescribe** `kernel/sm8750/config/linux.aarch64.conf` desde ROCKNIX **y no está cubierto por `tools/sync-to-os.sh`** (ese fichero NO se sincroniza desde el centro). Por eso el delta se documenta aquí, y hay que **re-aplicarlo después de cada `make sync`** (grep rápido para comprobar):

```bash
cd pocknix-os
grep -nE '^CONFIG_(CFG80211|MAC80211)=' kernel/sm8750/config/linux.aarch64.conf
# debe dar:
#   CONFIG_CFG80211=m
#   CONFIG_MAC80211=m
```

## Cómo se lleva el país a la imagen (WIRELESS_REGDOM="ES")
No se mete `/etc/conf.d/wireless-regdom` como fichero de paquete: es propiedad de `wireless-regdb` (backup) y un segundo paquete que lo incluya produce **conflicto de ficheros de pacman** (reproducido con fakeroot: "ya existe en el sistema de archivos (es parte de ...)") → rompería el build de la imagen y el `-Syu`. Se fija de forma **idempotente** desde el `.install` de `pocknix-system-overlay`:

- `packages/pocknix-system-overlay/pocknix-system-overlay.install` → `_pocknix_set_wireless_regdom()` en `post_install`/`post_upgrade`:
  1. si hay una línea activa `WIRELESS_REGDOM=` → la reescribe a `WIRELESS_REGDOM="ES"`;
  2. si solo está comentada la de ES → la descomenta;
  3. si no existe → la añade.
- Y llama a `set-wireless-regdom` (best effort) para aplicarlo en caliente.

## Build / deploy / verificación

```bash
# 1) sincronizar el centro al árbol + comprobar
cd /home/fransis/pocknix-odin3-project/pocknix-odin3-support
./tools/sync-to-os.sh && ./tools/check-sync.sh

# 2) compilar el kernel (y los módulos) — DEVICE=sm8750 OBLIGATORIO
cd ../pocknix-os
sudo DEVICE=sm8750 make kernel

# 3) deploy a la Odin con kernel+módulos del MISMO build (por md5 del Image):
#    tools/deploy-to-device.sh — KERNEL -> /flash/KERNEL (backup previo), módulos
#    -> /lib/modules/<ver>/ copiando el CONTENIDO (no la carpeta), depmod -a <ver>
# 4) (imagen) el país llega vía pocknix-system-overlay (depende de pocknix-bsp-sm8750)

# 5) verificación en la Odin
dmesg | grep -i regulatory        # "cfg80211: Loaded X regulatory rules ... from regulatory.db" o similar
iw reg get                        # -> country ES: DFS-ETSI
iw phy phy0 info                  # 5 GHz SIN "(no IR)"
cat /etc/conf.d/wireless-regdom   # -> WIRELESS_REGDOM="ES"
```

## Dónde más queda documentado
- `docs/PENDIENTES-20261013.md` → bloque **A6** ("Hecho (tarea A6)").
- Este fichero es la referencia del delta para el próximo `make sync`.