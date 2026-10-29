# Consumo en suspensión — cómo medirlo

Herramienta permanente (paquete `pocknix-system-overlay`):

- **Hook**: `/usr/lib/systemd/system-sleep/zz-battery-sleep`. En cada `pre`/`post` de suspensión
  apunta a `/var/log/pocknix/sleep-battery.log`: epoch, fase, `cap`, `status`, `energy_now`,
  `power_now`. Rota a 256 KB.
- **Informe**: `pocknix-sleep-report [-n N]`. Saca una línea por ciclo con duración, batería antes y
  después, delta y **%/h**, y clasifica: `ok` (≤0,60), `ALTO` (≤1,20), `FUGA` (>1,20), `cargando`
  (los ciclos con cargador no cuentan).

## Uso

```bash
pocknix-sleep-report          # todos los ciclos
pocknix-sleep-report -n 5     # los 5 últimos
```

Salida de ejemplo:

```
DORMIDA          DESPIERTA        DURACION        BATERIA    DELTA    CONSUMO  ESTADO
28/10 14:02      28/10 23:02         9h00m   76.0% ->  72.0%    -4.0%   0.44 %/h  ok
29/10 10:02      29/10 18:02         8h00m   90.0% ->  78.0%   -12.0%   1.50 %/h  FUGA
```

## Referencia medida

| Kernel | Suspensión | Consumo |
|---|---|---|
| 7.2.12-18 (sin SoCCP) | 28/10 22:10 → 29/10 07:09 (9 h) | **0,44 %/h** (76 % → 72 %) |

Con el kernel 22 (SoCCP + D3) se espera por debajo de eso. La comparación se hace con la misma
batería, sin cargador y con una duración parecida.

## Notas

- `energy_now` sale 0 en la Odin (el `battmgr` no lo expone); el cálculo va con `capacity`, que sí
  es fiable. `power_now` sí funciona (≈4,2 W con pantalla encendida en reposo).
- El hook no toca nada: solo escribe una línea. Si algo fallara, el fichero se puede borrar sin más.
- Los ciclos con `status=Charging` se marcan y se excluyen de la media.
