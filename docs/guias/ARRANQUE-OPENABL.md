# Arranque y menú de OpenABL

**Qué es**: el gestor de arranque de la consola. Desde la versión de noviembre de
2026 es **OpenABL 1.2**, que además de arrancar Linux añade un **menú** al
encender: elegir kernel, arrancar desde la tarjeta SD o un USB, entrar en
Android/recovery y llegar al modo de recuperación (EDL).

Detalle técnico: [`../OPENABL-MIGRACION.md`](../OPENABL-MIGRACION.md).

## Lo primero: no tienes que hacer nada

La actualización de paquetes deja la consola **preparada**, pero **no cambia el
gestor de arranque**: eso es a propósito, porque escribir el bootloader con la
consola encendida es la única operación que, si se corta la corriente, deja el
equipo sin arrancar.

- Si **no instalas** OpenABL: la consola arranca exactamente como siempre. Nada
  se rompe y no aparece ningún aviso insistente.
- Si lo instalas: ganas el menú. Se tarda un minuto y se hace una sola vez.

Todo lo demás (juegos, Steam, mandos, suspensión) es idéntico en los dos casos.

## Instalarlo (una vez, opcional)

Requisitos:

- **Enchufada a la corriente** o con más del **30 %** de batería. El instalador
  se niega si no.
- No la apagues ni la desenchufes mientras escribe (son unos segundos).

Pasos:

1. Abre **CalvOS Tools → Advanced → Bootloader → Install**.
   También vale, desde una terminal: `sudo pocknix-update-abl`.
2. El programa:
   - guarda una **copia de tu bootloader actual** (`/flash/openabl/abl_a.img` y
     `abl_b.img`);
   - escribe los **dos slots** y **verifica cada uno** antes de tocar el
     siguiente;
   - pide escribir `FLASH` para confirmar.
3. Apaga y **enciende manteniendo pulsado Volume −** para entrar en el menú.
4. En el menú (te mueves con Volume − / Volume +, seleccionas con Power):
   - **Device model**: tu modelo, **AYN Odin 3**.
   - **Boot mode**: **Linux**.
   - **Boot source**: **Internal** (o *Auto*, que prueba la memoria interna
     primero).
   - **Start**.

A partir de ahí, **arranca solo**: Volume − únicamente hace falta si quieres
abrir el menú a propósito.

## Qué puedes hacer en el menú

| Opción | Para qué |
|---|---|
| **Start** | Arrancar Linux con lo seleccionado |
| **Boot entries** | Elegir una entrada concreta (aparece si hay más de una) |
| **Restart bootloader** | Volver al menú |
| **Recovery mode** | Reiniciar en recovery de Android |
| **Emergency download mode** | Modo EDL de Qualcomm (recuperación desde PC) |
| **Boot other slot** | Arrancar desde el otro slot A/B |
| **Boot mode** | Linux o Android |
| **Boot source** | Auto / Internal / SD card / USB |
| **Device model** | Qué árbol de dispositivo (dtb) usa Linux |
| **Uninstall CFW** | Quitar una instalación de Linux de la memoria interna |

## Si algo sale mal

- **Pantalla negra después del logo**: casi siempre es que **no hay modelo
  elegido**. Apaga, enciende con **Volume −** y elige *Device model* → *AYN
  Odin 3* → *Start*.
- **Un kernel nuevo no arranca**: enciende con Volume − → *Boot entries* →
  **Pocknix (previous kernel)**. El kernel anterior se guarda como `Image.bak`
  en cada actualización.
- **Quieres volver al gestor anterior**: los backups de tu bootloader original
  están en `/flash/openabl/abl_a.img` y `abl_b.img`, y se copian solos a la
  tarjeta si hay una montada. Volver es escribir esas dos imágenes en los slots
  (`abl_a` / `abl_b`). No lo hagas sin leer
  [`../OPENABL-MIGRACION.md`](../OPENABL-MIGRACION.md) §5.

## Dónde está cada cosa

```
/flash/Image                      # kernel que arranca el menú
/flash/Image.bak                  # kernel anterior (entrada "previous kernel")
/flash/dtbs/*.dtb                 # modelos que ofrece el menú
/flash/loader/loader.conf         # entrada por defecto
/flash/loader/entries/pocknix.conf            # kernel actual
/flash/loader/entries/pocknix-previous.conf   # kernel anterior (si existe)
/flash/openabl/                   # kit de instalación + backups de los slots
/flash/rocknix_abl/               # kit anterior (reserva)
```

Los ficheros se actualizan **solos** al instalar un kernel nuevo
(`pocknix-bls-deploy`, hook de pacman). No hay que copiar nada a mano.
