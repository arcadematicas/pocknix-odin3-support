# Actualizar la Odin 3 con seguridad — guía para Davidusky (y su IA "Jarvis")

> **Contexto / por qué existe esta guía.** El repo de Pocknix que traían las imágenes apuntaba a
> `pocknix.shuuri.net` (de OTRO) y la parte del SoC **sm8750 NO existe** ahí (da 404). Al actualizar,
> `pacman` caía a `[alarm]`/`[aur]` y **mezclaba versiones** ("chimera") → la consola dejaba de arrancar.
> Ya **no** es así: publicamos nuestro repo **propio y firmado** en Cloudflare R2. Esta guía repunta tu
> Odin a él y actualiza con seguridad. **La AVISO de "no actualizar" queda LEVANTADA.**

---

## Resumen del arreglo (qué cambió)
- **Repo propio**: `https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev` → subrutas `/sm8750`, `/shared`, `/base`.
- **Clave GPG del repo**: `85C433EE12621EED` (`pocknix-repo@arcadematicas`).
- Se **elimina `[aur]`** (era el veneno) y la base queda **pinneada**: `[pocknix-base]` = snapshot ALARM
  `20260826.2` (no la ALARM viva).
- **Verificado en una Odin real**: actualizó de 7.2.4 → 7.2.9 **sin** "signature invalid", **sin** mezclar
  con ALARM y **sin** errores de módulos (BTF). El kernel 7.2.6/7.2.9 funciona bien: el fallo histórico era
  la **mezcla de paquetes**, no el kernel.

## Requisitos
- Odin 3 con la imagen de Pocknix (nuestra).
- Conexión a internet en la consola (WiFi).
- Una terminal: por **SSH** (`ssh deck@<IP_de_tu_Odin>`, contraseña por defecto `pocknix`) o en la propia
  consola con **Ctrl+Alt+F2**.

---

## PASO 0 — Copia de seguridad (hazlo SIEMPRE)
```bash
sudo cp -a /flash/KERNEL     /flash/KERNEL.bak-$(date +%Y%m%d)
sudo cp -a /flash/KERNEL.md5 /flash/KERNEL.md5.bak-$(date +%Y%m%d)
# snapshot btrfs (si no se crea solo):
sudo pocknix-snapshots 2>/dev/null || true
```

## PASO 1 — Apuntar al repo nuevo (R2)
```bash
sudo cp -a /etc/pacman.conf /etc/pacman.conf.bak-$(date +%Y%m%d-%H%M%S)

sudo tee /etc/pacman.conf >/dev/null <<'CONF'
[options]
Architecture = aarch64
HoldPkg     = pacman glibc
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional
ParallelDownloads = 5

[pocknix]
SigLevel = Required DatabaseOptional
Server = https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev/sm8750

[pocknix-shared]
SigLevel = Required DatabaseOptional
Server = https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev/shared

[pocknix-base]
SigLevel = Required DatabaseOptional
Server = https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev/base

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[alarm]
Include = /etc/pacman.d/mirrorlist
CONF
```
> ⚠️ Fíjate: **NO hay `[aur]`**. Los `[core]/[extra]/[alarm]` de ALARM solo sirven de comodín para instalar
> paquetes nuevos; lo instalado se resuelve por `[pocknix-base]` (pinneado).

## PASO 2 — Importar la clave del repo
```bash
curl -fsSL https://pub-fd47305874674bf597b27eb7f880e73b.r2.dev/sm8750/pocknix-repo.gpg -o /tmp/pocknix-repo.gpg
sudo pacman-key --add /tmp/pocknix-repo.gpg
sudo pacman-key --lsign-key 85C433EE12621EED
```

## PASO 3 — Refrescar y VERIFICAR (aquí se ve si va bien)
```bash
sudo pacman -Syy
# Debe descargar: pocknix, pocknix-shared, pocknix-base, core, extra, alarm
#   -> y NO debe aparecer "signature invalid" ni errores.

# Comprobación de aciertos (deben salir del repo "pocknix", NO de "extra"):
sudo pacman -Sp --print-format '%n %v %r' mesa gamescope linux-pocknix-sm8750
```

## PASO 4 — Actualizar
```bash
# Recomendado: el actualizador propio (aplica solo la política de --overwrite de ficheros huérfanos):
sudo pocknix-update

# Alternativa manual, con la política de --overwrite ACOTADA:
sudo pacman -Syu \
  --overwrite '/usr/lib/libplutovg.so*'      --overwrite '/usr/lib/libplutosvg.so*' \
  --overwrite '/usr/lib/libFLAC.so.8*'       --overwrite '/usr/lib/libpcap.so.0.8*' \
  --overwrite '/usr/lib/libdisplay-info.so.1*' --overwrite '/usr/share/pocknix/vk-arm/*'
```
> Si `pacman` nombra OTROS ficheros en conflicto ("existe en el sistema de archivos"), son huérfanos
> escritos a mano: reintenta **una** vez añadiendo `--overwrite '<ruta-exacta>'` **solo** para esas rutas.
> **NUNCA `--overwrite '*'`.**

## PASO 5 — Reiniciar y verificar
```bash
sudo systemctl reboot
# cuando vuelva:
uname -r                                   # -> 7.2.9
sudo systemctl --failed                    # -> 0 unidades fallidas
ip -br addr show | grep wlan               # -> WiFi UP
```
> El paquete del kernel reconstruye `/flash/KERNEL` + `KERNEL.md5` solo (deja `KERNEL.bak`). No hay que
> tocar el arranque a mano.

---

## Si algo va mal (vuelta atrás)
- **Kernel**: restaurar el backup → `sudo cp -a /flash/KERNEL.bak-<fecha> /flash/KERNEL` + regenerar
  `KERNEL.md5` (el ABL valida el md5).
- **Sistema**: `sudo pocknix-rollback` (restaura el snapshot btrfs) o desde el menú de arranque.

## NOTAS PARA JARVIS (la IA de Davidusky)
1. **Objetivo**: que `pacman -Syu` **no mezcle** con ALARM. Por eso `[pocknix-base]` (snapshot) va ANTES de
   `[core]/[extra]/[alarm]`, y `[aur]` desaparece.
2. **Verificación dura** (criterio de éxito): (a) `pacman -Syy` sin "signature invalid"; (b)
   `pacman -Sp mesa gamescope linux-pocknix-sm8750` → repo `pocknix`; (c) tras `-Syu`, `pacman -Qu` ≈ 0.
3. **Nunca `pacman -Sy` solo** (actualización parcial) → rompe el sistema. Siempre `-Syu` o `pocknix-update`.
4. Tras actualizar, `uname -r` debe ser **7.2.9** y `/flash/KERNEL.md5` debe cuadrar con `/flash/KERNEL`.
5. **Datos del usuario** que NUNCA se tocan con esto: `/home/deck`, `/opt/deckstation` (ROMs/saves/bios).
   Si algo de esto aparece en un conflicto, **párate**: no es un huérfano normal.
6. Referencias internas: `docs/REPO-R2-CAUSA-RAIZ-2026-10-09.md` (causa raíz + repo) y
   `docs/ACTUALIZADOR-QAM-2026-10-05.md` (el actualizador del QAM y la política de `--overwrite`).
