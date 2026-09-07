# InputPlumber — capability map AYN modificado

`ayn_mcu.yaml` se instala en `/usr/share/inputplumber/capability_maps/ayn_mcu.yaml`
(dispositivo "AYN Layout", combinado con el device `01-ayn-controller.yaml`).

## Cambio aplicado
El **paddle trasero derecho M2** (`BTN_C`) se re-mapeó de `gamepad: RightPaddle2`
a `keyboard: KeyF13`, para usarlo como **toggle de MangoHud** (ver
`config/mangohud/`). El paddle **M1** (`BTN_Z`) se mantiene como `LeftPaddle2`.

```yaml
- name: Right Paddle (MangoHud toggle F13)
  source_events:
    - evdev:
        event_type: KEY
        event_code: BTN_C
        value_type: button
  target_event:
    keyboard: KeyF13
```

## Notas
- Los paddles son un dispositivo GPIO separado (`gpio-keys-paddles`, BTN_Z/BTN_C)
  que InputPlumber **graba** (EVIOCGRAB) — no se pueden leer en crudo mientras
  InputPlumber los gestiona.
- El cambio aplica al **reiniciar InputPlumber** (o la consola).
- El dispositivo virtual de salida "InputPlumber Keyboard" es donde se emiten las
  teclas F13; el daemon de toggle lo escucha.
- Backup del original: `ayn_mcu.yaml.bak` en la misma carpeta.
