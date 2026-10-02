# Borradores — micrófono interno AYN Odin 3 (SM8750)

> ⚠️ **NADA DE ESTO ESTÁ APLICADO.** Son borradores de trabajo derivados de
> [`../MICROFONO-INVESTIGACION.md`](../MICROFONO-INVESTIGACION.md).
> No toques nada hasta que la Fase 0 (ver más abajo) esté hecha.

## Orden correcto de aplicación

| Orden | Fichero | Qué hace | Riesgo |
|---|---|---|---|
| **Fase 0** | [`00-fase0-extraer-android.sh`](00-fase0-extraer-android.sh) | Descubrimiento: extrae `audio_platform.xml` + topología del Android del AYN (solo lectura) y **dice qué camino toca** | 0 |
| — | [`05-analisis-topologias.md`](05-analisis-topologias.md) | Censo de todas las topologías disponibles (02/10): **ninguna** tiene VA **y** Secondary MI2S, y los AYN con micro funcionando lo llevan en el **WCD** | 0 |
| **Fase 1** | [`04-obtener-topologia-va.md`](04-obtener-topologia-va.md) | Sustituir `SM8750-AYN-tplg.bin` por una con `VA_CODEC_DMA_TX_0` **y** Secondary MI2S | 🔴 ALTO |
| **Fase 2** | [`01-dts-va-dai-link.patch`](01-dts-va-dai-link.patch) + [guía](01-dts-va-dai-link.md) | Habilitar `lpass_vamacro`/`lpass_tlmm` + pinctrl + mic-bias + `va-dai-link` | 🟡 MEDIO |
| **Fase 3** | [`02-ucm-section-mic.conf`](02-ucm-section-mic.conf.md) y/o [`03-servicio-mic-route.md`](03-servicio-mic-route.md) | Encender la ruta en el mixer | 🟡 MEDIO |
| **Fase 4** | — | Validar end-to-end con `pw-top` / `arecord` | 0 |

**⛔ Por qué Fase 1 va antes que Fase 2**: sin una topología con `VA_CODEC_DMA_TX_0` en el DSP, el
PCM 3 que crea el dai-link existe en ALSA pero no tiene ruta en el firmware → silencio o
`Input/output error`, y un `SectionDevice."Mic"` que lo use **puede tumbar el perfil de audio
entero** (PipeWire marca `p->supported = false` si un PCM falla → `Dummy Output`).

## Por qué 3 (servicio systemd) y no solo 2 (UCM)

El PR ArmadaOS #432 (Odin 2) aprendió esto: si el micro interno y el del headset se modelan como
`SectionDevice`s **distintos pero con el mismo PCM de captura**, PipeWire crea **perfiles de
tarjeta separados**, y cambiar de perfil **reconstruye la tarjeta entera** incluyendo los sinks de
reproducción. Por eso separan el *routing* (un `amixer` aparte) del UCM (que solo declara el PCM).

## Verificación rápida antes de nada

```bash
# ¿YA está arreglado por casualidad? (no debería)
lsmod | grep va-macro
arecord -l
amixer -D hw:0 cget name='vdd-micb' 2>/dev/null
```

## Rollback global

| Fase | Rollback |
|---|---|
| 1 | `cp SM8750-AYN-tplg.bin.bak SM8750-AYN-tplg.bin && reboot` |
| 2 | `git checkout kernel/dts/cq8725s-ayn-common.dtsi` (o `patch -R -p1 < 01-dts-va-dai-link.patch`) + recompilar kernel + reinstalar `/flash/KERNEL` |
| 3 | restaurar el `.conf` anterior + `systemctl restart alsa-restore` |

⚠️ La Fase 2 exige **recompilar el kernel y reinstalar la imagen de boot** (`/flash/KERNEL`, con
backup previo). El rollback es volver al `KERNEL.bak` anterior.