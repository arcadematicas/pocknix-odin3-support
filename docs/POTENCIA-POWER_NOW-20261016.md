# Consumo (W) mal reportado en la Odin 3 — `POWER_NOW` mentiroso del firmware ADSP

**Fecha**: 16/10/2026 · **Dispositivo**: AYN Odin 3 (SM8750, `qcom,sm8550-pmic-glink`) ·
**Estado**: parche escrito y verificado (aplicación limpia). **Pendiente**: recompilar el
kernel, desplegarlo y confirmar en vivo.

---

## 1. Síntoma

El HUD de MangoHUD de la Odin mostraba **~56 W** de consumo mientras el sistema usaba
**~11-13 W**. El panel de rendimiento del QAM, el lector de batería del plugin Decky
(`battery/reader.py`) y KDE enseñaban el mismo disparate, porque **todos leen la misma
propiedad del kernel**.

El valor real (batería) siempre fue correcto; lo que estaba mal era **un nodo del kernel**.

## 2. Medidas (jugando, en la Odin)

`/sys/class/power_supply/battery/`, 5 muestras cada 2 s:

| Nodo | Valor | ¿Correcto? |
|---|---|---|
| `status` | `Discharging` | — |
| `voltage_now` | 3.760-3.784 V | ✅ |
| `current_now` | -2.86..-3.56 A | ✅ |
| **`V × I`** | **10.8-13.4 W** | ✅ es lo único con sentido físico |
| `power_now` | **51933259 µW (51.9 W) en las 5 muestras** | ❌ idéntico, no cambia con la carga |
| `hwmon46 [battery] power1_input` | 49906427..51786593 µW | ❌ mismo valor roto |

Contexto: `power_now` tampoco tenía relación con la carga en reposo (62 W un día, 53 W otro).
Un handheld **no puede** consumir 52 W (vaciaría la batería en ~35 min y el SoC no da para
eso). En el sistema **solo hay esa fuente** de potencia: `hwmon46 power1_input` (que sale del
mismo `POWER_NOW`). No hay otro nodo con ~56 W.

## 3. Causa raíz (kernel, no el HUD)

El fuel gauge de la Odin corre en el **firmware del ADSP** (`pmic_glink` →
`drivers/power/supply/qcom_battmgr.c`). La Odin entra por el compatible de fallback
`qcom,sm8550-pmic-glink` ⇒ variante `QCOM_BATTMGR_SM8550` ⇒ **usa la ruta de actualización de
`SM8350`** (`qcom_battmgr_bat_sm8350_update()`), que por cada lectura de `POWER_NOW` pide al
firmware la propiedad `BATT_POWER_NOW` (id 22) y **publica el valor tal cual**:

```c
case BATT_POWER_NOW:
        battmgr->status.power_now = le32_to_cpu(resp->intval.value);
        break;
```

Ese valor del firmware **es basura** (no depende de la carga). `VOLTAGE_NOW` y `CURRENT_NOW`
sí llegan bien.

**Conclusión**: el arreglo va en el kernel — así se corrige de golpe para **todos** los
consumidores (MangoHUD, QAM/gamescope, Decky, upower/KDE y `hwmon`), en vez de parchear cada
programa por separado. El parche de MangoHUD que prefiere `current_now × voltage_now`
(`packages/mangohud/0001-...`) sigue siendo válido, pero su *fallback* divide `power_now` entre
1e7 **asumiendo un error limpio de 10×** que aquí **no existe** (el error del firmware no es un
factor). No se toca ese paquete aquí (hay un build de MangoHUD en marcha); queda anotado.

## 4. El parche

`kernel/patches/20-sm8750/2108-power-supply-qcom_battmgr-derive-power-now.patch`

**Origen**: trabajo propio de pocknix. **No hay** patch equivalente en Armada ni en ROCKNIX
(se revisó la lista completa de Armada: solo hay 09xx de battmgr — 0900/0901/0902/0903 — y
ninguno toca `POWER_NOW`). Se numera en la serie **21xx** que pidió la tarea para los parches
de batería/battmgr.

Qué toca exactamente (`drivers/power/supply/qcom_battmgr.c`, 34+/3-):

1. **`qcom_battmgr_bat_sm8350_update()`**: para `POWER_SUPPLY_PROP_POWER_NOW`, **deja de pedir**
   `BATT_POWER_NOW` al firmware y en su lugar refresca `BATT_VOLT_NOW` y `BATT_CURR_NOW`.
2. **`qcom_battmgr_bat_get_property()`**: en `POWER_SUPPLY_PROP_POWER_NOW` **deriva** el valor:

   ```
   power_now (µW) = |voltage_now (µV) × current_now (µA)| / 1e6
   ```

   `µV × µA = 1e-12 W = 1e-6 µW`, así que dividir por 1e6 da µW.

**Signo**: descargando, `current_now` es negativo; el consumo es una *magnitud* → se publica
**positivo** (patrón del subsistema power_supply).

**Unidades**: se mantiene µW, la unidad que espera el core (`hwmon` `power1_input` sale del
mismo property ⇒ queda bien solo).

**Criterio "Full"/"Charging"**: con la batería llena en AC el firmware reportaba
`current_now ≈ -2441 µA` a ~4.0 V → el cálculo da **~0.01 W (~0 W)**, que es lo correcto
físicamente (reposo, batería llena). Cargando, `current_now` es positivo y el consumo sale
positivo igual.

**SC8280XP / X1E80100 se dejan intactos**: su ruta de actualización **nunca** pide
`CURRENT_NOW`, así que derivar daría 0; además su firmware (clase portátil) reporta `POWER_NOW`
de forma sensata. El `if/else` del getter replica la misma condición que separa las dos rutas.

## 5. Verificación de la aplicación (hecha)

- El fichero `qcom_battmgr.c` es **byte-idéntico** entre **v7.2.9** y **v7.2.10**
  (comprobado bajando ambos de `git.kernel.org`), así que la verificación sobre 7.2.9/7.2.10 es
  la misma.
- ⚠️ **No se pudo bajar `linux-7.2.10.tar.xz`**: la red de esta máquina está a **~4-6 KB/s**
  (Cloudflare/GitHub directamente caídos); bajar los ~150 MB llevaría horas. Sí se obtuvo el
  fichero **prístino de v7.2.10** desde `git.kernel.org` (que es lo que importa para este
  parche).
- Sobre una base con los parches previos que tocan este fichero, aplicados **en el orden del
  build** (`0078` → `0079` → `0080` → `0081` → `0503` → `0903`; los demás no tocan el driver),
  el resultado es **idéntico al fichero real del árbol de compilación** (`pocknix-os/build/
  kernel/sm8750/linux-7.2.9/.../qcom_battmgr.c`).
- `2108` aplica **con `patch -p1 -F0`** (sin fuzz, **sin `.rej`**) y también pasa
  `git apply --check`. Ningún parche previo tocaba el *valor* de `POWER_NOW`, así que este es
  el primero.

## 6. Cómo verificar **después** (en vivo, tras recompilar y desplegar)

1. **Reposo vs carga**, jugando:

   ```sh
   for i in 1 2 3 4 5; do
     V=$(cat /sys/class/power_supply/battery/voltage_now)   # µV
     I=$(cat /sys/class/power_supply/battery/current_now)    # µA
     P=$(cat /sys/class/power_supply/battery/power_now)      # µW
     awk -v v="$V" -v i="$I" -v p="$P" 'BEGIN{printf "V*I=%.2f W   power_now=%.2f W\n", (v*i)/1e12, p/1e6}'
     sleep 2
   done
   ```

   `power_now` debe dar **~10-14 W** y **cambiar** con la carga (antes: 51.9 W fijos). Debe
   seguir a `V×I`.

2. **hwmon** (misma fuente):

   ```sh
   cat /sys/class/hwmon/hwmon46/power1_input   # ~10-14 W (11.000.000-14.000.000), no ~50 M
   ```

   (el número de `hwmon` puede variar; identificar por `name` = `battery`).

3. **HUD**: el consumo de MangoHUD debe marcar ~11-13 W jugando, no ~56 W.
4. **Batería llena en AC**: `power_now` debe acercarse a **0 W** (decenas de mW).

## 7. Lo que falta

- **Sincronizar al árbol de build** y **recompilar el kernel** (`tools/sync-to-os.sh` copia el
  fichero — es un *overlay*, no hace falta registrarlo). **No se sincronizó**: hay un build de
  kernel + MangoHUD en marcha de otro agente, y no se debe tocar ese árbol.
- **Desplegar** el kernel nuevo en la Odin y ejecutar la verificación de §6.
- Nada de esto está validado en hardware todavía: el parche está verificado en **aplicación**,
  **no** en la Odin.

## 8. Referencia

- `packages/mangohud/0001-Qualcomm-battery-power-now.patch` — prefiere `V×I` en el HUD (su
  comentario del fallback 1e7/10× es incorrecto aquí; **no se toca** en esta tarea).
- Referencia de Armada (mismo driver, útiles pero **no** de este bug): `0901` (unidad de carga a
  mAh), `0902` (exponer `CHARGE_NOW`), `0903` (límite de corriente de carga, ya portado).
  Ojo: en la Odin `charge_full=7970079` / `charge_now=5021150` están en **µAh**.
- Diagnóstico de batería previo: `docs/BATTERY-ISSUE.md`.
