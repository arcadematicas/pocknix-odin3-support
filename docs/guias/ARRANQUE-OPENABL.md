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

1. Abre **CalvOS Tools** y elige la entrada **«Bootloader: install or update to
   OpenABL 1.2…»** (es una lista plana: no hay submenú *Advanced*).
   También vale, desde una terminal: `sudo pocknix-update-abl`.
   Si solo quieres mirar cómo está: `sudo pocknix-update-abl --status`.
2. El programa:
   - guarda una **copia de tu bootloader actual** (`/flash/openabl/abl_a.img` y
     `abl_b.img`) — **nunca sobrescribe una copia que ya exista**, porque en una
     consola de fábrica esa copia es el ABL **original** y es el único camino de
     vuelta;
   - si hay una SD o un USB montado, copia ahí los dos `.img`
     (`pocknix-abl-backup/`): la copia de `/flash` desaparece al desinstalar;
   - escribe los **dos slots** y **verifica cada uno** antes de tocar el
     siguiente;
   - pide escribir `FLASH` para confirmar (existe `-y`, pero entonces no
     confirma nada: úsalo solo en un script).
3. Apaga y **enciende manteniendo pulsado Volume −** para entrar en el menú.
4. En el menú (te mueves con Volume − / Volume +, seleccionas con Power):
   - **Device model**: tu modelo, **AYN Odin 3** (sale de los `.dtb`; en la
     *Portal* aparece como **AYN Odin 3 Portal**).
   - **Boot mode**: **Linux**.
   - **Boot source**: **Internal** (o *Auto*, que prueba la memoria interna
     primero).
   - **Start**.

A partir de ahí, **arranca solo**: Volume − únicamente hace falta si quieres
abrir el menú a propósito.

## Comprobar que quedó bien

```bash
# 1. El ABL que está en marcha (vacío si todavía es el de fábrica/ROCKNIX)
sudo pocknix-update-abl --status
#    esperado tras instalar:  state=uptodate  kit=openabl  running_openabl=1.2  needs_openabl=0

# 2. La versión que declara el firmware: 65538 = 1.2
cat /sys/firmware/efi/esrt/entries/entry0/fw_version

# 3. Que Linux lo cargó la entrada BLS y no /KERNEL
head -c 60 /proc/cmdline     # debe empezar por root=PARTUUID=…
```

Estados que puede devolver `--status` en `state=`: `uptodate` (los dos slots son
el kit), `differs` (los dos iguales pero no son el kit: ABL de fábrica, ROCKNIX u
otro OpenABL), `mixed` (los slots no coinciden), `nopart` (no ve los slots: hace
falta root), `nokit` (no hay kit instalado) y `gptrepair` (tabla de particiones
dañada; el instalador la repara **solo** reescribiendo la cabecera de respaldo,
sin tocar contenido).


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

## Consola nueva o recién reparada

- Si la consola viene **con Android de serie y sin root** (no hay `su`), el kit no puede
  escribir los slots desde Android: se usa **fastboot en el slot inactivo** — procedimiento
  completo en [`../OPENABL-FASTBOOT-SIN-ROOT.md`](../OPENABL-FASTBOOT-SIN-ROOT.md).
- En una consola de fábrica el `state=` inicial es `differs`: los dos slots son
  iguales entre sí, pero **no** son el kit. Ese contenido es el ABL original (o
  el de Android) y el instalador lo respalda **antes** de escribir.
- **No sobrescribas ese backup** y cópialo fuera de la consola:

  ```bash
  scp deck@<ip-de-la-consola>:/flash/openabl/abl_{a,b}.img .
  ```

  Al desinstalar CalvOS se borra la partición donde viven, y son el único camino
  de vuelta al bootloader original.
- La primera vez que arranca OpenABL **hay que elegir Device model una vez**. Si
  no, la pantalla se queda negra después del logo (no está roto: no sabe qué
  árbol de dispositivo cargar).
- En la **Odin 3 Portal** el kit es el mismo (el ELF es por SoC, SM8750) y el
  modelo aparece en el menú como **AYN Odin 3 Portal**, tomado de su `.dtb`. El
  panel es distinto (`vtdr6130,o3p`), pero eso lo resuelve el kernel, no el menú.

## Para grabarlo en vídeo (5 tomas)

1. `sudo pocknix-update-abl --status` en una terminal — el "antes".
2. CalvOS Tools → la entrada del bootloader → el diálogo de aviso.
3. La terminal pidiendo `FLASH` y el `writing abl_a (…) … verified 0dba7b9`.
4. Apagar y encender con **Volume −**: el menú, *Device model*, *Boot mode:
   Linux*, *Boot source: Internal*, *Start*.
5. Ya en Linux: `--status` (`state=uptodate`) y
   `cat /sys/firmware/efi/esrt/entries/entry0/fw_version` → `65538`.

Para el plano: batería por encima del 50 % y el cable enchufado a la vista. No
hay que cortar ni montar nada entre el paso 3 y el 4: son seguidos y el corte de
corriente es lo único que puede estropearlo.

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
