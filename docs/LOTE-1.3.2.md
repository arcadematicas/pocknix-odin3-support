# Lote CalvOS 1.3.2 — **PREPARADO, sin validar ni publicar (5/11/2026)**

> Construido el 4/11 por la noche. **No publicar hasta validarlo en la Odin.**
> El audio DP necesita además un dock/HDMI para la prueba final (davidusky).

## Paquetes

| Paquete | Versión | Repo | Qué trae |
|---|---|---|---|
| `linux-pocknix-sm8750` | 7.2.12-**32** | sm8750 | DTS con **`dp-dai-link`** ("DisplayPort Playback") + ventilador **sin `#cooling-cells`** (un solo escritor) |
| `pocknix-firmware-sm8750` | 0.1.0-**4** | sm8750 | tplg de armada con DP (`SM8750-AYN-tplg.bin`, 24.516 B, sha256 `821d52b7…`) → `/usr/lib/firmware/updates/` |
| `pocknix-bsp-sm8750` | 0.2.0-**44** | sm8750 | UCM con `SectionDevice."HDMI"` (`hw:${CardId},3`, `DP0 Jack`) |
| `pocknix-bsp-common` | 0.1.0-**25** | shared | ventilador suave: **EMA + histéresis 2 °C + rampa** (+40/−12 por tick) y fast-path a 255 si TMAX ≥ 90 °C |

Contexto ya publicado y ya instalado en la Odin (lote anterior):
`pocknix-branding 6`, `pocknix-base 10`, `pocknix-tools 22`, `pocknix-decky 67`,
`pocknix-bsp-common 24` (fix vhci del suspend) y el rebranding visible a CalvOS.

Notas:
- La tplg de armada es un binario de `armada-os/armada` (GPL-2.0). Si se publica, dejar la
  atribución en `docs/AUDIO-HDMI-20261025.md` y en el PKGBUILD del firmware.
- `cooling-levels` se queda en el DTS: sin `#cooling-cells` es inerte y documenta los niveles.
- El daemon del ventilador mantiene intactos modos, `SPEEDS`, `fan-mode` por juego y el `off`.

## Validación en la Odin (en este orden)

```bash
# 1) paquetes (el kernel-guard puede reiniciar una vez: es normal)
echo pocknix | sudo -S pacman -U \
  linux-pocknix-sm8750-7.2.12-32-aarch64.pkg.tar.xz \
  pocknix-firmware-sm8750-0.1.0-4-any.pkg.tar.xz \
  pocknix-bsp-sm8750-0.2.0-44-any.pkg.tar.xz \
  pocknix-bsp-common-0.1.0-25-any.pkg.tar.xz
sudo reboot
```

Tras el reinicio:

```bash
# audio base sigue bien
speaker-test -c 2 -t sine -l 1        # altavoz
# (auriculares: enchufar y comprobar que cambia la ruta)

# DP: debe existir el PCM 3 y el jack
aplay -l | grep -i MultiMedia4
amixer -c 0 cget name="DP0 Jack"

# ventilador: un solo escritor (ya no debe existir el cooling device del pwm-fan)
for c in /sys/class/thermal/cooling_device*; do cat "$c/type"; done | grep -c pwm-fan
cat /sys/class/hwmon/hwmon*/pwm1   # observar 2-3 min bajo carga: sin saltos 0<->225
journalctl -b -o cat | grep "vhci pre"   # breadcrumb del fix de suspend
```

Con dock/HDMI (la prueba de davidusky): `speaker-test -D hw:0,3 -c 2 -t sine` — detalle en
`docs/AUDIO-HDMI-20261025.md`.

## Criterio de aceptación

- [ ] Arranca y el audio de altavoz/auriculares sigue funcionando.
- [ ] `aplay -l` muestra `device 3: MultiMedia4 Playback` y existe `DP0 Jack`.
- [ ] El ventilador no oscila en el borde de un umbral; los cambios son graduales.
- [ ] Con dock, suena por HDMI/DP y el altavoz se mutea al enchufar (`JackHWMute`).
- [ ] El suspend en modo juego no aborta con EBUSY (breadcrumb `vhci pre` con `forced=` si hizo falta).

## Pendiente para después

- Reconciliar `pocknix-os` con el fork (10 commits por detrás): fex-emu 20261012,
  inputplumber 0.83, splash CalvOS de pocknix-steam 73, gamescope-session sin bucle mangoapp,
  desktop-kde con baloo off, overlay guard del kernel.
- Parche de armada que falta: `0081-ASoC-wcd939x-fix-headphone-analog-volume-controls.patch`
  (audio; evaluar si aplica a nuestro wcd939x).
- Panel de Control 0.84.0 (upstream 2026-11-04) — vendorizar y probar.
- Kernel 7.2.15 disponible (estamos en 7.2.12): evaluar re-sync + parches.

## Reconciliación del fork (5/11/2026)

`pocknix-os` estaba 10 commits por detrás (fex 20261012, inputplumber 0.83,
pocknix-steam 73 con splash CalvOS, gamescope-session sin bucle mangoapp, desktop-kde
con baloo off, kernel-guard y refactor de sabores). Merge hecho y pusheado.

Portado al **centro** para que el sync no lo revierta:
- `scripts/build-packages.sh`: fix "there is nothing to do" del fork **+** nuestro
  `clear_stale_repo_locks` (el fork partía de una base sin él).
- `packages/soc-overrides/fex-emu`: PKGBUILD 2610.20261012 (sin los 4 parches, ya no hacen falta).
- `overlay/`: `pocknix-kernel-guard(.service/.timer)`, `pocknix-kernel-pair` y el hook alpm
  `91-pocknix-kernel-pair.hook` (red de seguridad kernel/módulos).
- `packages/pocknix-desktop-kde` (nuevo) + mapeo en `sync-to-os.sh`/`check-sync.sh`.
- `packages/pocknix-steam/nodeps` (paquete de scripts: evita resolver gtk2/mangohud en el chroot).
- `packages/pocknix-decky/panel-de-control` re-vendorizado a **v0.84.0** (pkgrel 68).

Compilado y verificado: `inputplumber 0.83.0-1`, `pocknix-desktop 0.1.0-32`,
`pocknix-desktop-kde 0.1.0-3`, `pocknix-steam 0.1.0-73`, `gamescope-session 20260928-4`.
Pendiente de build: `pocknix-decky 68` y `fex-emu 2610.20261012`.

## Audio DP (5/11) — parche de armada + verbo Dock

- Kernel **7.2.12-33**: `10-mainline/0027` (hw_params en las ops de audio HDMI; fix de armada).
- `pocknix-bsp-sm8750 0.2.0-47`: `HiFi-Dock.conf` instalado pero **sin activar**; el UCM por
  defecto sigue sin HDMI (seguro sin dock).
- Kit de prueba con dock (davidusky): `packages/pocknix-bsp-sm8750/dock-kit/` +
  `docs/DOCK-AUDIO-TEST.md`.
