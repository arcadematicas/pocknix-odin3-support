#!/usr/bin/env python3
# pocknix-audio-jack — deja el audio en el dispositivo correcto y con el filtro bien enganchado.
#
# POR QUE EXISTE (dos averias reales del Odin 3):
#  1) El filtro de ecualizacion del panel (sink "AYN Odin 3 EQ") enlaza su salida a un nodo
#     ALSA concreto y WirePlumber NO la reengancha al enchufar/desenchufar: el sonido se
#     quedaba en un nodo no disponible (silencio) hasta reiniciar el filtro.
#  2) Tras reiniciar pipewire/wireplumber, el filtro puede quedar sin enlace o enlazado al
#     nodo equivocado. Antes solo se corregia al cambiar el jack; ahora se verifica cada ciclo.
import subprocess, time

CARD = "0"
JACK_NUMID = "111"
EQ_STREAM = "effect_output.pdc_eq"
EQ_SINK = "AYN Odin 3 EQ"
HW = {
    True: "alsa_output.platform-sound.HiFi__Headphones__sink",
    False: "alsa_output.platform-sound.HiFi__Speaker__sink",
}
POLL = 2.0

def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=8).stdout
    except Exception:
        return ""

def jack_plugged():
    return "values=on" in run(["amixer", "-c", CARD, "cget", f"numid={JACK_NUMID}"])

def eq_present():
    return EQ_SINK in run(["pactl", "list", "short", "sinks"])

def fix_links(plugged):
    target, other = HW[plugged], HW[not plugged]
    graph = run(["pw-link", "-l"])
    if EQ_STREAM not in graph:
        return
    for ch in ("FL", "FR"):
        src = f"{EQ_STREAM}:output_{ch}"
        dst = f"{target}:playback_{ch}"
        if src not in graph:
            return
        if f"{dst}" in graph:
            continue
        subprocess.run(["pw-link", "-d", src, f"{other}:playback_{ch}"], capture_output=True)
        subprocess.run(["pw-link", src, dst], capture_output=True)

def fix_default():
    wanted = EQ_SINK if eq_present() else None
    if wanted and run(["pactl", "get-default-sink"]).strip() != wanted:
        subprocess.run(["pactl", "set-default-sink", wanted], capture_output=True)

def main():
    while True:
        try:
            plugged = jack_plugged()
            fix_links(plugged)
            fix_default()
        except Exception:
            pass
        time.sleep(POLL)

if __name__ == "__main__":
    main()
