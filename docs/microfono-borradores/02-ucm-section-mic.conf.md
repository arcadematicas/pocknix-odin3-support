---
title: BORRADOR — Sección de captura "Mic" para el UCM del Odin 3
status: NO APLICADO
---

> ⚠️ **BORRADOR — NO APLICADO.** Este fichero **NO** es un parche de UCM de producción: es la
> sección a añadir **a mano** al final del `HiFi.conf` de
> `AYN/Odin3` (`/usr/share/alsa/ucm2/AYN/Odin3/HiFi.conf`) **una vez hechos** las Fases 1 y 2.
>
> ⛔ **Antes de nada, lee `../MICROFONO-INVESTIGACION.md` §7 y §9.** Añadir un `SectionDevice` con
> un PCM que falla **hace que PipeWire descarte el perfil entero** (`ucm_probe_profile_set` →
> `p->supported = false`) → **Dummy Output**, o sea *todo* el audio muerto, no solo el micro.

## Por qué este fichero es deliberadamente MÍNIMO

El UCM actual de `AYN/Odin3/HiFi.conf` solo declara `Speaker` (PCM 0) y `Headphones` (PCM 1).
Añadir un `SectionDevice."Mic"` es lo queimatha de romper el audio según la issue ArmadaOS #362,
porque:

1. El probe de PipeWire abre **todos** los PCM del perfil. Si el PCM 3 no tiene ruta en el DSP
   (topología sin `VA_CODEC_DMA_TX_0`), falla y se cae el perfil completo.
2. Los `EnableSequence` con `cset` se ejecutan **al activar** el perfil, no en el probe. Si un
   `cset` apunta a un control o valor de enum que no existe en el machine driver del Odin 3, la
   secuencia aborta.

Por eso aquí **no hay includes ni csets**: solo el `Value` que declara el PCM. El *routing* del
códec va en [`03-servicio-mic-route.md`](03-servicio-mic-route.md), igual que en el PR ArmadaOS #432.

---

## La sección a añadir

```conf
SectionDevice."Mic" {
	Comment "Internal microphone (LPASS VA macro DMIC)"

	# Deliberadamente sin EnableSequence / cset / CaptureMixerElem:
	# un cset a un control inexistente aborta la secuencia y tumba el perfil.
	# El routing lo hace pocknix-odin3-mic-route.service (ver 03-...).

	Value {
		CapturePriority 200
		CapturePCM "hw:${CardId},3"
		CaptureChannels 2
	}
}
```

## Por qué `hw:${CardId},3`

| PCM | dai-link (orden del DT) | DAI |
|---|---|---|
| 0 | `spk-i2s-dai-link` | `SECONDARY_MI2S_RX` (altavoz) |
| 1 | `wcd-playback-dai-link` | `RX_CODEC_DMA_RX_0` (auriculares) |
| 2 | `wcd-capture-dai-link` | `TX_CODEC_DMA_TX_3` (**WCD**: AMIC/SWR_MIC/DMIC del códec) |
| **3** | `va-dai-link` *(añadido en Fase 2)* | `VA_CODEC_DMA_TX_0` (**VA macro**: DMIC de 1 bit) |

Es el mismo PCM que usa el UCM del MTP (`Qualcomm-sm8750/MTP/HiFi.conf`). El `${CardId}` es
imprescindible: fija la tarjeta, no el índice global.

---

## Variante con EnableSequence (⚠️ SOLO tras confirmar los controles)

Si el servicio systemd (fichero 03) resulta insuficiente y hay que mover el routing al UCM,
**primero** inventariar los controles reales del Odin 3:

```bash
amixer -D hw:0 controls | grep -iE 'DMIC|DEC|vdd-micb|VA_'
amixer -D hw:0 cget name='DMIC1 Switch'
```

Solo entonces, y **un cset por línea**, con la forma que usa el UCM del MTP:

```conf
SectionDevice."Mic" {
	Comment "Internal microphone"

	EnableSequence [
		cset "name='DMIC1 Switch' 1"
		cset "name='DMIC1 Mixer' 1"
		cset "name='DMIC1' 1"
	]

	DisableSequence [
		cset "name='DMIC1 Switch' 0"
		cset "name='DMIC1 Mixer' 0"
	]

	Value {
		CapturePriority 200
		CapturePCM "hw:${CardId},3"
		CaptureChannels 2
	}
}
```

> ⚠️ Los nombres de control exactos (`DMIC1 Switch`, `DMIC1 Mixer`, …) **hay que confirmarlos con
> `amixer` en el Odin 3**. No están verificados aquí: el barrido de la issue #362 los lista como
> `MSM_DMIC*`, que es la nomenclatura de Android, no la de mainline.
> Un nombre inventado = `cset` aborta la secuencia = perfil no activable.

Referencia alternativa con más detalle: `Qualcomm-sm8750/MTP/HiFi.conf` incluye
`/codecs/qcom-lpass/va-macro/DMIC0EnableSeq.conf` y `DMIC1EnableSeq.conf`, que están en el paquete
`alsa-ucm-conf` de Pocknix bajo `/usr/share/alsa/ucm2/codecs/qcom-lpass/va-macro/`.

---

## Aplicar / revertir

```bash
# backup
sudo cp /usr/share/alsa/ucm2/AYN/Odin3/HiFi.conf \
        /usr/share/alsa/ucm2/AYN/Odin3/HiFi.conf.bak-mic

# ... editar el fichero a mano (añadir el SectionDevice al final) ...

# recarga: ALSA ACP lee el UCM al arrancar el perfil; no hace falta reiniciar
sudo systemctl restart alsa-restore    # si existe; si no: cierra la sesión de audio

# revertir
sudo cp /usr/share/alsa/ucm2/AYN/Odin3/HiFi.conf.bak-mic \
        /usr/share/alsa/ucm2/AYN/Odin3/HiFi.conf
```

## Verificar

```bash
pw-cli list-objects | grep -i 'node.name'      # debe aparecer la source Mic
pw-top                                         # nivel de la source Mic
arecord -D hw:0,3 -f S16_LE -r 48000 -c 2 -d 10 -v
```

⚠️ Si `pw-cli` deja de listar **los sinks** → el perfil se ha descartado → rollback inmediato
(quitar la sección y reiniciar la sesión de audio).