# Nova-Deck (os-build) — hallazgos útiles (3/11/2026)

Repo: <https://github.com/Nova-Deck/os-build> (GPL-2.0, ★15, 18 issues abiertos, push 3/11).
“novadeck”: SteamOS para handhelds Snapdragon (AYN Odin 2/3, RP5/6, Pocket S2…). **Requiere
OpenABL + GRUB/EFI y arranque A/B con rollback**; su userland es SteamOS read-only.

No adoptamos su modelo (OpenABL + slots A/B + sistema read-only): es otro enfoque de arranque.
Pero su **DTS de la Odin 3** y su **pila de 178 parches de kernel** son una referencia directa.

## 1. Audio por HDMI/DisplayPort — nos resuelve el bloqueo que teníamos

Nuestro `docs/AUDIO-HDMI-20261025.md` concluía: faltaba el `dp-dai-link`, el control `DP0 Jack`,
el PCM 3 y una tplg con `DISPLAY_PORT_RX_0` (“nadie la publica”).

Nova-Deck trae exactamente el enlace que faltaba en `cq8725s-ayn-common.dtsi`:

```dts
dp-dai-link {
    link-name = "DisplayPort Playback";
    codec { sound-dai = <&mdss_dp0>; };
    cpu { sound-dai = <&q6apmbedai DISPLAY_PORT_RX_0>; };
    platform { sound-dai = <&q6apm>; };
};
```

Y su comentario aclara lo demás: **la tplg SM8750-AYN actual sí es la generación con audio DP**
(y es la de armada: `MultiMedia4` + `DISPLAY_PORT_RX_0`, 24.516 B). La nuestra (18.236 B, de una
versión anterior) **no** la tiene (`strings | grep DISPLAY_PORT` → 0).

Ruta concreta para probar (candidato para el kernel de mañana):

1. Sustituir la tplg del BSP por la de armada actual (24.516 B, sha256 `821d52b7…`), que ya tenemos
   descargada; la nuestra es una versión previa sin DP.
2. Añadir `dp-dai-link` al `cq8725s-ayn-common.dtsi` (copiable de Nova-Deck).
3. Añadir la sección `HDMI / DisplayPort playback` al UCM (plantilla ya escrita en
   `AUDIO-HDMI-20261025.md`, con `JackControl "DP0 Jack"`).
4. Probar con dock/USB-C DP: `amixer -c 0 cget name="DP0 Jack"`, `aplay -D hw:0,3`, y que el
   altavoz se mute al conectar (UCM `JackHWMute`).

Riesgo: bajo (añadir un dai-link y cambiar la tplg); se valida con el dock y se revierte fácil.

## 2. Otros detalles de su DTS que no tenemos

- **`&lpass_wsa2macro` y `&lpass_wsamacro` a `disabled`**: los altavoces van por I2S, y un macro WSA
  “bound” despierta al ADSP periódicamente sin uso. Nosotros no los tocamos (quedan como vengan del
  `sm8750.dtsi`). Candidato de ahorro de batería, a medir.
- Su `&iris`/`&lpass_vamacro` están igual que los nuestros (`okay`, `dmic-sample-rate 4800000`).
- Ellos ponen `#cooling-cells` al `pwm-fan` (thermal controla el ventilador). Nosotros lo quitamos a
  propósito (el thermal peleaba con `pocknix-fancontrol`): **no adoptar**.
- No llevan nuestras cosas de batería/LED/SoCCP/rails LPM/dither 8bpc; son decisiones distintas.

## 3. Su pila de parches (178) — referencia para display/GPU

Nombres que merecen revisarse si tocamos pantalla/suspensión/GPU:

- `0280` a8xx a830, `0281` AB GMU votes on a8xx, `0282` fix gmem base on a8xx, `0283` GMEM slices.
- `0342` inline rotation on sm8750, `0343` fix gamma LUT for sm8750 DPUs, `0350-0352` qseed detail
  enhancer, `0360` DSPP IGC/3D gamut LUTDMA, `0370` quiesce boot scanout.
- `0390` vblank timestamps on command-mode panels, `0392` merge3d command mode, `0395/0396` flushes.
- `0410` DSI wide bus bpp, `0420` keep link clocks while display active, `0430` DSI byte/pixel
  reparent on power-off, `0440` DSI PHY PLL bias on enable.
- `0120` rpmhpd don't clamp gfx/gmxc before sync_state, `0150` gcc sm8750 PCIe GDSCs retention,
  `0265` drop boot bus vote once GMU votes bandwidth, `0270` submitqueue priority.

Nuestros `2122/2123` ya cubren HFI IRQ; el resto se revisará **solo si aparece** un síntoma
(rotation, vblank, suspend DSI, GPU hang) — no meter 20 parches de display sin necesidad.

## Prioridad

1. **Alta**: audio HDMI/DP (bloqueo resuelto: tplg de armada + `dp-dai-link` + UCM).
2. Baja: desactivar los macros WSA (batería), y revisar su lista de parches si aparece un síntoma.
