# Adreno 830 — ¿bug del ACD (`qcom,opp-acd-level`) en el SM8750? (investigación, 09-oct-2026)

## Origen
Issue externo **#1** en `arcadematicas/pocknix-odin3-support`, abierto por **WhiteEagle-12**
(proyecto **Holodor**, `transentient/holodor`) — otra distro de la Odin 3 que usa nuestro
kernel `linux-pocknix-sm8750` (ellos en `7.1.3-33`).

**La afirmación**: en la Odin 3 (CQ8725S, Adreno 830, speed bin 232) los OPP del GPU que llevan
`qcom,opp-acd-level` corren a **media velocidad**: 1100 MHz daría 1,66 TFLOPS en vez de 3,38, y
**660 MHz sería más rápido que 1100**. Quitando `qcom,opp-acd-level` se recupera la velocidad
completa → "la tabla ACD llega al GMU con los niveles equivocados".

Los parches señalados son justo los que llevamos: `0038-…add-GPU-nodes` (OPPs con
`opp-acd-level`) y `0049-…adreno-830-catalog`.

## Qué comprobamos en nuestra unidad (kernel 7.2.9)
- El **DTB vivo** tiene `opp-acd-level` en los OPP altos con los **mismos valores** que citan
  (1100 → `0x88295ffd`, 967/900/832 → `0x882a5ffd`, 734 → `0x82a5ffd`, …).
- **Vulkan compute FP32** (shader propio: 8 cadenas vec4 FMA independientes; governor
  `userspace` fijando el OPP; `systemd-inhibit` para que no suspenda):

  | OPP fijo | FP32 | tiempo | ratio |
  |---|---|---|---|
  | 1100 MHz | 338,0 GFLOPS | 0,813 s | ×1,666 |
  | 660 MHz | 202,9 GFLOPS | 1,355 s | — |

  El ratio **1,666 ≈ 1100/660** → el rendimiento **escala linealmente con el OPP**. Si a 1100 el
  reloj se partiera por la mitad, 660 lo batiría; no ocurre.
- **OpenGL** (glmark2 a pantalla completa, mismos OPP fijos): 1100 > 660 (score 1394 vs 882).

## Conclusión
- **En 7.2.9 NO reproducimos el "half clock".** Su kernel `7.1.3-33` es bastante más antiguo →
  es probable que el manejo del ACD/GMU haya cambiado entre 7.1.3 y 7.2.x.
- Respondido en el issue pidiéndoles: (a) re-probar en una build 7.2.9 y (b) compartir su
  compute shader y el diff de su kernel.

## Lo que SÍ es válido del reporte (térmico)
- Nuestras zonas `gpuss0..7` solo tienen trip `hot` (120 °C) + `critical` (125 °C) y **sin
  cooling map**, aunque `devfreq-3d00000.gpu` **sí** existe como cooling device.
- A velocidad plena (OPP altos, con el techo subido) eso permite acercarse a ~101 °C.
  **Acción**: añadimos un trip **pasivo ~95 °C** mapeado al devfreq del GPU
  (parche `0056-arm64-dts-qcom-sm8750-gpu-thermal-cooling-map.patch`).

## Método reproducible
- Fijar OPP: `echo userspace > /sys/class/devfreq/3d00000.gpu/governor` y
  `min_freq = max_freq = <OPP>`; restaurar luego a `simple_ondemand`, `min=160 MHz`, `max=832 MHz`.
- Test FP32: `glslangValidator -V fma.comp -o fma.spv` + `gcc -O2 vkflops.c -o vkflops -lvulkan`.
- OpenGL: `WAYLAND_DISPLAY=gamescope-0 glmark2-wayland --fullscreen` (necesita `XDG_RUNTIME_DIR`).
- Herramientas (Odin): `glmark2` (extra), `gcc` + `vulkan-headers` (pocknix-base).
