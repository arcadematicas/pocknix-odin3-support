# calvOS-doctor — informes de diagnóstico

Herramienta del sistema para que cualquiera pueda mandar un informe **útil** sin saber qué mirar,
sin exponer datos personales y sin llevar credenciales dentro de la imagen.

```sh
calvos-doctor                                  # recoge y guarda (NO envía nada)
calvos-doctor --text "no hay audio al enchufar" # añade una descripción
calvos-doctor --send --text "..."              # envía al colector (pide confirmación)
calvos-doctor --send --yes                     # sin preguntar (scripts)
```

## Qué hace exactamente

1. **Recoge**: modelo, kernel, versiones de los paquetes de calvOS (kernel, BSP, Decky, gamescope,
   mesa, turnip, steam), estado del panel (brillo, calibración, modos), audio (jack, sink por
   defecto, amplificadores `SPK_L/R`, compander, quantum, xruns), batería, unidades fallidas y los
   logs relevantes (`dmesg`, journal con prioridad warning, audio y GPU).
2. **Redacta**: `/home/<usuario>`, `/run/media/<usuario>`, hostname, nombre de usuario, MAC, IP,
   SSID y cualquier clave que suene a `serial`, `imei`, `uuid`, `token`, `password`, `secret` o `key`.
3. **Enseña** un resumen y guarda el bundle en `~/calvos-report-<fecha>.tar.gz`.
4. **Solo envía con `--send`** (y pregunta, salvo `--yes`), al colector
   `https://calvos-reports.calvos-reports.workers.dev/api/report`, que abre el issue en
   [`arcadematicas/calvOS-reports`](https://github.com/arcadematicas/calvOS-reports) y devuelve la
   URL. En la consola se pinta también un **QR** para abrirlo en el móvil (`qrencode`), porque en
   modo juego no hay navegador.

## Por qué así y no con un token dentro del sistema

El token de GitHub vive **solo** en el Worker (secret de Cloudflare). El cliente únicamente hace
`POST` de un JSON ya redactado y no puede leer informes. Ver el README de `calvOS-reports`.

## Integración en el panel (Decky)

El botón de informe del plugin *Panel de Control* se apunta a nuestro colector **sin tocar su
código**: su backend ya lee `PDC_REPORT_URL` del entorno y `pocknix-steam` la exporta. Así sigue
funcionando aunque el plugin se actualice.

## Ficheros

- `packages/pocknix-bsp-sm8750/doctor/calvos-doctor` → `/usr/local/bin/calvos-doctor`
- Colector: `github.com/arcadematicas/calvOS-reports` (`worker/src/index.js`)

## Integración en PocknixControl (26/10/2026)

Pestaña **Sistema** → sección **INFORME**: descripción opcional + botón **"Enviar informe"**.

- El backend (`py_modules/pocknix_control/report.py`) lanza `calvos-doctor --send --yes [--text ...]`
  y parsea la línea `issue: <url>`. **No** reimplementa la recogida, la redacción ni el envío: el
  script del BSP es la única fuente.
- `main.py`: `send_report(text)` (con `asyncio.to_thread`), `src/backend.ts`: `sendReport(text)`.
- Mismo colector que la CLI: Worker → issues en `arcadematicas/calvOS-reports`.
- El token de GitHub **nunca** viaja en la imagen: solo el secret del Worker.
