#!/usr/bin/env python3
# pocknix-audio-jack — mantiene el audio en el dispositivo correcto al conmutar el jack.
#
# POR QUE EXISTE (tres averias reales del Odin 3, todas verificadas):
#  1) El filtro de ecualizacion del panel (sink "AYN Odin 3 EQ") enlaza su salida a un nodo
#     ALSA concreto y WirePlumber NO la reengancha al enchufar/desenchufar: el sonido se
#     quedaba en un nodo no disponible (silencio).
#  2) Al desenchufar, los amplificadores del altavoz (AW88166, controles `SPK_L/R PCM Playback
#     Volume`) se quedan a 0 -> silencio aunque la ruta sea correcta. Nadie los restaura.
#  3) Al reiniciar pipewire/wireplumber el filtro puede quedar sin enlace. Antes solo se
#     corregia al cambiar el jack.
#
# COMO FUNCIONA: se despierta con `pactl subscribe` (instantaneo, sin esperar 2 s) y ademas
# hace una pasada de seguridad cada 5 s. En cada pasada deja:
#   - el sink por defecto en el ecualizador (o en el altavoz si no hay EQ),
#   - la salida del filtro enganchada SOLO al nodo disponible,
#   - los amplificadores del altavoz a un volumen audible si no hay auriculares.
import os
import subprocess
import sys
import threading
import time

CARD = "0"
JACK_NUMID = "111"
EQ_STREAM = "effect_output.pdc_eq"
EQ_SINK = "AYN Odin 3 EQ"
SPK_VOL_NUMIDS = ("2", "8")        # SPK_L/R PCM Playback Volume (AW88166)
SPK_VOL = 950                      # 0..1023; a 0 el altavoz es silencio absoluto
HW = {
    True: "alsa_output.platform-sound.HiFi__Headphones__sink",
    False: "alsa_output.platform-sound.HiFi__Speaker__sink",
}
TICK = 10.0                            # red de seguridad (el camino rapido es por eventos)
SETTLE = 0.20                      # deja que PulseAudio/PipeWire asiente tras el evento


def run(cmd, timeout=8):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:
        return ""


def jack_plugged():
    return "values=on" in run(["amixer", "-c", CARD, "cget", f"numid={JACK_NUMID}"])


def eq_present():
    return EQ_SINK in run(["pactl", "list", "short", "sinks"])


def ensure_spk_volume():
    """Si no hay auriculares, los amps del altavoz deben estar por encima de 0."""
    changed = False
    for numid in SPK_VOL_NUMIDS:
        out = run(["amixer", "-c", CARD, "cget", f"numid={numid}"])
        if "values=0" in out.replace(" ", ""):
            run(["amixer", "-c", CARD, "cset", f"numid={numid}", str(SPK_VOL)])
            changed = True
    return changed


def fix_links(plugged):
    target, other = HW[plugged], HW[not plugged]
    graph = run(["pw-link", "-l"])
    if EQ_STREAM not in graph:
        return False
    changed = False
    for ch in ("FL", "FR"):
        src = f"{EQ_STREAM}:output_{ch}"
        if src not in graph:
            return changed
        dst = f"{target}:playback_{ch}"
        if dst in graph:
            continue
        run(["pw-link", "-d", src, f"{other}:playback_{ch}"])
        run(["pw-link", src, dst])
        changed = True
    return changed


def fix_default(plugged):
    wanted = EQ_SINK if eq_present() else HW[plugged]
    if run(["pactl", "get-default-sink"]).strip() != wanted:
        run(["pactl", "set-default-sink", wanted])
        return True
    return False


def apply_all(reason=""):
    """Deja todo en su sitio y, si ha cambiado algo, deja una linea en el journal con tiempos.

    La linea sirve para MEDIR la conmutacion: `pocknix-audio-jack` aparece en `journalctl -u`
    con los ms que ha tardado y que acciones han hecho falta. Sin esto, "tarda bastante" es
    una impresion; con esto es un numero.
    """
    t0 = time.monotonic()
    plugged = jack_plugged()
    links = fix_links(plugged)
    default = fix_default(plugged)
    amps = ensure_spk_volume() if not plugged else False
    dt_ms = (time.monotonic() - t0) * 1000.0
    if links or default or amps:
        acciones = ",".join(
            n for n, v in (("links", links), ("default", default), ("amps", amps)) if v
        )
        print(
            f"{time.strftime('%H:%M:%S')} jack={'on' if plugged else 'off'} "
            f"acciones={acciones} {dt_ms:.0f}ms" + (f" motivo={reason}" if reason else ""),
            flush=True,
        )
    return plugged


def watch_events(stop):
    """pactl subscribe: reacciona al instante a cambios de tarjeta/sink."""
    while not stop.is_set():
        try:
            proc = subprocess.Popen(
                ["pactl", "subscribe"],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
                env={**os.environ, "XDG_RUNTIME_DIR": os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")},
            )
        except Exception:
            time.sleep(2)
            continue
        try:
            for line in proc.stdout:
                if stop.is_set():
                    break
                low = line.lower()
                if " on card " in low or " on sink " in low or " on server " in low:
                    time.sleep(SETTLE)
                    apply_all(reason="evento")
        finally:
            try:
                proc.terminate()
            except Exception:
                pass
        time.sleep(1)


def main():
    apply_all()                      # estado inicial
    stop = threading.Event()
    t = threading.Thread(target=watch_events, args=(stop,), daemon=True)
    t.start()
    try:
        while True:                  # red de seguridad
            time.sleep(TICK)
            apply_all()
    except KeyboardInterrupt:
        stop.set()


if __name__ == "__main__":
    main()
