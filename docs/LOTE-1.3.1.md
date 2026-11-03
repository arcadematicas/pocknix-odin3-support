# Lote CalvOS 1.3.1 (borrador) — pendiente de validar en consola

> Paquetes construidos el 3/11/2026. **No publicar hasta validarlos en la Odin.**

## Paquetes

| Paquete | Versión | Repo | Qué trae |
|---|---|---|---|
| `linux-pocknix-sm8750` | 7.2.12-**30** | soc | dtb de la Odin 3 con el **LED de carga** (`&pm8550_pwm` multi-led rojo/verde) |
| `pocknix-bsp-sm8750` | 0.2.0-**43** | soc | servicio `odin3-charge-led` (rojo cargando / verde llena) + preset |
| `pocknix-decky` | 0.1.0-**65** | shared | **PluginLoader-arm64 nativo v3.3.1** (sin FEX), updater y sync migrados |
| `deckstation-arm` | 1.0.0-**18** | shared | Updater con OpenROM 3.9.5 (AppImage GUI + Core zip) |

Notas:
- El kernel 29 se descartó: se empaquetó con el dtb de pruebas (puerto SWR 5). El 30 es el bueno.
- `pocknix-decky` mantiene las dependencias `fex-emu`/`fex-rootfs` aunque el loader ya no las use
  (FEX sigue haciendo falta para Steam; quitarlas del paquete no ahorra nada y evita sorpresas).

## Validación en la Odin (en este orden)

```bash
# 1) kernel + bsp (el kernel-guard reiniciará UNA vez: es normal)
echo pocknix | sudo -S pacman -U \
  /tmp/linux-pocknix-sm8750-7.2.12-30-aarch64.pkg.tar.xz \
  /tmp/pocknix-bsp-sm8750-0.2.0-43-any.pkg.tar.xz
sudo reboot

# 2) tras el reinicio
systemctl status odin3-charge-led        # active
ls /sys/class/leds/rgb:charging          # existe
cat /sys/class/leds/rgb:charging/multi_intensity   # 255 0 con cargador
# probar también: desenchufar (se apaga) y 100 % (verde)

# 3) decky arm64
echo pocknix | sudo -S pacman -U /tmp/pocknix-decky-0.1.0-65-any.pkg.tar.xz
sudo systemctl restart pocknix-decky-loader
systemctl status pocknix-decky-loader pocknix-decky-sync
file /home/deck/homebrew/services/PluginLoader   # aarch64
# QAM de Decky: abre, panel de control, plugins; sin FEX en el proceso
pgrep -af PluginLoader | head

# 4) OpenROM (deckstation-arm 18): Updater -> OpenROM -> Reinstalar/actualizar
#    y una conversión por lotes de prueba
```

## Si algo falla

- Decky no arranca: volver a `pocknix-decky-0.1.0-64` (x86+FEX) y mirar
  `journalctl -u pocknix-decky-loader -b`.
- LED no enciende: comprobar que el dtb cargado es el 30 (`dtc` sobre `/boot/dtbs/...` o el sysfs
  del nodo) y que `rgb:charging` existe.
- Kernel: el guardia compara md5; tras instalar el paquete el hook reconstruye `/flash/KERNEL`.

## Publicación (solo tras validar)

```bash
cd ~/pocknix-odin3-project/pocknix-os
make stage PKG="linux-pocknix-sm8750 pocknix-bsp-sm8750"     # repo soc
make stage-check
make publish
make stage-shared PKG="pocknix-decky deckstation-arm"        # repo shared
make stage-check-shared
make publish-shared
```
