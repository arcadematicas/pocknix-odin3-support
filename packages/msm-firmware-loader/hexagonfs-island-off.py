#!/usr/bin/python3
"""Apaga el modo "island" del SSC en el AYN Odin 3 (pakala).

Con la isla activada, un s2idle entrado justo despues de cerrar un sensor cuelga el SoC
(armada-os/armada 623e96d3). El config y el registro de sensores viven en particiones de
solo lectura y msm-firmware-loader los ENLAZA; aqui se copian a /run, se pone
enable_island=0 y se deja el enlace apuntando a la copia.

Fail-open: ante cualquier problema deja el arbol original y sale en silencio (log en
/run/pocknix-island-off.log)."""
from __future__ import annotations

import json
import os
import shutil
import sys

BASE = "/run/msm-firmware-loader/hexagonrpc/sensors"
LOG = "/run/pocknix-island-off.log"
TARGETS = ("pakala_power_0.json",)


def log(msg: str) -> None:
    try:
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(msg + "\n")
    except OSError:
        pass


def patch_island(path: str) -> bool:
    """Pone enable_island.data a "0" conservando el resto del JSON."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError) as exc:
        log(f"skip {path}: {exc}")
        return False

    changed = False
    for node in (data, data.get(".island") or {}, data.get("power.island") or {}):
        if not isinstance(node, dict):
            continue
        en = node.get("enable_island")
        if isinstance(en, dict) and en.get("data") != "0":
            en["data"] = "0"
            changed = True
    if not changed:
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
    model = ""
    try:
        with open("/sys/class/dmi/id/product_name", "r", encoding="utf-8") as fh:
            model = fh.read().strip()
    except OSError:
        pass
    if "odin 3" not in model.lower().replace("odin3", "odin 3"):
        return 0
    if not os.path.isdir(BASE):
        log("sin arbol hexagonfs; nada que hacer")
        return 0

    ok = False
    cfg = copy_over_symlink("config")
    if cfg:
        for name in TARGETS:
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
