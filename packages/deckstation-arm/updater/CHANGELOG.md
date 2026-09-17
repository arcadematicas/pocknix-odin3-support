# DeckStation Updater — Changelog

## [Unreleased] — 2026-08-10

### Fase 4 — Temas visuales
- **Temas visuales de WProton**: El updater usa ahora el mismo sistema de temas que WProton (`clasico | moderno | arcade`) con la misma paleta de colores, texto de selección, grises `dim` y radio de esquinas por tema. Se eligen desde `settings.conf` (`THEME=`) o con la variable `UPDATER_THEME`.
- **Menú de Apariencia**: Nueva opción en el HUB que muestra los 3 temas con muestra de colores, aplica el cambio al instante y lo guarda en `settings.conf`.

### Nota GoosEstation
- El core `goosestation-libretro` (PS1) **no** se compila desde el Updater: se suministra precompilado junto con el payload de la actualización de DeckStation (copia de `goosestation_libretro.so` + `.info` en `Apps/retroarch/RetroArch-Linux-x86_64.AppImage.home/.config/retroarch/cores/`).

## [Unreleased] — 2026-06-26

### Fase 1 — Seguridad en actualizaciones
- **Backup antes de actualizar**: El AppImage actual se renombra a `.bak` antes de descargar/extraer el nuevo. Si la operación falla, se restaura automáticamente desde el backup.
- **Limpieza de temporales al inicio**: Al arrancar, elimina cualquier `temp_update.archive`, `temp_update.AppImage` o `temp_extract_archive/` que haya quedado de ejecuciones anteriores.

### Fase 2 — Caché + indicador de actualizaciones
- **Caché de respuestas GitHub/Gitea**: Las respuestas de la API se guardan en `cache/releases_NOMBRE.json` con TTL de 30 minutos. Reduce drásticamente las llamadas a la API.
- **Escáner de actualizaciones en segundo plano**: Al entrar en "Actualizar Emuladores", se lanza un hilo que revisa todos los emuladores con 0.5s de pausa entre cada uno para evitar rate limiting.
- **Marcador visual**: Los emuladores con nueva versión disponible muestran un indicador `⬆` verde en el menú.
- **Barra de estado**: Muestra "Escaneando actualizaciones..." mientras el escáner trabaja.

### Fase 3 — Limpieza de código
- **Icon map a JSON**: Las ~100 entradas del mapeo de emuladores a iconos se movieron de código hardcodeado a `icons/map.json`. Si falta el archivo, se usan diccionarios vacíos (el sistema sigue funcionando).
- **git.txt como fuente principal de repositorios externos**: `EXTERNAL_REPOS` se construye leyendo `git.txt` primero. El diccionario hardcodeado (`EXTERNAL_REPOS_FALLBACK`) se usa solo como respaldo. Para añadir un emulador externo, solo hay que editar `git.txt`.
- **Corrección automática**: `shadps4` apuntaba a `shadps4-qtlauncher` (incorrecto); ahora usa el repo correcto `shadPS4` definido en `git.txt`.

### Mejoras en descargas
- **Timeout en stream de descarga**: Añadido `timeout=(10, 30)` a `requests.get(stream=True)`. Antes se colgaba para siempre si el servidor no respondía.
- **Reintentos con backoff**: 3 intentos automáticos (2s/4s/6s) si falla por `ConnectionError`, `Timeout` o `ChunkedEncodingError`.
- **Soporte de reanudación (Range header)**: En reintentos, envía `Range: bytes=X-`. Si el servidor responde 206 (Partial Content), reanuda. Si responde 200 (completo), reinicia la descarga desde cero (evitando corrupción por append).
- **Verificación de espacio en disco**: Antes de descargar, comprueba que haya al menos ~500MB libres. Si no, muestra error y no inicia la descarga.
- **Velocidad de descarga en tiempo real**: Muestra "Descargando: 45% (2.3 MB/s)" actualizado cada ~50 chunks.
- **Cancelar descarga (ESC/gamepad B)**: Durante la descarga, se puede pulsar ESC o B para cancelar. Limpia todos los archivos temporales y vuelve al menú de emuladores.
- **Mensaje de error si falta 7z**: Si `7z` no está instalado, muestra `❌ '7z' no instalado. Ejecuta: sudo pacman -S p7zip` en lugar del genérico "archivo corrupto".
- **Feedback en descargas de tamaño desconocido**: Muestra velocidad aunque el servidor no reporte `content-length`.
- **raise_for_status() movido antes de modificar estado**: No se modifica `write_mode` ni `downloaded` hasta confirmar que la respuesta HTTP es válida.

### Fixes de bugs
- **Range header fantasma**: Se definía `resume_headers` *después* de hacer la petición HTTP → nunca se enviaba.
- **Corrupción potencial en retry sin Range**: Si el servidor ignoraba `Range` y devolvía 200, el modo `'ab'` append duplicaba el archivo parcial + completo.
- **Sin timeout en request**: La descarga podía colgarse indefinidamente.
- **Estado mutable antes de validar HTTP**: `write_mode` y `downloaded` se modificaban antes de `raise_for_status()`.
