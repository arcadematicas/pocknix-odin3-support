#!/usr/bin/env python3
"""Convierte los frames de la bootanimation Odin 3 a raw BGRX para /dev/fb0.

La bootanimation original es landscape 1920x1080. El fb0 del Odin 3 es
msmdrmfb 1080x1920 (portrait) con stride 4352 y 32bpp BGRX. Para que se vea
derecha al sostener el dispositivo en landscape aplicamos:
    fb0[y][x] = A[1080-1-x][y]   (== np.flip(A, axis=0).transpose(1,0,2))
Transformacion verificada empiricamente con una imagen de prueba (flechas).

Uso:
    python3 convert_frames.py [N] [INICIO]
        N      numero de frames a convertir (default: 240)
        INICIO indice inicial (default: 0)
    Variables de entorno:
        SRC_DIR directorio con los PNG de entrada (default: ./frames_reduced)
        OUT_DIR directorio de salida (default: ./frames_raw)

Entrada esperada: PNGs landscape 960x540 llamados odin_XXXXX.png
                  (o cualquier resolucion WxH; se escalan a 1920x1080).
Salida: raw BGRX de 1080x1920, stride 4352, frame_XXXX.raw (8,355,840 bytes).
"""
import sys
import os
import numpy as np
from PIL import Image

SRC_DIR = os.environ.get("SRC_DIR", "frames_reduced")
OUT_DIR = os.environ.get("OUT_DIR", "frames_raw")
STRIDE = 4352              # stride del fb0 (1080*4 + 32 de padding)
TARGET_LANDSCAPE = (1920, 1080)  # tamano al que escalamos antes de rotar
TOTAL_FRAMES = 240


def convert_one(src_path, out_path):
    img = Image.open(src_path).convert("RGB")
    img = img.resize(TARGET_LANDSCAPE, Image.LANCZOS)
    arr = np.array(img)                          # (1080, 1920, 3)
    fb = np.flip(arr, axis=0).transpose(1, 0, 2)  # (1920, 1080, 3)
    h, w = fb.shape[0], fb.shape[1]
    bgrx = np.zeros((h, w, 4), dtype=np.uint8)
    bgrx[:, :, 0] = fb[:, :, 2]  # B
    bgrx[:, :, 1] = fb[:, :, 1]  # G
    bgrx[:, :, 2] = fb[:, :, 0]  # R
    bgrx[:, :, 3] = 255          # X (opaco)
    buf = np.zeros((h, STRIDE), dtype=np.uint8)
    buf[:, : w * 4] = bgrx.reshape(h, w * 4)
    buf.tofile(out_path)


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else TOTAL_FRAMES
    start = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    os.makedirs(OUT_DIR, exist_ok=True)
    for i in range(start, min(start + n, TOTAL_FRAMES)):
        src = os.path.join(SRC_DIR, f"odin_{i:05d}.png")
        dst = os.path.join(OUT_DIR, f"frame_{i:04d}.raw")
        convert_one(src, dst)
        print(f"OK frame {i}: {os.path.getsize(dst)} bytes")
    print("Fin")


if __name__ == "__main__":
    main()
