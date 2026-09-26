#!/usr/bin/env python3
"""mesa-bench-compare.py — compara logs de MangoHUD entre dos o más Mesas y dice cuál rinde más.

Sin dependencias externas (solo stdlib). Pensado para el A/B de
  - nuestra Mesa estable / una build de Turnip  vs  la Mesa de Valve (26.3.0-devel)
con los CSV que deja MangoHUD (una fila por frame, con cabecera).

Uso:
    tools/mesa-bench-compare.py nuestro-26.2.3:/home/deck/mangologs/a.csv \\
                                 valve-26.3:/home/deck/mangologs/b.csv

Cada argumento es `nombre:ruta.csv`. El PRIMER archivo es la referencia: el resto se
compara contra él.

Qué calcula (por CSV):
    - descarta el 10 % inicial de frames (calentamiento: compilacion de shaders, paginas
      a disco, primer frame largo)
    - FPS medio
    - 1 % low   = media del 1 % de frames MÁS LENTOS (la definición de CapFrameX/PresentMon)
    - 0,1 % low = ídem con el 0,1 %
    - frametime medio y desviación típica (std. muestral)
    - stutter = nº de frames con frametime > 2x la mediana

La columna de frametime se autodetecta ('frametime', tambien 'frame_time'/'framems'); si no
está, se calcula desde 'fps' (frametime = 1000 / fps). Las filas con fps <= 0 o no numericas
se ignoran (MangoHUD las pone cuando el juego se congela o al cerrar).
"""

import csv
import os
import statistics
import sys

WARMUP = 0.10          # fraccion inicial descartada
STUTTER_FACTOR = 2.0   # frametime > 2x mediana
TIE_PCT = 1.0          # ±1 % en FPS medio = EMPATE


# --------------------------------------------------------------------------- lectura del CSV
def _norm(name):
    return name.strip().lower().replace("_", "").replace(" ", "")


def _find_col(header, wanted):
    """Indice de la primera columna cuyo nombre normalizado empieza por `wanted`."""
    for i, h in enumerate(header):
        if _norm(h).startswith(wanted):
            return i
    return None


def load_frames(path):
    """Lee el CSV de MangoHUD -> (filas, de_donde_salio_el_frametime, num_filas_totales)."""
    rows = []
    header = None
    ft_idx = fps_idx = None
    ft_src = "columna frametime del CSV"
    with open(path, newline="", encoding="utf-8-sig", errors="replace") as fh:
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            row = next(csv.reader([line]), [])
            low = [_norm(c) for c in row]
            if header is None:
                # MangoHUD a veces antepone una linea de texto: la cabecera es la que trae "fps"
                if not any(c.startswith("fps") or c.startswith("frametime") for c in low):
                    continue
                header = row
                fps_idx = _find_col(header, "fps")
                ft_idx = _find_col(header, "frametime") or _find_col(header, "framems")
                if ft_idx is None and fps_idx is None:
                    raise ValueError("el CSV no tiene ni columna 'fps' ni 'frametime'")
                if ft_idx is None:
                    ft_src = "columna fps del CSV (frametime = 1000/fps)"
                continue
            idxs = [i for i in (ft_idx, fps_idx) if i is not None]
            if not idxs or len(row) <= max(idxs):
                continue
            try:
                fps = float(row[fps_idx]) if fps_idx is not None else None
                ft = float(row[ft_idx]) if ft_idx is not None else None
            except (TypeError, ValueError):
                continue
            if fps is not None and fps <= 0.0:
                continue          # frame sin presentar (pausa del driver / cierre del juego)
            if ft is not None and ft <= 0.0:
                continue
            if ft is None:
                if fps is None or fps <= 0.0:
                    continue
                ft = 1000.0 / fps
            rows.append((ft, fps if fps is not None else 1000.0 / ft))
    if header is None:
        raise ValueError("no se encontro la cabecera (linea con 'fps' o 'frametime')")
    if not rows:
        raise ValueError("el CSV no tiene filas de frame utilizables")
    return rows, ft_src, len(rows)


# --------------------------------------------------------------------------- metricas
def percent_low(frametimes, pct):
    """'pct low' = media del pct% de frames MÁS LENTOS (ordenados por frametime)."""
    n = max(1, int(round(len(frametimes) * pct / 100.0)))
    return statistics.fmean(sorted(frametimes, reverse=True)[:n])


def stats_for(path):
    rows, ft_src, total = load_frames(path)
    cut = int(len(rows) * WARMUP)
    warm = rows[cut:] or rows            # si el log es muy corto, no nos quedamos sin datos
    fts = [ft for ft, _ in warm]
    med = statistics.median(fts)
    return {
        "path": path,
        "ft_src": ft_src,
        "total": total,
        "usados": len(fts),
        "fps": statistics.fmean(f for _, f in warm),
        "low1": 1000.0 / percent_low(fts, 1.0),
        "low01": 1000.0 / percent_low(fts, 0.1),
        "ft": statistics.fmean(fts),
        "std": statistics.stdev(fts) if len(fts) > 1 else 0.0,
        "stutter": sum(1 for ft in fts if ft > STUTTER_FACTOR * med),
        "med": med,
    }


# --------------------------------------------------------------------------- presentacion
def _pct(new, ref):
    if ref <= 0:
        return float("nan")
    return (new - ref) / ref * 100.0


def _verdict(delta):
    if delta != delta:            # NaN
        return "?"
    if delta > TIE_PCT:
        return "MEJOR"
    if delta < -TIE_PCT:
        return "PEOR"
    return "EMPATE"


def _columns(r, ref):
    """(etiqueta, ancho, celda) de la tabla, ya formateados."""
    d_fps = _pct(r["fps"], ref["fps"])
    d_low = _pct(r["low1"], ref["low1"])
    return [
        ("FPS medio", 9, "{:9.2f}".format(r["fps"])),
        ("1% low", 8, "{:8.2f}".format(r["low1"])),
        ("0,1% low", 8, "{:8.2f}".format(r["low01"])),
        ("ft medio", 10, "{:9.2f}ms".format(r["ft"])),
        ("desv. ft", 10, "{:9.2f}ms".format(r["std"])),
        ("stutter", 8, "{:8d}".format(r["stutter"])),
        ("frames", 7, "{:7d}".format(r["usados"])),
        ("dFPS", 9, "{:+8.1f}%".format(d_fps)),
        ("d1%low", 9, "{:+8.1f}%".format(d_low)),
    ]


def print_table(rows, ref):
    name_w = max(len("opcion"), max(len(r["name"]) for r in rows))
    head = _columns(rows[0], rows[0])   # para los anchos de las cabeceras
    print("opcion".ljust(name_w) + "".join(c[0].rjust(c[1] + 2) for c in head))
    print("-" * name_w + "  " + "  ".join("-" * c[1] for c in head))
    for r in rows:
        print(r["name"].ljust(name_w) + "".join(c[2].rjust(c[1] + 2) for c in _columns(r, ref)))
    print()
    print("  1% low / 0,1% low = media de los frames MÁS lentos (definición CapFrameX).")
    print("  stutter = nº de frames con frametime > 2x la mediana.")
    print("  dFPS / d1%low = variación frente a la REFERENCIA (primer argumento).")
    print("  ±1 % en FPS medio = EMPATE.")
    print()
    for r in rows:
        delta = _pct(r["fps"], ref["fps"])
        print("  {:<20} {:>7.2f} fps  ->  {}".format(
            r["name"], r["fps"], "REFERENCIA" if r is ref else _verdict(delta)))
    print()
    for r in rows:
        print("  {}: frametime de la {}  (se usan {}/{} frames del CSV, se descartan los "
              "primeros {} %)".format(r["name"], r["ft_src"], r["usados"], r["total"],
                                        int(WARMUP * 100)))


# --------------------------------------------------------------------------- main
def parse_arg(arg):
    if ":" not in arg:
        raise ValueError("cada argumento debe ser nombre:ruta.csv -> {}".format(arg))
    name, path = arg.split(":", 1)
    name, path = name.strip(), path.strip()
    if not name or not path:
        raise ValueError("cada argumento debe ser nombre:ruta.csv (no van vacios)")
    return name, os.path.expanduser(path)


def main(argv):
    args = argv[1:]
    if len(args) < 2:
        print(__doc__.strip(), file=sys.stderr)
        print("\nerror: hacen falta 2 o mas argumentos nombre:ruta.csv", file=sys.stderr)
        return 2
    rows = []
    for a in args:
        try:
            name, path = parse_arg(a)
        except ValueError as exc:
            print("error: {}".format(exc), file=sys.stderr)
            return 2
        if not os.path.isfile(path):
            print("error: no existe el CSV de '{}': {}".format(name, path), file=sys.stderr)
            return 2
        try:
            s = stats_for(path)
        except (OSError, ValueError) as exc:
            print("error leyendo {} ({}): {}".format(name, path, exc), file=sys.stderr)
            return 1
        s["name"] = name
        rows.append(s)
    print_table(rows, rows[0])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
