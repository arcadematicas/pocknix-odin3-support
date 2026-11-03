# OpenABL — evaluación para CalvOS / Odin 3

> Fuente: <https://github.com/OpenHandheldCollective/OpenABL> (GPL-3.0, ★62, 16 forks, v1.2 del 24/10/2026).
> Evaluado el 3/11/2026. **No se ha flasheado nada.**

## Qué es

El ABL de Qualcomm (el bootloader que ya lleva la consola) **parcheado** con un menú gráfico
y un cargador de Linux dentro del propio firmware. No sustituye a Linux ni es un gestor de
arranque en la partición: vive en la partición `abl`.

- **Soporta SM8750 y lista “AYN Odin 3” explícitamente** en su tabla de paneles
  (`Core/Panel.c`: `mOdin3Backlight` GPIO 56, `mOdin3Supplies` GPIO 97).
- Releases con `abl_signed-SM8750.elf` + `openabl-recovery-flashable-sm8750.zip` + instalador
  Android (`OpenABL-Android-Installer`, Kotlin) para ponerlo sin PC.
- Ajustes en los últimos 4 KiB de `misc`; el resto del arranque de Android no se toca
  (sigue arrancando con verified boot y recovery).

## Qué aporta

- **Menú de arranque** (Vol‑ para abrirlo, Vol+/Vol‑ para mover, Power para elegir) con:
  arrancar Linux/Android, **origen** (interna/SD/USB), entradas de arranque, recuperación,
  EDL, cambiar slot A/B, idioma, modo ABL silencioso/verbose, logo de arranque propio,
  **desinstalar CFW** de la interna, info del dispositivo y apagado.
- **Doble arranque real**: Android sigue intacto en sus particiones.
- **Arranque desde SD/USB** (cambia el puerto USB a host), y también de una **imagen de disco
  escrita en `userdata`**.
- Cuenta de arranques (Automatic Boot Assessment) y variables EFI si el kernel lleva el
  parche de QSEECOM.

## Cómo arranca Linux (importante para nosotros)

No usa boot.img de Android. Prueba, en este orden, en las unidades permitidas por el
“origen de arranque”:

1. Opciones `Boot####` (BootNext/BootOrder).
2. Por unidad: **BLS** (`\loader\entries\*.conf`) y **UKI** (`\EFI\Linux\*.efi`),
   luego **`\extlinux\extlinux.conf`**, luego **`\EFI\BOOT\BOOTAA64.EFI`** (GRUB/systemd-boot).
3. Arranca el kernel por su **EFI stub** (descomprime gzip), con initrd y el devicetree de la
   entrada o el “Device model” elegido (`.dtb` en `\boot\grub`, `\dtbs`, `\dtbs\qcom`,
   `\dtb`, `\dtb\qcom`).

Nuestro esquema actual es distinto: ABL carga `/flash/KERNEL` (boot image de Android con
`Image` gzip + dtbs + cmdline). Para usar OpenABL habría que **añadir un layout BLS/extlinux**
en la FAT (`/flash`), por ejemplo:

```ini
# /flash/extlinux/extlinux.conf   (o /flash/loader/entries/calvos.conf)
label calvos
  linux /calvos/Image
  devicetree /calvos/cq8725s-ayn-odin3.dtb
  append root=PARTLABEL=POCKNIX_ROOT rootwait loglevel=7 ... (el cmdline actual)
```

No hace falta initramfs (el kernel actual arranca con ramdisk vacío: los FS van built-in).
El `Image` arm64 ya lleva EFI stub. El `.dtb` lo generaríamos del árbol como ahora.

## Riesgos y frenos

1. **Flashear `abl_a`/`abl_b` es la operación más delicada del equipo**. Si falla: EDL o
   recovery. Antes de probar hay que tener a mano `openabl-recovery-flashable-sm8750.zip`
   y saber entrar en EDL. **No hacerlo en la Odin “de uso” sin plan de vuelta.**
2. Cambia el flujo de instalación: hoy `install.sh` escribe `/flash/KERNEL` y conserva el ABL.
   Con OpenABL el arranque de Linux pasa a `extlinux`/BLS y el actualizador tendría que
   generar también ese layout (o migrar).
3. El parche `Linux/0001-firmware-qcom-scm-allow-QSEECOM-on-OpenABL-s-platforms.patch` hace
   falta solo para que Linux vea las variables EFI (`bootctl`, boot counting). Sin él se
   arranca igual.
4. Si el “Device model” no acierta con el dtb, se puede quedar sin pantalla; hay que colocar
   el `.dtb` correcto en la unidad.
5. Es un proyecto joven (v1.2) con 6 issues abiertos: revisar antes de adoptarlo como default.

## Recomendación

**Interesante de verdad, pero para una sesión aparte y con red de seguridad.** Encaja muy
bien con lo que queremos (menú, doble arranque, SD/USB, desinstalar CFW), y la Odin 3 está
soportada por nombre. El trabajo real no es flashear: es **dar a CalvOS un layout
BLS/extlinux** y adaptar el instalador/actualizador, más validar el retorno por EDL.

Plan mínimo si se decide probar:

1. Preparar el recovery (zip flashable en la SD + procedimiento EDL documentado).
2. Flashear OpenABL en un equipo de pruebas (no en la consola de uso).
3. Añadir a la imagen `extlinux.conf` + `Image` + `dtb` en `/flash`, sin quitar `/flash/KERNEL`
   (así el ABL de AYN sigue funcionando si se vuelve atrás).
4. Probar: arranque Linux interna, SD, USB, Android, y “Uninstall CFW”.
5. Solo si todo va: plantearlo como opción de la imagen (flag en el instalador).

## Otros repos del colectivo

- `OpenHandheldCollective/linux`: árbol **mainline** (7.4-rc), sin parches de dispositivo.
  Útil solo como fuente si algún día subimos de kernel.
- `OpenABL-Android-Installer`: instalador desde Android; útil para usuarios, no para nosotros.
- `regmsg-binaries`: binarios atados a REG-Linux; no aplica.
