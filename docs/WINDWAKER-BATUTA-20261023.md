# Wind Waker HD (port nativo): la batuta no registraba arriba/derecha

## Síntoma
Con el stick derecho, la **batuta** (dirigir la Wind Waker) solo registraba **abajo** e
**izquierda**. Arriba y derecha no hacían nada.

## Lo que NO era
- **No era el mando**: en el test del propio juego (Ajustes → Gamepad) el stick cubría bien las
  cuatro direcciones, y en Steam el dispositivo responde. El `ABS_RX/RY` del pad físico (escala
  ‑1024..1024) está correcto.
- **No era el kernel ni InputPlumber**: el mando se entrega por el pad virtual "X-Box 360" sin
  recortes.

## Causa
El port aplica una **zona muerta del 15 %** y un `right_stick_range` de **1.0**. El juego exige
casi deflexión completa para leer la dirección de la batuta; con esa combinación, los dos sentidos
"cortos" del stick no llegaban al umbral.

## Arreglo (config del port, no del sistema)
En `<juego>/.home/.config/wwhd/controls.json`, bloque `options`:

```json
"stick_deadzone": 0.08,
"right_stick_range": 1.35
```

- `stick_deadzone`: 0.15 → **0.08** (menos zona muerta).
- `right_stick_range`: 1.0 → **1.35** (escala tras la zona muerta: "un stick corto llega a fondo").
- Efecto lateral: la **cámara** también se vuelve un ~35 % más sensible; si molesta, bajar a 1.2
  (la batuta suele seguir funcionando).
- Copia de seguridad: `controls.json.bak-batuta`.

## Si se reinstala el port
El ajuste vive en el `HOME` portable del AppImage
(`WindWakerHD-linux-aarch64.AppImage.home/.config/wwhd/controls.json`), así que se conserva mientras
no se borre esa carpeta. Si se empieza de cero, hay que volver a poner esos dos valores.
