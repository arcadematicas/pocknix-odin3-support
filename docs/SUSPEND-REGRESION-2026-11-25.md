# Regresión de suspensión — la Odin reinicia al despertar (25/11/2026)

Estado: **abierto, investigando**. Objetivo: volver a la suspensión robusta de hace unos días
(`deep`, **0,14 %/h** medido) sin renunciar a lo demás.

## 1. Qué pasó (evidencia)

| Hora | Hecho | Fuente |
|---|---|---|
| 24/11 22:54 | Arranque (primer boot con `linux-pocknix-sm8750 7.2.15-7`) | `last -x` |
| 24/11 23:15 | Steam pide suspender; hook `pre` de `zz-battery-sleep` escribe y **no hay `post`** | `~/.local/share/Steam/logs/steamui_system.txt`, `/var/log/pocknix/sleep-battery.log` |
| 25/11 07:04:55 | **Arranque desde cero** al ir a despertar → no reanudó | `last -x`, `journalctl --list-boots` |

- El journal del arranque anterior **se perdió** (`journalctl -b -1` vacío, aunque `/var/log/journal`
  es persistente) y **`/sys/fs/pstore` estaba vacío**.
- Sin esos dos datos no se puede distinguir entre:
  1. **panic** durante el resume (el cmdline lleva `oops=panic panic=5` → reinicia solo a los 5 s), o
  2. **cuelgue duro / corte del PMIC** (reinicio por watchdog o apagado; no deja pstore).

Correcciones de diagnóstico ya aplicadas en la Odin:
- `journald` con `SyncIntervalSec=15s` (`/etc/systemd/journald.conf.d/10-sync.conf`) para conservar
  el final del arranque anterior aunque el apagado no sea limpio.
- Pendiente comprobar si **ramoops registra** (`dmesg | grep -i ramoops`). Si no registra, el
  `pstore` vacío no significa "no hubo panic".

## 2. La suspensión buena que hay que recuperar

- `mem_sleep_default=deep` en el cmdline (BSP 42, 31/10) y en `devices/sm8750/profile.conf`.
- Consumo medido: **0,14 %/h** (6 h 50 en `deep`), frente a ~0,5 W de `s2idle`.
- Validaciones: kernel 31 (`7.2.12-30`, 4/11, 3 ciclos) y **`7.2.15-1` (7/11, "suspend/resume OK")**.

## 3. Ventana de regresión

Entre `7.2.15-1` (`288f9af`, 7/11) y `7.2.15-7` entraron, **sin volver a probar suspensión**:

| Commit | Qué entró |
|---|---|
| `418e64d` (10/11) | Dock USB-C / DP AltMode: `0620`–`0624` **kernel** |
| `faed6d5` (15/11) | `2170` poll de zonas térmicas GPU, `2171` `perfmode_bw` en A8x, `2172` HBR3 |
| `17a1e60` (15/11) | `9999` cooling-map de la GPU (estaba dentro de `trips`, DTS inválido) |
| `cd0c279` (11/11) | DTS del **segundo board** (portal) + ajustes en `cq8725s-ayn-common.dtsi` |
| `44d6f22` (24/11) | `2605` log de diagnóstico class-H (audio; inocuo) |

Parches realmente nuevos en `20-sm8750/`:
`0620-usb-typec-nb7vpq904m-set-clientdata-in-probe`,
`0621-soc-qcom-pmic_glink_altmode-dont-wait-ack-and-add-debug`,
`0622-drm-msm-dp-enable-audio-for-all-external-dp-displays`,
`0623-usb-typec-preserve-host-mode-and-combo-phy-dp-only`,
`0624-usb-typec-mux-wcd939x-keep-usb-enabled-in-dp-altmode`,
`2170`, `2171`, y el `9999` modificado.

DTS del Odin 3 (`cq8725s-ayn-odin3.dts`):
```dts
&{/pmic-glink/connector@0} { try-power-role = "sink"; };
```

## 4. Sospechosos, por orden

1. **`pmic-glink` / typec (0621 + `try-power-role="sink"` + PHY combo)**. `pmic-glink` es el canal
   por el que el PMIC/EC entrega los eventos de USB-C **y las notificaciones de suspensión**. En este
   lote se activó el DP del Odin de verdad: `link-frequencies` en `mdss_dp0_out` **hasta HBR3
   (8,1 Gbps)**, audio por DP (`0622`), el rol de datos del altmode (`0623`/`0624`) y el forzado
   `try-power-role="sink"`. El PHY combo es **compartido USB3/DP**: si su estado de energía al
   suspender no cuadra, el resume se cuelga sin dejar pstore (cuelgue duro, no oops). Encaja con el
   síntoma.
2. **GPU A830 (`2170` + `2171` + cooling-map `9999`)**. Toca votos de GMU/interconnect y DVFS, que es
   justo el camino de `2124`/`2125` (los fixes de resume del kernel 31).
3. **`deep` en sí sobre 7.2.15-7**. `deep` siempre fue el modo frágil; `s2idle` era el "seguro".

## 5. Plan para recuperarla

### Paso 0 — datos (5 min, sin builds)
1. `journalctl -b -1 | tail -200` (¿hay panic/GMU/OOB/timeout?).
2. `dmesg | grep -i ramoops` (¿registra pstore?).
3. `cat /sys/power/mem_sleep` (¿`[deep]` de verdad?).
4. `cat /flash/pocknix-kernel-guard.log` — el guardia escribe **en /flash** (persistente): diría si
   reinició él por desajuste kernel/módulos.
5. `ls -l /flash/ | grep -E 'KERNEL|modules-'` — si hay un `KERNEL.bak-*` **y** su
   `modules-<ver>.tar.zst`, hay rollback a un kernel anterior sin compilar.
6. `/var/cache/pacman/pkg/linux-pocknix-sm8750-*` — idem.

### Paso 1 — A/B sin depender de Fransis (RTC + systemctl)
```bash
rtcwake -m no -s 120            # alarma; NO suspende
systemctl suspend               # entra por el camino real (con los hooks de sleep)
```
⚠️ `rtcwake -m mem` **no** ejecuta los hooks de systemd: InputPlumber no se para, `vhci_hcd`
devuelve `-16` y el suspend **aborta** (ver `docs/SUSPEND-ISSUE.md`). Hay que usar
`systemctl suspend` con la alarma ya puesta.
Éxito = `uptime` **continuo**. Fracaso = arranque nuevo → `journalctl -b -1`.
**Regla nueva: nunca suspender en remoto sin alarma RTC.**

### Paso 1b — A/B de modo
```bash
echo s2idle > /sys/power/mem_sleep   # y repetir el Paso 1
```
Si `s2idle` va y `deep` no, el problema está en el camino `deep`, no en las notificaciones del PMIC.

### Paso 2 — kernel "suspend-safe" (lo que devuelve lo de hace unos días)
Base: el árbol de `7.2.15-1`, que ya llevaba `mem_sleep_default=deep` + `2124`/`2125`.
Quitar de la compilación, por este orden:
1. `0620`–`0624` y el bloque `&{/pmic-glink/connector@0}` del DTS del Odin 3.
2. Si sigue fallando: `2170`, `2171` y devolver `9999` a la versión de `288f9af`.
3. Si sigue: volver temporalmente a `mem_sleep_default=s2idle` (~0,5 W) y abrir bisect fino.

Antes de instalar el kernel nuevo: **copiar el paquete actual** a `/flash` para poder volver
(la R2 solo conserva `7.2.15-7`; los anteriores están podados).

### Paso 3 — validación
- 3 ciclos con `rtcwake` (120 s, 10 min, 30 min) sin reinicio.
- 2 h con el hook `zz-drain-log` → comparar con **0,14 %/h**.
- Un ciclo con juego abierto, uno con jack y uno con el dock.

## 6. Deuda detectada (no causa, pero hay que arreglarlo)

`pocknix-fake-suspend` está declarada de dos formas contradictorias:
- el `[Install]` del paquete dice `WantedBy=systemd-suspend.target`, **que no existe**;
- el PKGBUILD del BSP crea a mano un symlink en `systemd-suspend.service.wants/`.

Según `docs/SUSPEND-ISSUE.md`, ese stub **está superado**: en la Odin la suspensión es `deep` real
con los hooks de `systemd-sleep`, y el `fake-suspend` de ArmadaOS era solo su reserva (de hecho, el
stub fue **la causa** del bug de 09-11/09: interceptaba `systemd-suspend.service` y el equipo no
suspendía de verdad). Por eso:

- El override en `/etc/systemd/system/pocknix-fake-suspend.service` que se puso el 25/11
  (`WantedBy=suspend.target`, verificado con `bl_power=4` + `powersave`) **se retira** en cuanto
  haya acceso: no arregla nada y añade una variable al experimento.
- Si el paquete sigue instalando la unidad, hay que decidir **una** de dos cosas y dejarlo escrito:
  (a) borrarla del BSP (lo coherente con `SUSPEND-ISSUE.md`), o (b) dejarla como red de seguridad con
  `WantedBy=suspend.target` y **sin** el symlink manual del PKGBUILD.

## 7. Kernel 8 "suspend-safe" (construido el 25/11, sin instalar todavía)

**Qué se ha quitado del stack** (renombrados a `*.patch.disabled` en
`kernel/patches/20-sm8750/`):

| Parche | Qué hacía |
|---|---|
| `0620` typec nb7vpq904m | `clientdata` en el probe del redriver |
| `0621` pmic_glink_altmode | no esperar ack del PAN_EN (hack + debug + triggers sysfs) |
| `0622` drm/msm/dp | audio en todos los DP externos |
| `0623` typec | conservar host mode / combo PHY solo-DP |
| `0624` typec mux wcd939x | mantener USB en DP altmode |
| `2170` dts | poll de las zonas térmicas de la GPU |
| `2171` a6xx | `perfmode_bw` en A8x |

Y en el DTS: fuera `mdss_dp0_out` (`link-frequencies` hasta HBR3) y el conector
`pmic-glink` con `try-power-role="sink"`. El `9999` vuelve a la versión de `7.2.15-1`.
**Se queda** todo lo anterior (audio class-H `2600`–`2604`, serie armada-sleep, GPU
`2103`/`2122`–`2125`, y el fix del `wakeup-source` del Volume Up).

**Verificado en el fuente compilado** (no solo en el log del build):
- `pmic_glink_altmode.c`: sin `manual trigger`/`force_dp`/`(continuing)`; vuelve
  `wait_for_completion_timeout(&altmode->pan_ack, 5 * HZ)`.
- `a6xx_gmu.c`: `adreno_is_a6xx` = 0 apariciones.
- DTS del Odin: sin `mdss_dp0_out` ni `try-power-role`.

**Artefactos**: `linux-pocknix-sm8750 7.2.15-8`, `KERNEL` (boot image) de 18.257.920 B,
md5 `0d6d7ac6530cc9c820a51f8070d5922d`; `Image` md5 `dd957ee024cea6fed1e5809fda455fe1`
(verificado **dentro del paquete**: coincide). Paquete
`build/localrepo/sm8750/linux-pocknix-sm8750-7.2.15-8-aarch64.pkg.tar.xz`, 77.669.724 B,
sha256 `3cf4e840a263b73d31aa4d5ee701d0dd1eca013f1c791f234d3663b033556f46`.
El `7`, en uso, es de 18.259.968 B (md5 `e2dc7ea5ec30272306ae84632886b670`).

### ⚠️ Trampa encontrada (y cerrada)
El primer build de este kernel **salió con los parches dentro**: los stacks son *overlays* y
`rsync` no borra, así que al renombrar a `.patch.disabled` en el centro el `.patch` viejo seguía
en `pocknix-os` y se aplicaba (129 parches en vez de 122). Se detectó mirando el fuente compilado.
Ahora `tools/sync-to-os.sh` los borra del árbol (`overlay_disabled`) y `tools/check-sync.sh`
falla con `STALE` si queda alguno.

### Cómo se instalará y validará
1. Copiar el `.pkg.tar.xz` a la Odin y `sudo pacman -U` (el hook regenera `/flash/KERNEL`).
   Antes, guardar el paquete actual en `/flash` para poder volver.
2. Reiniciar y comprobar en el arranque: `uptime`, `systemctl --failed`, audio class-H, mando.
3. **Suspensión**: `rtcwake -m no -s 300` + `systemctl suspend`; debe volver con el **mismo
   `boot_id`** y seguir contando el uptime. Repetir 3 veces (2 min, 10 min, 30 min).
4. Medir 2 h con `zz-drain-log` → objetivo **0,14 %/h**.
5. Solo entonces: publicar en R2 y anotar en el CHANGELOG.

## 8. La pieza que faltaba: la preparación previa a suspender (25/11, tarde)

Probado en la Odin con el kernel **7.2.15-7** (el que fallaba), sin tocar el kernel:

| Ciclo | Condición | Resultado |
|---|---|---|
| 07:43 → 18:28 (10 h 45 min) | **con cargador**, preparación activa | **reanudó** (mismo `boot_id`, uptime 11 h 28 min) |
| 18:34 → 18:36 (120 s) | **con batería**, preparación activa | **PASS** (`calvos-suspend-test`, mismo `boot_id`) |

El journal del ciclo bueno lo deja claro: `Starting CalvOS Fake Suspend` a las 07:43:28 y
`PM: suspend entry (deep)` a las 07:43:29. Es decir, la preparación (pantalla a `bl_power=4`,
governor `powersave`, `sync`) **entró en la transacción de suspensión**, y
`PM: suspend exit` la revirtió al despertar.

Recordemos que la unidad **nunca se ejecutaba**: su `[Install]` decía
`WantedBy=systemd-suspend.target`, un target **que no existe** (la cadena real es
`suspend.target → systemd-suspend.service`). La única vía era un symlink manual del PKGBUILD en
`systemd-suspend.service.wants/`, que en esta instalación no estaba (`is-enabled` decía
`disabled`). O sea: la Odin 3 llevaba suspendiendo **sin** la preparación que ArmadaOS sí hace.

### Arreglado en el paquete (`pocknix-bsp-sm8750` 63 → 64)

- `fake-suspend/pocknix-fake-suspend.service`: `WantedBy=suspend.target` y
  `DefaultDependencies=no` (antes, el target inexistente).
- PKGBUILD: fuera el symlink manual en `systemd-suspend.service.wants/` (dos mecanismos para lo
  mismo, uno inválido).
- `.install`: `systemctl enable pocknix-fake-suspend.service` (como el LED de carga), para que
  una instalación limpia lo traiga activo.

### Estado final del día (25/11, 19:12)

- **`pocknix-bsp-sm8750 0.2.0-64` instalado** en la Odin; retirado el override de `/etc` que puse
  a mano y el symlink huérfano que dejó. La unidad se carga **desde `/usr/lib`** y está
  `enabled` por `suspend.target` (`systemd-analyze verify` limpio).
- **5 ciclos, 5 PASS** con el kernel 7.2.15-7: 120 s (×2, el último ya por la vía del paquete),
  600 s, suspensión por inactividad de 6 min 27 s y **10 h 45 min** con cargador. Siempre mismo
  `boot_id` y uptime continuo.
- La suspensión por inactividad la pidió Steam (`dbus-send` desde la sesión), así que el flujo
  real — consola quieta en Game Mode — también pasa por la preparación.

Queda solo la medición de consumo: un ciclo **largo con batería** (3 h o toda la noche) leyendo
`charge_now` del hook `zz-drain-log` (objetivo 0,14 %/h ≈ 11 mA). Con 120 s o 10 min el contador
no se mueve lo suficiente para distinguirlo del ruido.

**Consecuencia importante**: si esto se sostiene, **el kernel 8 no hace falta** para arreglar la
suspensión: se queda el 7 con el lote DP/dock y los ajustes de GPU, y el "suspend-safe" queda
guardado como plan B.
