#!/usr/bin/python3
"""Apaga el modo "island" del SSC en el AYN Odin 3 (pakala).

Con la isla activada, un s2idle entrado justo despues de cerrar un sensor cuelga el SoC
(armada-os/armada 623e96d3). El config y el registro de sensores se enlazan desde el firmware,
que es de solo lectura; aqui se copian a /run, se pone enable_island=0 y se deja el enlace
apuntando a la copia.

El modelo se lee de /proc/device-tree/model: en la Odin 3 el DMI viene vacio.
Fail-open: ante cualquier problema deja el arbol original y sale en silencio
(log en /run/pocknix-island-off.log)."""
from __future__ import annotations

import json
import os
import shutil
import sys

BASE = "/run/msm-firmware-loader/hexagonrpc/sensors"
LOG = "/run/pocknix-island-off.log"


def log(msg: str) -> None:
    try:
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(msg + "\n")
    except OSError:
        pass


def _model() -> str:
    for path in ("/proc/device-tree/model", "/sys/class/dmi/id/product_name"):
        try:
            with open(path, "rb") as fh:
                text = fh.read().replace(b"\x00", b"").decode("utf-8", "replace").strip()
            if text:
                return text
        except OSError:
            continue
    return ""


def _island_off(node, depth: int = 0) -> bool:
    """Recorre el JSON entero y apaga cualquier enable_island que encuentre."""
    changed = False
    if isinstance(node, dict):
        en = node.get("enable_island")
        if isinstance(en, dict) and en.get("data") != "0":
            en["data"] = "0"
            changed = True
        for value in node.values():
            if depth < 12:
                changed |= _island_off(value, depth + 1)
    elif isinstance(node, list):
        for value in node:
            if depth < 12:
                changed |= _island_off(value, depth + 1)
    return changed


def patch_island(path: str) -> bool:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError) as exc:
        log(f"skip {path}: {exc}")
        return False
    if not _island_off(data):
        return False
    try:
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=4)
            fh.write("\n")
    except OSError as exc:
        log(f"write {path}: {exc}")
        return False
    log(f"island off -> {path}")
    return True


def copy_over_symlink(name: str) -> str | None:
    path = os.path.join(BASE, name)
    if not os.path.islink(path):
        return path if os.path.isdir(path) else None
    real = os.path.realpath(path)
    tmp = path + ".island-off"
    try:
        if os.path.exists(tmp):
            shutil.rmtree(tmp)
        shutil.copytree(real, tmp, symlinks=False)
        os.unlink(path)
        os.rename(tmp, path)
    except OSError as exc:
        log(f"copy {name}: {exc}")
        return None
    log(f"copiado {name} desde {real}")
    return path


def main() -> int:
    model = _model()
    if "odin 3" not in model.lower().replace("odin3", "odin 3"):
        return 0
    if not os.path.isdir(BASE):
        log("sin arbol hexagonfs; nada que hacer")
        return 0

    ok = False
    cfg = copy_over_symlink("config")
    if cfg:
        for name in os.listdir(cfg):
            if name.startswith("pakala") and name.endswith("_power_0.json"):
                ok |= patch_island(os.path.join(cfg, name))
    reg = copy_over_symlink("registry")
    if reg:
        for root, _dirs, files in os.walk(reg):
            for f in files:
                if f.endswith(".power.island"):
                    ok |= patch_island(os.path.join(root, f))
    log("hecho" if ok else "sin cambios")
    return 0


if __name__ == "__main__":
    sys.exit(main())
