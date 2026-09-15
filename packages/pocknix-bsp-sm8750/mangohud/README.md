# MangoHud con parches Qualcomm/SM8750 + toggle por paddle trasero

MangoHud compilado desde el source v0.8.4 con los **7 parches de ROCKNIX**
(common + qualcomm + SM8750) para el Odin 3, más configuración compacta y un
toggle accesible con el paddle trasero M2.

## Por qué los parches
El MangoHud genérico de Arch no lee bien el GPU del SM8750 en kernel mainline.
Los parches de ROCKNIX (`ROCKNIX/distribution/projects/ROCKNIX/packages/apps/mangohud/patches/`)
corrigen las rutas:
- `SM8750-GPU.patch`: temperatura desde `gpuss0_thermal` (hwmon) y frecuencia
  desde `/sys/class/devfreq/3d00000.gpu` (en vez de `/sys/class/kgsl/kgsl-3d0`).
- `Qualcomm-GPU-support`, `Qualcomm-battery-power_now`, `SM8750-Battery`, etc.

**Resultado**: la temperatura del GPU ya funciona en el HUD. Los **watios de
GPU/CPU NO son posibles** (este kernel no expone sensores de potencia) y el
**% de GPU da 0 con mangoapp** (no está inyectado en el juego — el % real solo
sale inyectando MangoHud en el juego con `MANGOHUD=1`).

## Compilación (cross, desde PC x86_64)
Se compiló en un rootfs **aarch64 + qemu** en la PC (16 cores), aplicando los 7
patches y las opciones de ROCKNIX:
```
meson setup build -Dwith_xnvctrl=disabled -Dwith_x11=enabled -Dmangoplot=disabled \
  -Dwith_wayland=enabled -Dmangoapp=true -Dwith_fex=true
```
Artefactos instalados en la Odin: `libMangoHud*.so` → `/usr/lib/mangohud/`,
`mangoapp` y `mangohud` (script) → `/usr/bin/`.

**Importante**: mangoapp es **autocontenido** (no usa `libMangoHud.so` en
runtime) — hay que reemplazar el binario `/usr/bin/mangoapp`, no solo las libs,
para que los parches surtan efecto en el overlay.

## Config compacta (barra horizontal superior)
`MangoHud.conf` → `/home/deck/.config/MangoHud/MangoHud.conf`:
```
fps / gpu_stats / gpu_temp / gpu_core_clock / cpu_temp / ram / frametime
hud_compact / horizontal / hud_no_margin / position=top-center / font_size=17
```
Se rompió el symlink que apuntaba al `mangohud.conf` de Steam para que Steam no
lo pise con `no_display`.

## Toggle con el paddle trasero M2
- El Odin 3 tiene paddles GPIO: **M1 = BTN_Z** (izquierdo), **M2 = BTN_C**
  (derecho). InputPlumber los mapea como botones de un DualSense Edge.
- En el capability map `ayn_mcu.yaml` se re-mapeó **M2 → tecla F13** del teclado
  virtual de InputPlumber (ver `config/inputplumber/`).
- `mangohud-toggle-daemon.py` escucha F13 y alterna `no_display` en la config de
  MangoHud, luego envía **SIGHUP a mangoapp** (mangoapp no relee la config solo;
  sin el SIGHUP el toggle no surte efecto).

⚠️ No reemplazar `/usr/bin/mangoapp` con `cp` mientras corre ("Text file busy") —
usar rename atómico (`cp` a un archivo temporal en el mismo FS + `mv -f`).
