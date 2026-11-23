# Samba: el invitado no podia crear ni borrar (23/11/2026)

## Sintoma
Desde el PC, por SMB: se podia **leer** todo, pero **crear o borrar** carpetas y ficheros daba
`STATUS_ACCESS_DENIED`. Fransis: "esto siempre ha funcionado bien".

## Diagnostico
- `smbstatus` mostraba sesiones como usuario `deck`, pero `pdbedit -L` estaba **vacio**: no habia
  ninguna cuenta Samba.
- El propio `pocknix-share` lo documenta:

  > Guest-only, but deck must EXIST in passdb or every write is refused at smb2_create: the
  > guest token keeps the Guest SID and the synthesised ACL grants write to the owner SID only.

  Es decir: el invitado conserva el **SID Guest**, y la ACL que sintetiza Samba solo concede
  escritura al **SID propietario**. Sin una entrada de `deck` en passdb, `smb2_create` responde
  ACCESS_DENIED aunque el share sea `writable` y `force user = deck`.
- No era cosa de permisos POSIX: `/opt/decomps` y `/home/deck` son `deck:deck` y se escribe bien
  en local. Tampoco del `vfs objects` (se probo quitandolo: mismo error).

## Causa del cambio
La entrada **SMB** de la seccion *Herramientas* de CalvOS Store (primera version) instalaba samba
y habilitaba `smb.service`/`nmb.service` a pelo con `systemctl enable --now`. **Nunca ejecutaba
`pocknix-share on`**, que es quien crea la entrada de passdb (con contrasena aleatoria que se
descarta) y habilita ademas `avahi-daemon`.

Antes se activaba desde **Calvos Tools → Compartir**: ese flujo pasa por `pocknix-share` y por eso
funcionaba. El cambio lo introdujo nuestra entrada nueva de la tienda, no el sistema.

## Arreglo
1. **Dispositivo (estado actual)**: se quito la contrasena temporal de diagnostico (`pdbedit -x deck`)
   y se ejecuto `pocknix-share on`: entrada de passdb recreada con contrasena aleatoria, smb+avahi
   habilitados. Verificado: como invitado, `mkdir`/`rmdir` funcionan en `/opt/decomps` y `/home/deck`.
2. **Motor (`pocknix-store 7`)**: nuevo paso `setup` llamado **`share-passdb`** que ejecuta
   `/usr/bin/pocknix-share on`. La entrada `catalogue.d/samba.conf` ahora lleva
   `setup=share-passdb`, y el motor ya ejecuta los pasos `setup` al instalar (es el mismo mecanismo
   de Tailscale). Una instalacion existente se repara con `sudo pocknix-store setup samba`.
3. **PC**: el montaje `/mnt/odin` pasa de `credentials=` a `guest` (el invitado ya escribe). Se
   elimino `/etc/samba-cred-odin`.

## Notas
- `nmb.service` no hace falta: el `smb.conf` lleva `disable netbios = yes`. La entrada ya solo
  declara `smb.service`.
- El catalogo es **clave=valor por linea**: un `note=` partido en dos lineas se pierde.
- La raiz de `/opt` sigue siendo `root:root` (no escribible por SMB). Sus subcarpetas si.
