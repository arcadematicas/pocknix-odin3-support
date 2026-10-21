#!/usr/bin/env python3
"""panel-vhz.py — mide el refresco REAL del panel (Hz) leyendo vblanks por DRM.

Sirve para saber en que modo esta el panel de verdad, sin fiarse de lo que diga el
compositor: gamescope con `-r 60` NO cambia el modo DRM (solo limita fps), y el QAM
tampoco lo cambia (el cliente ARM solo lo lee).

Uso (en la consola):
    sudo python3 panel-vhz.py          # imprime p.ej. 120.04

Ojo: necesita un CRTC activo. Con kwin como master DRM suele fallar ("sin vblank");
funciona bien bajo gamescope. Copia en /tmp/vhz.py para la sesion (tmpfs se borra al
reiniciar).
"""
import fcntl
import glob
import os
import struct
import sys
import time

DRM_IOCTL_WAIT_VBLANK = 0xC018643A


def wait(fd, pipe):
    buf = bytearray(struct.pack("IIqq", 1 | pipe << 1, 1, 0, 0))
    fcntl.ioctl(fd, DRM_IOCTL_WAIT_VBLANK, buf)
    _, _, sec, usec = struct.unpack("IIqq", buf)
    return sec + usec / 1e6


for card in sorted(glob.glob("/dev/dri/card*")):
    fd = os.open(card, os.O_RDWR)
    for pipe in range(8):
        try:
            wait(fd, pipe)
            ts, end = [], time.monotonic() + 0.6
            while time.monotonic() < end:
                ts.append(wait(fd, pipe))
            print("%.2f" % ((len(ts) - 1) / (ts[-1] - ts[0])))
            sys.exit(0)
        except OSError:
            pass
print("sin vblank")
sys.exit(1)
