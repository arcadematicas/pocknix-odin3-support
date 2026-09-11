# Suspensión del AYN Odin 3 (SM8750) — RESUELTO (11/09/2026)

**Estado: el Odin 3 suspende y despierta correctamente (s2idle real), igual que
ArmadaOS.** El botón de encendido suspende y, al volver, la pantalla se reactiva
sola.

---

## 1. Síntoma

- Pulsar el botón de encendido **no suspendía**: la pantalla se apagaba y se
  volvía a encender al instante (un "parpadeo").
- La sesión (juegos/escritorio) seguía viva; el equipo nunca llegaba a dormirse.
- `systemctl suspend` parecía no hacer nada.

## 2. Causa raíz

`/etc/systemd/system/systemd-suspend.service.d/override.conf` **reemplazaba** el
suspend de systemd por un *stub* roto:

```
[Service]
ExecStart=
ExecStart=/usr/local/bin/pocknix-fake-suspend.sh suspend
ExecStop=
ExecStop=/usr/local/bin/pocknix-fake-suspend.sh resume
```

`/usr/local/bin/pocknix-fake-suspend.sh` **no suspendía nada**: apagaba la
retroiluminación (`echo 4 > .../bl_power`), ponía la CPU en `powersave` y hacía
`sync`, y **terminaba inmediatamente**. Como salía en milisegundos, systemd daba
la suspensión por completada y ejecutaba el `resume` enseguida → pantalla apagada
y encendida.

Ese stub venía de la etapa en la que se creía que "la suspensión real cuelga el
SM8750" (ver `config/fake-suspend/`). **Esa premisa era falsa**: lo que cuelga el
SM8750 es `deep`, no `s2idle`.

## 3. Cómo lo hace ArmadaOS (referencia)

En el perfil del Odin 3 de ArmadaOS (`lib-armada/devices/defaults.conf` +
`ayn-odin-3.conf`):

- `ARMADA_SUSPEND_MODE=s2idle` → **suspensión real**.
- `suspend-dispatch`: si el modo es `s2idle`, selecciona `mem_sleep` y ejecuta
  `/usr/lib/systemd/systemd-sleep suspend` (el suspend real de systemd). El
  `fake-suspend` **solo es el reserva** para SoCs donde el real cuelga.
- `device-quirks` selecciona `s2idle` en `/sys/power/mem_sleep` al arrancar.
- `powerbuttond` (modo juego) envía `steam://shortpowerpress` a Steam, y Steam
  inicia el ciclo de suspensión.

Conclusión: en la Odin 3 lo correcto es **s2idle real**, no fake-suspend.

## 4. Descubrimientos durante la depuración

### 4.1. `mem_sleep` por defecto = `deep`

Sin intervención, el kernel deja `mem_sleep` en `[deep] s2idle` (o `deep`), que
es el modo que cuelga el SM8750. Hay que seleccionar `s2idle`.

### 4.2. `vhci_hcd` (mando virtual de InputPlumber) bloqueaba el suspend

Con `systemctl suspend` el kernel entraba en s2idle y **abortaba al instante**:

```
usb usb1-port1: device 1-1 not suspended yet
vhci_hcd vhci_hcd.0: We have 1 active connection. Do not suspend.
vhci_hcd vhci_hcd.0: PM: dpm_run_callback(): platform_pm_suspend returns -16
vhci_hcd vhci_hcd.0: PM: failed to suspend: error -16
PM: Some devices failed to suspend, or early wake event detected
```

`vhci_hcd` es el controlador USB/IP con el que InputPlumber publica su **mando
virtual** (`InputPlumber Generic Steam Controller`, 28DE:12F0) cuando el target
es `deck`. Una conexión activa **-EBUSYs** el suspend.

**Esto ya lo resolvía Pocknix**: el hook
`/usr/lib/pocknix/sleep.d/pre/001-inputplumber` para InputPlumber y espera a que
el puerto se suelte; `post/001-inputplumber` lo relanza al volver. (El hook
`pocknix-sleep` reparte los scripts de `/usr/lib/systemd/system-sleep/` a
`/usr/lib/pocknix/sleep.d/{pre,post}/`.)

> Ojo: probar con `rtcwake -m mem` **no** ejecuta los hooks de systemd (escribe
> directo en `/sys/power/state`), así que InputPlumber no se detiene y el suspend
> aborta. Para probar hay que usar `systemctl suspend`.

### 4.3. Al resumir, la pantalla se quedaba apagada

Tras un resume correcto, la sesión (gamescope) volvía pero el panel seguía negro:

- `bl_power = 4` (FB_BLANK_POWERDOWN) y `actual_brightness = 0`
- el conector DRM sí reportaba `DPMS = On`

gamescope no re-activaba la retroiluminación (el suspend se pidió fuera del flujo
de Steam). Se recuperaba a mano con `echo 0 > .../bl_power`.

## 5. El fix

### 5.1. En la Odin (aplicado)

1. **Quitar el override roto** (respaldado):
   - `/etc/systemd/system/systemd-suspend.service.d/override.conf.disabled-20260911`
   - copia: `override.conf.bak-20260911`
   - script: `/usr/local/bin/pocknix-fake-suspend.sh.bak-20260911`
   - `systemctl daemon-reload` → `systemd-suspend.service` vuelve a ejecutar
     `/usr/lib/systemd/systemd-sleep suspend`.
2. **Seleccionar s2idle**:
   - `/usr/lib/systemd/sleep.conf.d/10-pocknix-s2idle.conf` (`MemorySleepMode=s2idle`)
   - `/usr/lib/tmpfiles.d/10-pocknix-mem-sleep.conf` (`w /sys/power/mem_sleep - - - - s2idle`)
3. **Hook de post-resume para la pantalla**:
   `/usr/lib/pocknix/sleep.d/post/004-display` (ver §5.2).

### 5.2. En las fuentes de `pocknix-os` (permanente)

| Fichero | Cambio |
|---|---|
| `devices/sm8750/profile.conf` | `KERNEL_CMDLINE_EXTRA` += **`mem_sleep_default=s2idle`** (específico de sm8750; sm8250/sm8550 no se tocan) |
| `overlay/usr/local/bin/pocknix-powerd` | `screen_is_on()` lee el **DPMS del conector DRM interno** (DSI/eDP/LVDS) antes del fallback de `bl_power` |
| `packages/shared/pocknix-bsp-common/display-sleep-post` (nuevo) | Hook post-resume → se instala como `usr/lib/pocknix/sleep.d/post/004-display` |
| `packages/shared/pocknix-bsp-common/PKGBUILD` | `pkgrel 14`, añade el `source` y la instalación del hook |

El hook `004-display`:

1. Si hay gamescope (modo juego), le pide despertar la pantalla interna con
   `gamescopectl drm_sleep_internal_screen 0` (como root, con `XDG_RUNTIME_DIR`;
   `runuser` no, porque crea sesión PAM y tarda ~5 s).
2. Desbloquea la retroiluminación: `echo 0 > /sys/class/backlight/*/bl_power`
   (el brillo conserva su valor, no hay que adivinarlo).

## 6. Verificación (en la Odin)

```
$ cat /sys/power/mem_sleep
[s2idle] deep

$ journalctl -b -u systemd-suspend
... Performing sleep operation 'suspend'...
... System returned from sleep operation 'suspend'      <- ~30 s después (alarma RTC)

$ cat /sys/class/backlight/ae94000.dsi.0/bl_power \
      /sys/class/backlight/ae94000.dsi.0/actual_brightness
0
3721
```

- `systemctl suspend` + alarma RTC a +30 s: duerme los 30 s y despierta.
- Botón de encendido (corto) → suspende; otra pulsación → despierta **con la
  pantalla encendida**. Confirmado por Fransis.
- El journal del pre-hook de InputPlumber muestra que para/relanza el servicio, y
  el post hook deja `bl_power=0` / `actual_brightness=3721`.

## 7. Notas / trampas

- **No usar `deep`** en el SM8750: cuelga. `s2idle` es el único modo seguro.
- El `bl_power` de la Odin 3 puede quedarse en `4` aunque el panel esté
  encendido: por eso `powerd` usa el DPMS del conector, no `bl_power`.
- El reloj del sistema se sincroniza desde el RTC al resumir; con NTP activo
  (`systemd-timesyncd`) se corrige solo. Verificado correcto tras el resume.
- El RTC (`pm8xxx_rtc_alarm`, IRQ 184) es fuente de wakeup válida → útil para
  pruebas automáticas (`echo $(( $(date +%s) + N )) > /sys/class/rtc/rtc0/wakealarm`).
- El stub `fake-suspend` **no forma parte** de las fuentes de `pocknix-os`; era
  una adición manual en la Odin. No hay nada que revertir en el repo por él.

## 8. Pendiente / opcional

- Portar el `fake-suspend` + `suspend-dispatch` de ArmadaOS como **red de
  seguridad** (si algún día el s2idle fallara). Hoy no es necesario.
- Valorar usar el flujo de Steam (`steam://shortpowerpress`) en modo juego para
  que Steam muestre su animación de suspensión, como hace ArmadaOS. El flujo
  actual (`pocknix-powerd` → `systemctl suspend`) funciona en ambas sesiones.
