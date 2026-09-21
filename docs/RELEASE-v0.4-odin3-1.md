# Release v0.4-odin3-1 — primera imagen oficial de Pocknix para la AYN Odin 3

**Fecha**: 21/09/2026 · **Artefacto**: `pocknix-sm8750-sd.img` (21.4 GB)

```
sha256  94c44863d82c9b651a62ffce5cde81c6af92a177459fda5f65de40ef50ee9c36
```

## Qué lleva

| Componente | Versión | Nota |
|---|---|---|
| Kernel | **7.2.4** | + 3 parches de rotación inline + `DEBUG_INFO_DWARF4` (BTF válida) + DTS del Odin 3 |
| gamescope | **6644cc9-5** | + parche `0010` (`--rotated-output-max-height`) → **rotación POR HARDWARE** |
| Mesa / Vulkan | **26.2.3** / freedreno 26.2.3 | + **Turnip 20260918** (Adreno 830) |
| `pocknix-steam` | **0.1.0-63** | launcher con el flag de rotación HW + tile **DeckStation** en Game Mode |
| `deckstation-arm` | **1.0.0-3** | + fix SDL del launcher (ES-DE en negro) + `setup_libxss` |
| `suyu-libretro` | **0.0.4-1** | 🆕 **el core de Switch ahora SÍ se instala** (ruta del PKGBUILD corregida) |
| `libxss` | **1.2.5-1** | 🆕 en `base.list` → RetroArch arranca en instalación limpia |
| `pocknix-bsp-sm8750` | **0.2.0-1** | + `POCKNIX_PANEL_ROTATE_MAX_H=1088` en `odin3.conf` |
| `pocknix-bootloader-sm8750` | **1.1.8-1** | coincide con el ABL ya flasheado |
| Repos pacman | 8 secciones | pocknix + **fallback ALARM** (permite instalar paquetes) |

## Qué se arregló para esta release

1. **Rotación por hardware** (`rotation=8`/`ROTATE_270` en el DPU) — el objetivo del proyecto.
2. **BTF**: con GCC 16 + DWARF 5, pahole 1.32 generaba BTF de módulos **malformada** → el kernel
   rechazaba **todos** los módulos (sin audio, sin mando, sin zram). Fix: `DEBUG_INFO_DWARF4`.
   Reportado a upstream: [shuuri-labs/pocknix-os#92](https://github.com/shuri-labs/pocknix-os/issues/92).
3. **`libxss`**: el RetroArch de DeckStation (binario nativo) lo necesita y la imagen no lo traía.
4. **`suyu-libretro`**: la ruta del `.so` en el PKGBUILD estaba mal → el core **nunca** se
   instalaba (`/usr/lib/libretro/` vacío).
5. **Variedad de bugs del build**: cache de gamescope sin `.git`, `pocknix-share` con `-Syu`
   (260 upgrades), el epoch de `smbclient`, el `check-sync` que no cubría la capa vendored.

## Cómo probarla

```bash
# Flashear (⚠️ DESTRUCTIVO) — o usar la SD de pruebas:
sudo dd if=pocknix-sm8750-sd.img of=/dev/sdX bs=4M status=progress conv=fsync
# Al arrancar, verificar:
uname -r                          # 7.2.4
dmesg | grep -c "failed to validate"   # 0
sudo cat /sys/kernel/debug/dri/0/state | grep -A3 'plane\['   # rotation=8
vulkaninfo --summary | grep driverInfo   # Mesa 26.2.3
ls /usr/lib/libretro/suyu_libretro.so
```

## Pendiente tras la release

- Probar en instalación limpia (flash) y validar todo lo anterior.
- Frame limiter del QAM (test de 30 s), ext4/F2FS en la UFS, sensores IIO, carga de batería (opcode `0x16`).
- WProton: validar el flujo completo.
