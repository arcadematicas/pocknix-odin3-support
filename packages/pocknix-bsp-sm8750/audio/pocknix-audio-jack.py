#!/usr/bin/env python3
# pocknix-audio-jack — mantiene el audio en el dispositivo correcto al conmutar el jack.
#
# POR QUE EXISTE (tres averias reales del Odin 3, todas verificadas):
#  1) El filtro de ecualizacion del panel (sink "AYN Odin 3 EQ") enlaza su salida a un nodo
#     ALSA concreto y WirePlumber NO la reengancha al enchufar/desenchufar: el sonido se
#     quedaba en un nodo no disponible (silencio).
#  2) Al desenchufar, el codec deja encendidos los switches de auriculares (HPHL/HPHR, RDAC,
#     CLSH) y el altavoz queda mudo aunque la ruta de PipeWire sea la correcta.
#  3) Al reiniciar pipewire/wireplumber el filtro puede quedar sin enlace. Antes solo se
#     corregia al cambiar el jack.
#
# COMO FUNCIONA: se despierta con `pactl subscribe` (instantaneo, sin esperar 2 s) y ademas
# hace una pasada de seguridad cada 5 s. En cada pasada deja:
#   - el sink por defecto en el ecualizador (o en el altavoz si no hay EQ),
#   - la salida del filtro enganchada SOLO al nodo disponible,
#   - los amplificadores del altavoz a un volumen audible si no hay auriculares.
import os
import pwd
import subprocess
import sys
import threading
import time

CARD = "0"
JACK_NUMID = "111"
EQ_STREAM = "effect_output.pdc_eq"
EQ_SINK = "AYN Odin 3 EQ"
# OJO: `SPK_L/R PCM Playback Volume` (AW88166) es ATENUACION en este driver: 0 = maximo
# y AW88166_MUTE_VOL = mute. No se toca (ponerlo alto deja el altavoz casi mudo).

# PA de auriculares (wcd939x): al reenchufar, WirePlumber no siempre re-ejecuta la secuencia
# UCM y el switch se queda apagado -> PipeWire cree que suena por los cascos pero el codec no
# los ha encendido. Se vigila y, si esta fuera, se re-aplica el device de la UCM.
HPH_NUMID = "25"
HPH_MODE_NUMID = "14"
HPH_MODE = "CLS_H_LOHIFI"   # class-H con compander: el estado validado en la Odin
# El UCM esta partido en dos VERBOS (perfiles): "HiFi" (altavoz) y "Headphones" (jack).
# Conmutar de perfil re-ejecuta la EnableSequence, que es lo que evita el zumbido; por eso
# el daemon ya no hace el ciclo off->perfil, sino que CAMBIA de perfil.
PROFILE = {True: "Headphones", False: "HiFi"}
# Fragmento del nombre del sink que crea cada perfil (se resuelve en caliente).
SINK_MATCH = {True: "Headphones__Headphones", False: "HiFi__Speaker"}
HW = {   # respaldo por si no se encuentra el sink (nombres antiguos)
    True: "alsa_output.platform-sound.HiFi__Headphones__sink",
    False: "alsa_output.platform-sound.HiFi__Speaker__sink",
}
TICK = 3.0
POLL = 1.0            # sondeo del jack: un `amixer cget` cuesta ~5 ms y elimina la rely on events                            # red de seguridad (el camino rapido es por eventos)
SETTLE = 0.20
LAST_JACK = {"plugged": None}
# Al enchufar CON audio en curso, el stream del juego se mueve al sink de auriculares DESPUES
# de nuestro reset, y ese movimiento deja el transporte mal (zumbido). Un segundo reset, ya
# con el stream asentado, lo deja bien.
SECOND_RESET = {"at": 0.0}


def run(cmd, timeout=8):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:
        return ""


# El servicio corre como root (hace falta para los controles ALSA del codec), pero `pactl` se
# NIEGA a conectar con el PipeWire del usuario desde root: "Connection refused". Todo lo que
# hable con PipeWire se lanza como el usuario de la sesion.
SEAT_USER = os.environ.get("POCKNIX_SEAT_USER", "deck")
try:
    _seat = pwd.getpwnam(SEAT_USER)
    SEAT_UID, SEAT_GID = _seat.pw_uid, _seat.pw_gid
except KeyError:
    SEAT_UID, SEAT_GID = 1000, 1000


def run_user(cmd, timeout=8):
    # setpriv y no runuser: runuser abre una sesion PAM por llamada y el journal se llena
    # de "session opened/closed" cada segundo.
    return run(["setpriv", f"--reuid={SEAT_UID}", f"--regid={SEAT_GID}", "--init-groups",
                "env", f"XDG_RUNTIME_DIR=/run/user/{SEAT_UID}", *cmd], timeout)


def jack_plugged():
    return "values=on" in run(["amixer", "-c", CARD, "cget", f"numid={JACK_NUMID}"])


def eq_present():
    return EQ_SINK in run_user(["pactl", "list", "short", "sinks"])


def ensure_headphone_amp(plugged):
    """Re-aplica la UCM de auriculares si el PA se quedo apagado.

    Coste: un `amixer cget` (~5 ms). Solo actua cuando el switch esta fuera, asi que no
    interfiere con una ruta que ya funciona. Con la compander encendida (la enciende el
    propio DAPM con class-H) y la impedancia medida por el driver, este es el estado bueno.
    """
    if not plugged:
        return False
    if "values=on" in run(["amixer", "-c", CARD, "cget", f"numid={HPH_NUMID}"]):
        return False
    # 1) Pedir la secuencia a la UCM (hace el routing completo cuando la re-ejecuta).
    run(["alsaucm", "-c", f"hw:{CARD}", "set", "_verb", "Headphones", "set", "_enadev", "Headphones"])
    # 2) Si la UCM no la re-ejecuto (device ya dado de alta), forzar el PA y el modo. Comprobado
    #    en la Odin: sin esto los switches se quedan fuera y no suena por los cascos.
    for numid in ("25", "26", "27", "142", "143", "23", "24"):
        run(["amixer", "-c", CARD, "cset", f"numid={numid}", "on"])
    run(["amixer", "-c", CARD, "cset", f"numid={HPH_MODE_NUMID}", HPH_MODE])
    run(["amixer", "-c", CARD, "cset", "numid=31", "18"])
    run(["amixer", "-c", CARD, "cset", "numid=32", "18"])
    return True


def fix_links(plugged):
    target, other = sink_for(plugged), sink_for(not plugged)
    graph = run_user(["pw-link", "-l"])
    if EQ_STREAM not in graph:
        return False
    changed = False
    for ch in ("FL", "FR"):
        src = f"{EQ_STREAM}:output_{ch}"
        if src not in graph:
            return changed
        dst = f"{target}:playback_{ch}"
        alt = f"{other}:playback_{ch}"
        if dst in graph:
            continue
        if alt in graph:
            run_user(["pw-link", "-d", src, alt])
        # Solo cuenta si el enlace SE CREA: al enchufar, el sink de auriculares puede
        # tardar un momento en aparecer y `pw-link` falla; antes se daba por hecho y no
        # se reintentaba, dejando el audio en el altavoz con los cascos puestos.
        r = subprocess.run(["setpriv", f"--reuid={SEAT_UID}", f"--regid={SEAT_GID}", "--init-groups", "env", f"XDG_RUNTIME_DIR=/run/user/{SEAT_UID}", "pw-link", src, dst], capture_output=True)
        if r.returncode != 0:
            continue
        changed = True
    return changed


def ensure_gain():
    """-3 dB de headroom en el PA (WirePlumber restaura su estado del mezclador y lo pisa)."""
    if "values=18" in run(["amixer", "-c", CARD, "cget", "numid=31"]):
        return False
    run(["amixer", "-c", CARD, "cset", "numid=31", "18"])
    run(["amixer", "-c", CARD, "cset", "numid=32", "18"])
    return True


def card_name():
    cards = run_user(["pactl", "list", "short", "cards"]).splitlines()
    if not cards:
        return ""
    parts = cards[0].split("\t")
    return parts[1] if len(parts) > 1 else (cards[0].split()[1] if len(cards[0].split()) > 1 else "")


def active_profile():
    for line in run_user(["pactl", "list", "cards"]).splitlines():
        if "Active Profile:" in line:
            return line.split(":", 1)[1].strip()
    return ""


def sink_for(plugged):
    for line in run_user(["pactl", "list", "short", "sinks"]).splitlines():
        if SINK_MATCH[plugged] in line:
            parts = line.split("\t")
            return parts[1] if len(parts) > 1 else line.split()[1]
    return HW[plugged]


def set_profile(plugged):
    """Conmuta al perfil del estado del jack. Devuelve True si ha cambiado."""
    wanted = PROFILE[plugged]
    cur = active_profile()
    if not cur or cur == wanted:
        return False
    name = card_name()
    if not name:
        return False
    run_user(["pactl", "set-card-profile", name, wanted])
    time.sleep(SETTLE)
    return active_profile() == wanted


def hard_reset():
    """Cierra y reabre el PCM de la tarjeta: es exactamente lo que hace reenchufar.

    Algunos arranques dejan el transporte SoundWire mal y suena con zumbido aunque los
    controles parezcan buenos; reabrir el PCM lo reinicia (medido: el replug lo cura).
    """
    cards = run_user(["pactl", "list", "short", "cards"]).splitlines()
    if not cards:
        return False
    name = cards[0].split("\t")[1] if len(cards[0].split("\t")) > 1 else cards[0].split()[1]
    listing = run_user(["pactl", "list", "cards"])
    prof = ""
    for line in listing.splitlines():
        if "Active Profile:" in line:
            prof = line.split(":", 1)[1].strip()
            break
    if not prof or prof == "off":
        return False
    run_user(["pactl", "set-card-profile", name, "off"])
    time.sleep(0.3)
    run_user(["pactl", "set-card-profile", name, prof])
    time.sleep(0.3)
    return True


def fix_default(plugged):
    wanted = EQ_SINK if eq_present() else sink_for(plugged)
    if run_user(["pactl", "get-default-sink"]).strip() != wanted:
        run_user(["pactl", "set-default-sink", wanted])
        return True
    return False


def apply_all(reason="", hard=False):
    """Deja todo en su sitio y, si ha cambiado algo, deja una linea en el journal con tiempos.

    La linea sirve para MEDIR la conmutacion: `pocknix-audio-jack` aparece en `journalctl -u`
    con los ms que ha tardado y que acciones han hecho falta. Sin esto, "tarda bastante" es
    una impresion; con esto es un numero.
    """
    t0 = time.monotonic()
    plugged = jack_plugged()
    # Conmutar de PERFIL ya reabre el PCM y re-ejecuta la UCM (es el arreglo de fondo).
    switched = set_profile(plugged)
    # Red de seguridad: si el perfil ya era el correcto (p.ej. replug), reabrir el PCM.
    reset = hard_reset() if (hard and plugged and not switched) else False
    links = fix_links(plugged)
    # El sink por defecto SOLO se toca en eventos (jack/streams) y al arrancar. En el tick
    # periodico no: WirePlumber reaplica su "default.configured.audio.sink" y entrabamos en
    # un bucle de set/revert cada 10 s (se veia como "acciones=default 28ms" sin parar).
    default = fix_default(plugged) if reason != "tick" else False
    amps = False   # no se tocan los amps del altavoz: su volumen es atenuacion (0 = maximo)
    codec = ensure_headphone_amp(plugged)
    gain = ensure_gain() if plugged else False
    dt_ms = (time.monotonic() - t0) * 1000.0
    LAST_JACK["plugged"] = plugged
    if reset or links or default or amps or codec or gain:
        acciones = ",".join(
            n for n, v in (("perfil", switched), ("reset", reset), ("links", links), ("default", default), ("amps", amps), ("codec", codec), ("gain", gain)) if v
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
                    # El evento de tarjeta llega ANTES de que amixer vea el jack en su
                    # estado nuevo: sin esta espera se aplica el estado viejo, no cambia
                    # nada y el cambio real se pospone al tick (de ahi los "2-10 s").
                    for _ in range(12):
                        if jack_plugged() != LAST_JACK["plugged"]:
                            break
                        time.sleep(0.15)
                    apply_all(reason="evento")
        finally:
            try:
                proc.terminate()
            except Exception:
                pass
        time.sleep(1)


def main():
    apply_all()                      # estado inicial
    # Sondeo propio en vez de `pactl subscribe`: el hijo de pactl podia morir y el servicio
    # se quedaba solo con el tick (de ahi los 2-10 s). Un `amixer cget` cada segundo cuesta
    # ~5 ms y no depende de nadie; solo se hace trabajo cuando el estado cambia.
    try:
        while True:
            time.sleep(POLL)
            if jack_plugged() != LAST_JACK["plugged"]:
                now = jack_plugged()
                apply_all(reason="poll", hard=(now and LAST_JACK["plugged"] is False))
                SECOND_RESET["at"] = (time.monotonic() + 3.0) if now else 0.0
            elif SECOND_RESET["at"] and time.monotonic() >= SECOND_RESET["at"]:
                SECOND_RESET["at"] = 0.0
                if LAST_JACK["plugged"]:
                    hard_reset()
                    ensure_headphone_amp(True)
                    ensure_gain()
                    fix_links(True)
                    fix_default(True)
                    print(f"{time.strftime('%H:%M:%S')} reset tardio (stream asentado)", flush=True)
            elif LAST_JACK["plugged"] is not None:
                if fix_links(LAST_JACK["plugged"]):
                    # Enlaces rehechos: el sink de destino no estaba cuando se enchufo.
                    print(f"{time.strftime('%H:%M:%S')} enlaces rehechos "
                          f"jack={'on' if LAST_JACK['plugged'] else 'off'}", flush=True)
                    fix_default(LAST_JACK["plugged"])
                # WirePlumber puede re-aplicar el perfil un segundo despues y dejar el PA de
                # auriculares otra vez fuera: se vigila en cada tick (un `amixer cget`, ~5 ms).
                if ensure_headphone_amp(LAST_JACK["plugged"]):
                    print(f"{time.strftime('%H:%M:%S')} PA de auriculares rehecho", flush=True)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
