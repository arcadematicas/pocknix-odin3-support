# Holodor — hallazgos útiles para CalvOS (3/11/2026)

Proyecto hermano: <https://github.com/transentient/holodor> — “SteamOS-style Linux para la AYN Odin 3”
(**Holo Core** de Valve + kernel de ROCKNIX). Mismo kernel base que nosotros, así que sus issues son
una fuente directa de bugs y arreglos.

## 1. BUG IMPORTANTE: los OPP de GPU con ACD van a la mitad de reloj (issue #3)

<https://github.com/transentient/holodor/issues/3> (abierto desde el 13/10, sin arreglar).

- En la Odin 3 (CQ8725S, GPU speed bin 232), **todo OPP con `qcom,opp-acd-level` entrega la mitad de
  rendimiento**: 1100 MHz da **1,66 TFLOPS en vez de 3,38**; 900 → 1,37 (0,50); 734 → 1,11 (0,49).
  Curiosamente 660 MHz (sin ACD en el dtb de stock) va **más rápido** que 1100 con ACD.
- Quitando `qcom,opp-acd-level` de los OPPs, todos los pasos recuperan su rendimiento (1100 → 3,35).
  No es voltaje: subir el voltaje de 1100 no cambia nada mientras el ACD esté puesto.
- **Nuestro estado: afectados.** El dtb compilado de la Odin 3 lleva **11** `qcom,opp-acd-level`
  (heredados de `sm8750.dtsi`; nuestra placa no los define). El driver soporta `msm.disable_acd=1`.
- **Ya tenemos la protección térmica** que recomiendan: nuestro parche `9999` añade trips pasivos
  a **95 °C** con cooling-map al devfreq de la GPU (`gpuss0/gpuss1`). Sin eso, a plena velocidad el
  issue reporta 101 °C en 2 min de carga (17 W de sistema); con el half-rate el problema quedaba tapado.

### Plan de prueba (mañana, junto al kernel nuevo)

1. Añadir `msm.disable_acd=1` a `kernel-cmdline` (paquete bsp), `pocknix-build-bootimg` y reiniciar.
   Es reversible y **no** requiere recompilar kernel.
2. Medir: pinchar `min_freq=max_freq` en `/sys/class/devfreq/3d00000.gpu` y comparar antes/después
   (`vkmark`/`glmark2` o el test de FMA del issue). Vigilar temperaturas y estabilidad.
3. Si va bien y es estable, quitar los `qcom,opp-acd-level` del dtb con un parche propio (2126) para
   que no dependa del cmdline, y volver a medir/validar térmica.

## 2. Lo que NO nos hace falta de su lista (ya lo tenemos)

Revisados sus `patches-staged/upstream-2026-10-02`:

- `msm-next-2c94d177` (Adreno 830, 7.4): nuestro catálogo a830 ya trae el reglist de 7.4, incluido
  `REG_A7XX_RB_CCU_DBG_ECO_CNTL = 0x00002200`.
- `perfmode_bw`: nuestra entrada a830 (`0x44050000`) usa **10687500** (valor upstream), no 8171875.
- `qcom-…-pcie-wake-polarity`: nuestro DTS ya tiene `wake-gpios = <&tlmm 104 GPIO_ACTIVE_LOW>`.
- `msm-next-db6a2e4a/eab0aff8/128a0edd` (votos de energía/rails): ya integrados en nuestro 7.2.12.
- `bbe4401e` (THP para GEM), `8eeca96a` (shrinker): no nos consta problema de stutter por esto; revisar
  solo si aparece.
- `armada-0619` (prioridad de submitqueue): ellos lo apuntan a su issue #1 (congelación del QAM).
  Nosotros no tenemos ese síntoma; no se adopta.

## 3. Su UCM no tiene micro

Su `HiFi.conf` solo define Speaker/Headphones/HDMI: **tampoco han resuelto el micrófono interno**.
Confirma que el problema no es de configuración de usuario (sigue abierto en nuestro plan).

## 4. Otros datos

- Usan `Holo Core` (SteamOS ARM64 oficial) como userland; nosotros pocknix. Su proyecto es una
  buena referencia de qué juegos van y qué falla en la misma máquina (`docs/games-odin3.md`).
- Traen daemons propios de LED de sticks y calibración de mandos; nosotros ya cubrimos eso con el
  Panel de Control e InputPlumber.
- Su `kernel-cmdline` no lleva el fix del ACD: el issue sigue pendiente en su lado.

## Prioridad

1. **Alta**: probar `msm.disable_acd=1` (posible ~2× de GPU en los pasos altos).
2. Media: vigilar el issue #3 por si publican el arreglo definitivo (tabla ACD correcta para el bin 232).
