# Pruebas — Mesa/Turnip de Valve **0.5.x** (`gite07916b4`) vs la nuestra (09-oct-2026)

## Método
- **Juego**: Dead Island (appid 91310), vía Proton ARM64.
- **Selección por juego**: PocknixControl → pestaña *Games* → Dead Island → *Use Per-Game Settings* → **Mesa Version**
  (`default` = nuestra Turnip / `26.3.0-valve` = la de Valve 0.5.x).
- **Fijado para todas las pasadas**: TDP **nivel 7** (modo Estable, auto-TDP OFF) + perfil **Balanced**, VSync off,
  misma resolución, **mismo guardado y mismo recorrido**.
- **Medición**: log del **mangoapp** (MangoHud) → `/home/deck/mangologs/mangoapp_*.csv`, y se cortan los tramos por
  tiempo (columna `elapsed`, en ns). Alternando A/B y descartando el 10 % inicial (lo hace `tools/mesa-bench-compare.py`).

## Resultado (A1 vs B1, tramos limpios)

| Variante | FPS medio | 1 % low | 0,1 % low | ft medio | stutter | ΔFPS | Δ1%low |
|---|---|---|---|---|---|---|---|
| **default** | 62,57 | 29,95 | 11,19 | 16,46 ms | **22** | — | — |
| **valve-0.5.x** | 62,87 | **39,33** | **29,88** | 16,24 ms | **3** | **+0,5 %** | **+31,3 %** |

## Veredicto
- **FPS medio: EMPATE** (+0,5 %) → la Turnip de Valve **no rinde más rápido de media**.
- Pero **1 % low +31 %** y **tirones 22 → 3** → va **mucho más suave** (menos stutter) → mejor para jugar.
- El payload `26.3.0-valve` (`pocknix-vk-valve`) ya es la **0.5.x** (`gite07916b4`). Se queda como **opción per-game**
  (la Mesa del sistema sigue siendo la nuestra); publicado en `[pocknix-shared]`.

> Nota: una primera pasada rápida (sin cortar bien la transición) dio −3,2 %: era artefacto de la carga/menús. Con
> tramos limpios (arriba) el resultado es empate en media + clara mejora en suavidad.
