# Xbox en la Odin: hakuX-lr y el XISO (2026-11-06)

## Qué sabemos

- El **xemu standalone** abre el XISO sin problemas: el volcado del juego es válido.
- Con **hakuX** (core libretro nuevo) el mismo juego **no abre**.
- La entrada **"Xemu (Squashfs)"** de ES-DE da un error de squashfs. No es un problema del
  juego: ese comando es un lanzador pensado **solo para ROMs `.squashfs`**
  (`./ROMs/xbox/unsquashfs.sh %ROMRAW%`), así que al pasarle un `.xiso`/`.iso` falla al
  descomprimir. No sirve para XISO.

## Qué soporta hakuX-lr

- XISO `.iso` (imagen de DVD Xbox), dumps Redump `.iso` y **CHD de DVD** (`chdman createdvd`).
- Requiere **Vulkan** (1.3 recomendado) y que RetroArch use el driver de vídeo Vulkan
  (la entrada de ES-DE pasa `--vulkan`).
- Requisitos de runtime: **glibc 2.38+** y **libstdc++ de GCC 13+**.
- **Sin savestates** (tampoco rewind ni run-ahead).
- No necesita BIOS, MCPX ROM ni imagen de HDD: crea su almacenamiento (`hdd/`, `cache/`)
  en el save dir de RetroArch.

## Antecedentes

- **5/11:** sale **hakuX 0.19.2** con fixes de memoria y de crashes respecto a 0.19.1.

## Hipótesis (por orden de probabilidad)

1. **Extensión `.xiso`**: el core puede no reconocer `.xiso` aunque sí `.iso`. Probar una
   copia renombrada a `.iso`.
2. **Driver Vulkan real en RetroArch**: si RetroArch cae a otro driver (o el ICD de Adreno no
   está activo), hakuX no arranca. Confirmar con `vulkaninfo` y con el log de RetroArch.
3. **Bug del core 0.19.1**: los fixes de 0.19.2 (memoria/crashes) pueden resolver el fallo.
4. **Formato del dump**: aunque xemu lo abra, podría ser un XISO con particularidades
   (padding, split, etc.) que hakuX no maneje.

## Pasos de prueba

1. Instalar **hakuX 0.19.2** (paquete `libretro-hakux` actualizado).
2. Ejecutar el diagnóstico y guardar la salida:

   ```sh
   sh tools/xbox-diag.sh "/ruta/juego.xiso" > /tmp/xbox-diag.txt 2>&1
   ```

3. Copiar el juego a `.iso` y lanzarlo con la entrada **hakuX (Vulkan)** de ES-DE.
4. Si sigue fallando, lanzar RetroArch a mano con log verbose y adjuntarlo:

   ```sh
   retroarch -v -L /usr/lib/libretro/hakux_libretro.so "/ruta/juego.iso"
   ```

5. Revisar `es_log.txt` (ES-DE) y `retroarch.log` (el script ya muestra la cola de ambos).
6. Confirmar de nuevo con el **xemu standalone** que el volcado sigue abriendo.

## Cambios de hoy

- `packages/libretro-hakux/PKGBUILD`: hakuX **0.19.1 → 0.19.2** (nuevo commit y sha256).
- `packages/deckstation-arm/configs/es-de/custom_systems/es_systems.xml`: la entrada
  "Xemu (Squashfs)" pasa a llamarse **"Xemu (ROM .squashfs)"** para dejar claro que solo
  sirve para ROMs `.squashfs` (no para XISO).
- `packages/deckstation-arm/PKGBUILD`: `pkgrel` 18 → 19 (republicar el paquete con el XML).
- Nuevo `tools/xbox-diag.sh`: recogida de estado **solo lectura** (cores, `.info`, Vulkan,
  bloque xbox de ES-DE, logs y magia XDVDFS de la ROM).

## Confirmado en la Odin (6/11, prueba en vivo)

El fallo de hakuX **no era el core ni el XISO**: el comando de ES-DE pasaba
`--vulkan`, y el RetroArch de DeckStation **no reconoce ese flag**:

```
/opt/deckstation/Apps/RetroArch/retroarch: unrecognized option '--vulkan'
```

RetroArch abortaba antes de cargar el core (`exit=1`). El driver ya está en
`video_driver = "vulkan"` en el `retroarch.cfg` portable, así que el flag sobra.

- **Arreglo**: quitado `--vulkan` del comando `hakuX (Vulkan)` en `es_systems.xml`.
- **Probado sin el flag** (hakuX 0.19.2, Otogi PAL, 60 s): arranca y juega
  (~14-18 fps en la prueba; kernel de Xbox vivo, 1.600 frames, sin errores).
- La entrada "Xemu (Squashfs)" sigue siendo solo para ROMs `.squashfs`; con un
  `.iso` da el error de squashfs (esperado). Renombrada a "Xemu (ROM .squashfs)".
- El HDR de gamescope siguió en 0 tras la prueba: RetroArch no lo enciende; el
  drift de HDR era Steam al arrancar/resumir (ver `HDR-RESUME-20261106.md`).
