# Decodificación de vídeo por hardware (VA-API sobre iris) — 27/11/2026

## Qué se ha añadido

El SM8750 expone dos nodos V4L2 con el driver **iris**:

```
/dev/video0  ->  qcom-iris-decoder
/dev/video1  ->  qcom-iris-encoder
```

Faltaba el puente a **VA-API**. Se empaqueta **`qcom-va-driver`** (MIT,
[`radxa-pkg/qcom-va-driver`](https://github.com/radxa-pkg/qcom-va-driver), commit `0980a1d`), que
instala `/usr/lib/dri/qcom_drv_video.so` (más los symlinks legacy `v4l2_` y `msm_`).

Detalle visto en el PR de Armada ([armada-os/armada#946](https://github.com/armada-os/armada/pull/946)).

## Verificado en la Odin (27/11/2026)

`vainfo` reconoce el backend sin variables de entorno (es el único driver VA):

```
vainfo: Driver version: Iris V4L2 stateful VA-API backend
```

Perfiles:

| Códec | Decode (VLD) | Encode |
|---|---|---|
| H.264 Baseline / Main / High | ✅ | ✅ (`EncSlice`) |
| HEVC Main | ✅ | ✅ |
| HEVC Main10 | ✅ | — |
| VP9 Profile0 / Profile2 | ✅ | — |
| AV1 Profile0 | ✅ | — |

Prueba real con `ffmpeg -hwaccel vaapi` sobre un H.264 720p generado al vuelo:

```
[h264] Reinit context to 1280x720, pix_fmt: vaapi
150 frames decoded; 0 decode errors; speed 43x
```

## Compilación

`packages/qcom-va-driver/PKGBUILD` (en `packages.list` del sm8750 para que entre en la imagen):

- `-Dgpu_copy=enabled` — copia de superficies por EGL/GLES.
- `-Dcdsp_vpp=disabled` y `-Dvulkan_vpp=disabled` — el VPP (procesado de vídeo en DSP/GPU) exige
  GHC y cabeceras Vulkan y no aporta nada al decode/encode básico. Se puede activar más adelante.

Dependencias de ejecución: `libva`, `libdrm`, `mesa`.

## Para qué nos sirve

- **Moonlight**: decodificar el stream por hardware en vez de CPU (menos latencia y consumo).
- **Reproducción de vídeo** (mpv, navegadores): H.264/HEVC/VP9/AV1 por hardware.
- **Grabación/captura**: el encoder H.264/HEVC por hardware queda también accesible por VA-API.

## Pendiente de probar con pantalla

1. Moonlight contra el PC (H.264 y HEVC) y comparar CPU/consumo con la decodificación software.
2. Un vídeo 4K HEVC en mpv con `--hwdec=vaapi`.
3. Que no interfiera con la captura (`calvos-grabar`) ni con Steam/gamescope.

## Notas

- No hace falta `LIBVA_DRIVER_NAME`; si algún día conviven varios drivers VA, se fuerza con
  `LIBVA_DRIVER_NAME=qcom`.
- El symlink `msm_drv_video.so` **no** choca con el `msm_dri.so` de OpenGL de Mesa (son espacios de
  nombres distintos: VA-API vs DRI).
