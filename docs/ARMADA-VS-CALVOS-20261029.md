# Armada vs. calvOS — qué tienen ellos funcionando y nosotros no

Fecha: 29/10/2026. Fuente: `armada-os/armada` @ `main` (clone completo, 501 MB), commits del
16-27/10 y comparación contra nuestro árbol (`pocknix-odin3-support` + `pocknix-os`).

> Método: no se comparan nombres de fichero (los nuestros están renumerados y renombrados), sino
> **capacidades**, mirando el código del kernel 7.2.12 que compilamos, los parches de armada y el
> firmware instalado en la consola.

## Resumen

| Capacidad | Armada | Nosotros | Qué falta | Esfuerzo |
|---|---|---|---|---|
| **SoCCP / deep sleep (D3)** | `0556` + `0556a` | ✅ **hecho hoy (kernel 22)** | Nada: el driver y el nodo ya venían en 7.2.12 y el firmware ya estaba instalado; solo faltaba `firmware-name` en el DTS | — |
| **Iris low-latency** | 1030-1037 + 1370 | ✅ kernel 21 | Nada (aunque Moonlight no se ha probado por decisión de Fransis) | — |
| **Audio HPH / clipping** | 0072, 0073, 0080, 0063, 0603 | ✅ kernel 21 (altavoces y auriculares OK) | Nada | — |
| **Micrófono interno** | DTS + `0073`/`0080` + UCM `AYN/Odin3` | ⚠️ kernel sí, **no captura** — **PRIORIDAD PRÓXIMA** | **Enrutado ALSA/UCM**: el FE abre el backend `WCD` en vez de `TX_CODEC_DMA_TX_3`, y el UCM pide `DMIC2 Switch`/`DMIC3_MIXER Switch`, nombres que este kernel no tiene (`DMIC2`, `DMIC3_MIXER`) | Medio |
| **LED de carga RGB** | paquete `armada-rgb` (Rust, userspace) | ❌ **no prioritario (decisión 29/10)** | El trigger `battery-charging-orange-full-green` **no existe** en nuestro kernel (es de SteamOS). Su demonio lee `power_supply` y escribe en `/sys/class/leds`. Nodo `pm8550_pwm` disponible, pero **el canal 3 lo usa el ventilador** | Bajo-medio |
| **Giroscopio / SSC** | `inputplumber` 0005-0008, `libssc` 0005, `armada-ssc` | ❌ — **PRIORIDAD PRÓXIMA** | Portar los parches a `inputplumber 0.83.0` (ellos van por 0.82) y decidir el apagado de la isla | Alto |
| **sched_ext (`scx-scheds`)** | paquete + kernel con sched_ext | ❌ | `CONFIG_SCHED_CLASS_EXT` no está en nuestro config; además haría falta el paquete | Bajo (config) / medio (paquete) |
| **UFS sm8750** | `0066` | ✅ ya en upstream 7.2.12 (`qcom,sm8750-ufshc`) | Nada | — |
| **Calibración frame-length del panel** (`0518`) | sí | ❓ | Nuestro panel va por el `1034` (icna35xx) y la calibración de 7.2.11; comprobar si son complementarios | Bajo |
| **q6apm MI2S en prepare** (`0612`) | sí | ❓ | Nuestro audio de altavoces ya funciona; comprobar si aporta algo | Bajo |
| **hv-haptics / rsinput FF** (`1000`, `1002`) | sí | ⚠️ parcial | Tenemos `2107` (haptics) y `2104-2106` (rsinput), pero su `1000` es el driver `qcom-hv-haptics` de sm8750 | Medio |

## Lo que ya damos por cerrado

- **SoCCP**: verificado en caliente. Con un symlink `soccp.mbn -> qcom/sm8750/ayn/odin3/soccp.mbn`
  el driver arranca (`remote processor soccp is now up`, `in D3, boot bus vote dropped`). El kernel
  22 lleva el `firmware-name` en el DTS, que es la forma correcta.
- **Micrófono**: no es el DTS. El `.dtb` compilado lleva `widgets = "Microphone", "Internal Mic"` y
  las rutas `DMIC3`, y el codec expone el control `DMIC3`. El fallo es de enrutado: durante la
  captura el backend activo es `WCD Capture`, y tras el primer bloque la señal es **cero exacto**.

## Orden sugerido

1. **Micrófono** (medio): UCM propio para `SM8750-AYN` con la secuencia de armada corregida
   (`DMIC2`, `DMIC3_MIXER`, `TX_DEC0`) y el mezclador `MultiMedia3 Mixer TX_CODEC_DMA_TX_3` en
   ambos canales. Se prueba sin recompilar kernel: `arecord` + 4 s de audio.
2. ~~**LED de carga**~~ — **descartado por Fransis el 29/10** (no es importante).
2. **sched_ext** (bajo): activar `CONFIG_SCHED_CLASS_EXT` en el config del kernel y probar
   `scx_lavd`/`scx_bpfland` con juegos.
3. **Giroscopio** (alto): es el más grande y el que más depende de paquetes.

## Nota sobre el método

`drivers/remoteproc/qcom_q6v5_pas.c` **ya incluye** `sm8750_soccp_resource` en 7.2.12 y el dtsi
**ya define** `remoteproc_soccp`. Eso significa que varios "parches de armada" son solo ajustes de
DTS o de packaging: antes de portar un parche entero, comprobar si el kernel base ya lo trae.

## Intento de arreglo del micrófono (29/10, tarde)

Probado en caliente, sin recompilar:

- Mezclador `MultiMedia3 Mixer TX_CODEC_DMA_TX_3` forzado a **ambos** canales → el backend no cambia
  (sigue `WCD Capture`, que **es** el link del TX_CODEC: su CPU DAI es `TX_CODEC_DMA_TX_3`; el nombre
  del link engaña).
- `DMIC2`, `DMIC3` y `DMIC3_MIXER` en `on`, `TX DEC0 MUX=SWR_MIC`, `TX_AIF1_CAP Mixer DEC0=on`,
  `TX_DEC0=100`.
- Barrido de `TX SMIC MUX0` por los 8 puertos (`SWR_MIC0..7`): **todos mudos**, con el mismo
  transitorio inicial (`min=-32768`, luego ceros exactos).

Conclusión: el problema está **aguas arriba del SWR**, no en el mux. Candidatos: el DMIC no recibe
bias/reloj (`MIC BIAS3` no se enciende) o el Odin 3 no cablea el micro interno a un DMIC del
`wcd939x` sino a `AMIC`/otro camino. Siguiente paso: revisar el DAPM con la captura activa
(`MIC BIAS3`, `DMIC3_OUTPUT`) y probar el camino analógico (`AMIC2`) antes de tocar el UCM.
