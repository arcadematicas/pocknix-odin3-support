# Sensores del ADSP (SSC) en la Odin 3 — diagnóstico y arreglo

**Fecha**: 15/10/2026 · **Dispositivo**: AYN Odin 3 (SM8750, `soc_id` 706, plataforma `pakala`) ·
**Estado**: ✅ **funcionando** (acelerómetro, giroscopio, magnetómetro y rotación)

---

## 1. Resumen

Los sensores de la Odin 3 pasan a **funcionar igual que en armada**. La pieza que faltaba era
**`pd-mapper`** (el demonio de `linux-msm`, el mismo proyecto que `hexagonrpc`):

> `pd-mapper` lee los ficheros **`.jsn`** (registro de servicios *servreg*) y **registra los process
> domains (PDs) del DSP**, incluido **`sensor_pd`**. Sin él, el ADSP nunca registra ese dominio y el
> SSC (Sensor Core) se queda a medias.

Antes de este arreglo el SSC arrancaba a medias: **acelerómetro y giroscopio sí**, pero
**magnetómetro y rotación (`rotv`) no** — exactamente los dos que se quedaban fuera.

Verificación en vivo (con `ssccli`, tras el arreglo):

```
Accelerometer:  X=-0.86  Y=0.38  Z=9.82 m/s²      ← gravedad, correcto
Gyroscope:      X=0.03   Y=0.03  Z=0.00 m/s
Magnetometer:   X=-256.7 Y=2093.6 Z=-840.6 µT     ← ¡antes fallaba!
iio-sensor-proxy: "Discovered 'rotv' sensor ... data-type: rotv  available: yes"   ← ¡antes fallaba!
```

En `dmesg` se ve el cambio: antes sólo aparecían indicaciones PDR de `charger_pd` y `audio_pd`;
`msm/adsp/sensor_pd` **nunca** aparecía.

---

## 2. La cadena completa (y qué aporta cada pieza)

| Pieza | Qué hace | Dónde vive |
|---|---|---|
| `msm-firmware-loader` | Monta las particiones del firmware y crea el tmpfs `/run/msm-firmware-loader` | paquete propio |
| `pocknix-sensors-tree` | **Nuestro**: monta `dsp_a` y construye el árbol HexagonFS + deja los `.jsn` | `packages/pocknix-bsp-sm8750/sensors/` |
| `pd-mapper` | Lee los `.jsn` y **registra los PDs** (`sensor_pd`) para el ADSP | `packages/pd-mapper/` |
| `libqrtr` | `libqrtr` de linux-msm (pd-mapper la necesita; no está en ALARM) | `packages/libqrtr/` |
| `hexagonrpcd` | Sirve el árbol HexagonFS al ADSP por FastRPC | `packages/hexagonrpc/` |
| `pocknix-sensors-config` | Las configs que pide el SSC (del firmware Android de stock) | `packages/pocknix-sensors-config/` |
| `libssc` | Cliente del Sensor Core (`ssccli`) para **verificar** | `packages/libssc/` |

**Orden de arranque** (crítico, lo imponen los `After=`):

```
msm-firmware-loader  →  pocknix-sensors-tree  →  { pd-mapper, hexagonrpcd-adsp-sensorspd }
```

---

## 3. Por qué hizo falta `pocknix-sensors-tree` (y no bastaba el loader)

`msm-firmware-loader` construye el árbol HexagonFS él solo en dispositivos "normales", pero en la
Odin 3 **no puede**, por dos motivos comprobados:

1. **No hay detección de slot A/B.** El script usa `qbootctl` y, si no está, busca
   `androidboot.slot_suffix=` en `/proc/cmdline`. En la Odin **no existe `qbootctl`** y el cmdline
   **no trae** esa variable → `ab_get_slot()` devuelve vacío → busca la partición `dsp` cuando la
   real se llama **`dsp_a`** → sólo consigue montar `persist` y el árbol sale **vacío**.
2. **No existe partición `vendor`** (su contenido va dentro de `super`, que es dinámico y necesita
   `make-dynpart-mappings`, que no está). Sus enlaces a `mnt/vendor*/etc/sensors/{config,sns_reg_config}`
   no pueden existir nunca.

Nuestro script cubre los dos huecos:

- monta **`/dev/disk/by-partlabel/dsp_a`** (contiene `adsp/` con las libs del PD que pide el ADSP:
  `libsns_*_skel.so`, `sns_tppe.so`…);
- enlaza las configs del vendor desde **`/usr/lib/firmware/sensors/`** (paquete
  `pocknix-sensors-config`) — son **las mismas** que el vendor: verificado por md5 (`sns_reg_config`
  y `sns_odp_config` idénticos, y el mismo juego de 139 JSON).

### El detalle de los `.jsn` (esto es lo que más cuesta encontrar)

`pd-mapper` **no** busca los `.jsn` en cualquier sitio: abre
`/sys/class/remoteproc/*/firmware`, toma su **`dirname`** y escanea **ese directorio (no recursivo)**
buscando `*.jsn` / `*.jsn.xz`.

```
/sys/class/remoteproc/remoteproc0/firmware = "qcom/sm8750/adsp.mbn"
  → dirname = "qcom/sm8750"
  → busca en  $(cat /sys/module/firmware_class/parameters/path)/qcom/sm8750/*.jsn
              y si no, en /lib/firmware/qcom/sm8750/*.jsn
```

Y `msm-firmware-loader` fija ese parámetro a **`/run/msm-firmware-loader/target`** (no
`/usr/lib/firmware`). Por eso los `.jsn` tienen que estar en
`/run/msm-firmware-loader/target/qcom/sm8750/` — que es justo lo que hace el script.

Los `.jsn` del Odin 3 (los mismos que envía armada en
`system_files/usr/lib/firmware/qcom/sm8750/ayn/odin3/`):

```json
adsps.jsn  →  "subdomain": "sensor_pd"     ← el que importa para los sensores
adspr.jsn  →  "subdomain": "root_pd"
adspua/adspuo.jsn, cdspr.jsn, battmgr.jsn
```

---

## 4. Cómo verificar (en la Odin, por ssh)

```sh
# 1) ¿está todo arrancado?
pgrep -c pd-mapper; pgrep -c hexagonrpcd
systemctl is-active pocknix-sensors-tree pd-mapper hexagonrpcd-adsp-sensorspd

# 2) el ADSP registró el sensor_pd?  (lo registra al arrancar el propio ADSP)
sudo dmesg | grep -i "PDR: Indication"
#   → debe salir   msm/adsp/sensor_pd   (antes sólo charger_pd y audio_pd)

# 3) ¿hay sensores?  (los datos en vivo)
ssccli --sensor accelerometer --timeout 6
ssccli --sensor gyroscope     --timeout 6
ssccli --sensor magnetometer  --timeout 6          # μT

# 4) ¿y la rotación?
sudo systemctl restart iio-sensor-proxy
sudo journalctl -u iio-sensor-proxy -n 30 | grep -iE "Discovered|available"
#   →  Discovered 'rotv' sensor ... data-type: rotv   available: yes
```

Los 6 sensores que expone `ssccli` (los que soporta libssc) y qué se puede esperar de cada uno:

| sensor | Odin 3 |
|---|---|
| `accelerometer` | ✅ |
| `gyroscope` | ✅ |
| `magnetometer` | ✅ |
| `compass` | ✅ (derivado del mag) |
| `light` | ❌ **no hay hardware** (ver §6) |
| `proximity` | ❌ **no hay hardware** (ver §6) |

Sensores que declaró Android para esta unidad concreta
(`persist/sensors/sensors_list.txt`):

```
step_detect pedometer persist_stationary_detect tilt offbody_detect mag_cal
persist_motion_detect gravity mag sig_motion rotv device_orient
geomag_rv gyro gyro_cal hall game_rv accel
```

---

## 5. Cambios que lo dejan en el sistema

- `packages/pd-mapper/` — paquete nuevo (PKGBUILD + unidad + enable).
- `packages/libqrtr/` — paquete nuevo (no está en ALARM y `pd-mapper` la necesita).
- `packages/hexagonrpc/` — deja de instalar `hexagonrpcd-adsp-sensorspd.service` (la dueña es el BSP)
  y sus demás unidades apuntan al nodo `-secure` (el único que expone nuestro kernel).
- `packages/msm-firmware-loader/` — ahora instala los **4** ficheros del upstream
  (`msm-firmware-loader.sh`, `msm-firmware-loader-unpack.sh` y sus dos `.service`) y los habilita.
  Sin los servicios, `msm-firmware-loader.service` no existía y el árbol nunca se creaba.
- `packages/pocknix-bsp-sm8750/sensors/` — **nuevo**: `pocknix-sensors-tree` (+ su unidad) y los
  drop-ins de orden para `pd-mapper.service` y `hexagonrpcd-adsp-sensorspd.service`.
- `packages/pocknix-bsp-sm8750/PKGBUILD` — instala el bring-up y **habilita**
  `pocknix-sensors-tree` y `hexagonrpcd-adsp-sensorspd` (antes no se habilitaba: ver §7).
- `devices/sm8750/packages.list` — añade la cadena de sensores a la imagen.
- `overlay/usr/lib/tmpfiles.d/pocknix-msm-firmware-loader.conf` — crea
  `/run/msm-firmware-loader` en cada arranque (el loader no lo crea él y sin él falla con
  `mount point does not exist`).

---

## 6. Limitación conocida: no hay brillo automático (y no es un bug)

La Odin 3 **no tiene sensor de luz ambiental (ALS)** ni de proximidad. Verificado por tres vías:

1. La lista de sensores de esta unidad (arriba) **no incluye** `light`/`als` ni `proximity`.
2. `ssccli --sensor light` → `Unable to initialize light sensor: UNKNOWN` (también con `pd-mapper`
   funcionando). Ídem `proximity`.
3. Las configs de luz que existen en el paquete (`bonito_tmd3765_0.json`, `eliza_tmd2755_0.json`) son
   de **otras plataformas/variantes** del SM8750, no de `pakala` (la nuestra).

Por tanto: **brillo automático imposible** (no hay nada que lo mida); el brillo manual sigue igual
(backlight por sysfs + el control del panel de Decky).

## 6-bis. Limitación conocida: el proxy de escritorio no expone el acelerómetro

`iio-sensor-proxy` 3.9 **sí** descubre `rotv` (data-type `rotv`, `available: yes`, 5 Hz) pero lo deja
sin registrar porque le falta la **mount-matrix**:

```
mount-matrix: undefined     →  HasAccelerometer = false   (AccelerometerOrientation = "undefined")
```

Se probó sin éxito servir `sensors/registry` como copia escribible. La mount-matrix no está en
ninguna config del vendor (sólo hay `gyro_rot_matrix`, attr id 19, en `pakala_default_sensors.json`).
**El dato ya sale del ADSP** (`ssccli` y libssc lo ven); lo que falta es que el proxy lo publique.
Vías para retomarlo:

- mirar de dónde saca la mount-matrix `src/drivers/ssc.c` de iio-sensor-proxy 3.9 (¿`sns_reg_config`?) y
  el porqué de `HasAccelerometer=false`;
- o un consumidor propio con **libssc** (sin pasar por iio-sensor-proxy) para la rotación.

**No** se ha añadido `iio-sensor-proxy` a `devices/sm8750/packages.list`: hoy no aporta nada que se
pueda usar. Si algún día se resuelve lo anterior, añadirlo ahí.

---

## 7. Avisos (para no repetir sufrimientos)

- **NO reiniciar el ADSP por sysfs** (`echo stop > /sys/class/remoteproc/remoteproc0/state`):
  en la Odin provoca un **warm reset de todo el dispositivo** (se reinició sola, y además tira la red).
  Para que el ADSP re-registre sus PDs, reiniciar el dispositivo entero.
- **No tocar `adsp_dtb.mbn`**: el que va en `/usr/lib/firmware` es el que arregla la carga de la
  batería. Los `.jsn`, en cambio, sí hay que tenerlos.
- `pd-mapper` lee los `.jsn` **una sola vez al arrancar**: si arranca antes de que
  `pocknix-sensors-tree` deje los ficheros, sale con `no pd maps available` y no hay sensores.
  De ahí los `After=` de los drop-ins.
- No lanzar demonios desde unidades `oneshot` (systemd mata el cgroup al terminar): `pd-mapper` y
  `hexagonrpcd` tienen sus propias unidades `Type=simple`.
- Ojo al depurar por ssh: **`pkill -f hexagonrpcd` mata la propia sesión ssh** (el patrón aparece en
  su línea de comandos). Usar `killall hexagonrpcd` (por nombre).

---

## 8. Cómo se llegó hasta aquí (resumen del camino)

1. El demonio moría en 0,5 s → se empaquetaron `hexagonrpcd`, `libssc` y `msm-firmware-loader`, y las
   configs del ADSP (`pocknix-sensors-config`, extraídas del dump `Odin3_20251206`).
2. Con las configs limpias el demonio llegaba a `INIT_ATTACH_SNS` y luego moría con
   `Unexpected buffer count for method 31` → era el `json.lst` pidiendo 4 ficheros que no existen
   (el propio vendor los pide: `qsh_camera_imx688_4.json`, `sns_amd_sw_disabled.json`,
   `sns_presence_detect.json`, `sns_tilt_sw_disabled.json`); quitando esas 4 entradas, el error
   desaparece.
3. Se probó a cambiar el firmware del ADSP por el del vendor **desagregado**: **no arranca** con
   nuestro kernel → el ADSP quedó *offline* y hubo que **revertir al `adsp.mbn` de armada**
   (md5 `6cfcbbb80b956dda`). Conclusión: el firmware correcto es el de armada; el problema no era ese.
4. Comparando con el repo de armada (`armada-elite`) se vio que ellos **envían los `.jsn`** por
   dispositivo (`…/sm8750/ayn/odin3/`) → ahí estaba la pista.
5. Faltaba el consumidor de los `.jsn`: **`pd-mapper`**. Compilado a mano (aarch64) y probado:
   `no pd maps available` → hasta enlazar los `.jsn` en el directorio correcto
   (`/run/msm-firmware-loader/target/qcom/sm8750/`). **A partir de ahí: magnetómetro y `rotv` en vivo.**
