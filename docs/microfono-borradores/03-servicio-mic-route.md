---
title: BORRADOR — Servicio systemd para el routing del micrófono (estilo PR ArmadaOS #432)
status: NO APLICADO
---

> ⚠️ **BORRADOR — NO APLICADO.** Modelotomado del PR ArmadaOS
> https://github.com/armada-os/armada/pull/432 (Odin 2 / qcs8550, **abierta sin mergear**).
> ⚠️ **Los valores de `amixer` de abajo NO están verificados para el Odin 3**: están extrapolados del
> Odin 2, cuyo micro está en un **DMIC del WCD9395** (ruta `hw:0,2` / `TX_CODEC_DMA_TX_3`), mientras
> que en el Odin 3 el micro **probablemente** está en el **VA macro** (ruta `hw:0,3` /
> `VA_CODEC_DMA_TX_0`). **Hay que adaptarlos al inventario real** de `amixer`.

## Por qué un servicio aparte y no csets en el UCM

Del propio PR #432:

> *"Representing the internal and headset microphones as conflicting UCM devices makes ALSA ACP
> create separate card profiles because both share capture PCM hw:0,2. Switching profiles
> reconstructs the entire card, including its playback sinks."*

Es decir: modelar micro-interno y micro-headset como devices separados en el UCM, compartiendo PCM,
fuerza a PipeWire a crear **perfiles de tarjeta distintos**, y cambiar de perfil **reconstruye la
tarjeta entera** (sinks incluidos). Separar el *routing* del *declaración* de PCM lo evita.

Ventaja añadida para nosotros: si un `amixer` falla, **solo muere el servicio**, no el perfil de
audio. Mucho más seguro para probar.

---

## Opción A — script (recomendada para empezar)

`/usr/local/bin/pocknix-odin3-mic-route`:

```sh
#!/bin/sh
# BORRADOR — routing del microfono interno del AYN Odin 3 (SM8750)
#
# Por que un script y no el UCM: ver ../MICROFONO-INVESTIGACION.md §7 y §9-Fase 3.
# Los nombres de control de abajo son EXTRAPOLADOS del Odin 2 (PR armada #432) y
# hay que verificarlos con `amixer -D hw:0 controls` en el Odin 3 ANTES de fiarse.

CARD=hw:0
DMIC_A=${DMIC_A:-1}          # 1 o 2 -> par gpio7 / gpio9 (dmic01 / dmic23)

set -x

# --- Enciende el mic-bias del VA macro (B3 del DTS) ---
# El widget existe solo si vdd-micb-supply esta declarado en el .dtsi.
amixer -D "$CARD" cset name='vdd-micb' 1 2>/dev/null || true

# --- Selecciona el DMIC en el TLMM ---
# gpio6/7 -> DMIC1, gpio8/9 -> DMIC2. El pinctrl (dmic01/dmic23) ya configura
# los pines en el DTS; esto solo elige cual de los dos pares se usa.
amixer -D "$CARD" cset name="DMIC${DMIC_A} Switch" 1 2>/dev/null || true
amixer -D "$CARD" cset name="DMIC${DMIC_A} Mixer"  1 2>/dev/null || true

# --- AIF de captura del VA macro hacia el BE ---
amixer -D "$CARD" cset name='TX_AIF1_CAP Mixer DEC0' 1 2>/dev/null || true
amixer -D "$CARD" cset name='DEC0 MODE' 'ADC_DEFAULT'   2>/dev/null || true

# --- Ganancia ---
amixer -D "$CARD" cset name='TX_DEC0' 100 2>/dev/null || true

# --- Apaga ADC2 (AMIC del headset) para que no se Injectione ruido ---
amixer -D "$CARD" cset name='ADC2' 0 2>/dev/null || true

set +x
```

⚠️ **Todos los `cset` están en `|| true` a propósito**: si un control no existe en el Odin 3, el
script **no muere**. Que falle es información, no un problema (mira el log).

---

## Opción B — unidad systemd

`/etc/systemd/system/pocknix-odin3-mic-route.service`:

```ini
[Unit]
Description=Pocknix Odin 3: routing del microfono interno (VA macro DMIC)
Documentation=file:///usr/share/doc/pocknix/MICROFONO-INVESTIGACION.md
After=sound.target
Wants=sound.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/pocknix-odin3-mic-route

[Install]
WantedBy=multi-user.target
```

Activar:

```bash
sudo install -m 0755 pocknix-odin3-mic-route /usr/local/bin/
sudo install -m 0644 pocknix-odin3-mic-route.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now pocknix-odin3-mic-route.service

# ver el resultado (set -x deja el log del ExecStart en el journal)
sudo journalctl -u pocknix-odin3-mic-route -b --no-pager
```

---

## Inventario previo (OBLIGATORIO)

Nunca escribir csets a ciegas. En el Odin 3, **después** de la Fase 2 (PCM 3 ya existe):

```bash
# 1) Que controles hay realmente
amixer -D hw:0 controls | grep -iE 'DMIC|DEC|MUX|ADC|vdd-micb|VA'

# 2) El mic-bias
amixer -D hw:0 cget name='vdd-micb'

# 3) Los mux de DMIC
for i in 1 2 3 4; do amixer -D hw:0 cget name="DMIC$i Switch"; done

# 4) Existe el PCM de captura del VA macro
arecord -l | grep -i capture
```

Si `amixer -D hw:0 cget name='vdd-micb'` responde **"Invalid element"** → el `vdd-micb-supply` no
está en el DTS (B3 falló) o el módulo VA macro no está cargado. **No seguir hasta resolverlo.**

---

## Rollback

```bash
sudo systemctl disable --now pocknix-odin3-mic-route.service
sudo rm /etc/systemd/system/pocknix-odin3-mic-route.service
sudo rm /usr/local/bin/pocknix-odin3-mic-route
sudo systemctl daemon-reload
```

Como **no toca el UCM**, el rollback no puede tumbar el audio de reproducción. Ese es todo el
motivo de hacerlo así.

---

## Si resulta que el micro está en el WCD (no en el VA macro)

Entonces el routing es el del Odin 2 (verificado en el PR #432, medido −29.8 dB) pero con el
**mismo PCM que ya tienes, `hw:0,2`**, no `hw:0,3`:

```sh
# Micro INTERNO (via DMIC3 del WCD9395)
amixer -D hw:0 cset name='TX SMIC MUX0' 'SWR_MIC7'
amixer -D hw:0 cset name='DMIC3' 1
amixer -D hw:0 cset name='DMIC3_MIXER' 1
amixer -D hw:0 cset name='TX_AIF1_CAP Mixer DEC0' 1
amixer -D hw:0 cset name='DEC0 MODE' 'ADC_DEFAULT'
amixer -D hw:0 cset name='TX_DEC0' 100
amixer -D hw:0 cset name='ADC2' 0

# Micro del HEADSET (AMIC2 -> ADC2)
amixer -D hw:0 cset name='TX SMIC MUX0' 'SWR_MIC1'
amixer -D hw:0 cset name='ADC2_MIXER' 1
amixer -D hw:0 cset name='ADC2 MUX' 'INP2'
amixer -D hw:0 cset name='ADC2' 1
amixer -D hw:0 cset name='TX1 MODE' 'ADC_NORMAL'
amixer -D hw:0 cset name='TX_DEC0' 110
amixer -D hw:0 cset name='DMIC3' 0
```

> ⚠️ Nota: en el Odin 3 **ambos** fallan según la issue #362 (el barrido de `SWR_MIC*` dio nivel 0
> en SWR_MIC1 y ruido idle en el resto). Si este camino tampoco da señal, el problema es más abajo
> (DMIC clock del WCD / bias), y es el bloqueador §8.4 de la investigación.