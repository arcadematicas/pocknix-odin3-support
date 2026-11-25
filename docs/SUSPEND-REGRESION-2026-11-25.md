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

1. **`pmic-glink` / typec (0621 + `try-power-role="sink"`)**. `pmic-glink` es el canal por el que el
   PMIC/EC entrega los eventos de USB-C **y las notificaciones de suspensión**. `0621` "no espera el
   ack" del altmode y añade debug; el DTS fuerza el rol *sink* en el conector 0. Que el resume se
   quede esperando/descoordinado con el PMIC encaja con un cuelgue sin rastro en pstore.
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
