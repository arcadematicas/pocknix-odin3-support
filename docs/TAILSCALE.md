# Tailscale en calvOS (acceso remoto)

Estado (23/10/2026): **no está configurado** en el sistema interno. En la tailnet aparecen nodos
antiguos de la Odin (`pocknix`, `odin3`, `odin3-1`, `pocknix-1`) **offline** desde hace semanas, de
imágenes anteriores.

## Comprobar si está instalado
```sh
pacman -Q tailscale        # ¿paquete?
systemctl is-enabled tailscaled
tailscale status
```

## Instalar y levantar
El paquete existe para aarch64 en ALARM (igual que `moonlight-qt`). Dos caminos:

1. **Vendorizarlo en nuestro repo** (`[pocknix-shared]`) para no abrir ALARM en el sistema:
   descargar `tailscale-<ver>-aarch64.pkg.tar.xz` + dependencias que falten y publicarlo como
   cualquier paquete propio.
2. **Instalarlo puntualmente** con `pacman -U` (y sus deps), sabiendo que la próxima actualización
   del sistema no lo gestionará.

Después:
```sh
systemctl enable --now tailscaled
tailscale up                # abre una URL de autenticación
```
Con `tailscale up` sin argumentos hay que autenticar en el navegador; para automatizar:
`tailscale up --authkey tskey-...` (clave efímera o reutilizable del panel de Tailscale).

## Notas
- El estado vive en `/var/lib/tailscale` → **se clona** con el sistema al instalar en interna.
- `tailscaled` debe ir habilitado para que sobreviva reinicios; el arranque es rápido (~2 s de retardo
  en la red, no bloquea la sesión de Steam).
- Sin Tailscale, con la consola fuera de casa **no hay acceso remoto**: solo LAN local.
