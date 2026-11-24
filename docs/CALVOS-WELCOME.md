# CalvOS Welcome — asistente de primer arranque

## Objetivo
Que una Odin recien flasheada quede usable sin tocar un terminal: red, perfil, mando probado y
los primeros paquetes instalados. Se muestra **una sola vez** por instalacion.

## Nombre y encaje
- Paquete nuevo: **`calvos-welcome`** (regla `calvos-*`), `arch=any`.
- UI con **`pocknix-ui`** (mismo motor QML que la tienda): `/usr/share/calvos-welcome/qml/Main.qml`.
- CLI propia minima (`calvos-welcome`) para estado/marcador y pasos que necesiten root.
- Cuelga de **`pocknix-desktop-full`** (dependencia), que es raiz del gate. Es pequena (QML).

## Deteccion de "primer arranque"
- Marcador: `/var/lib/calvos-welcome/done` (por dispositivo, sobrevive a updates).
- Lanzadores:
  1. `/etc/xdg/autostart/calvos-welcome.desktop` para modo escritorio (sale solo si el marcador
     no existe).
  2. Enganche en `pocknix-session` para **Game Mode**: antes de arrancar Steam, si no hay marcador,
     lanzar el asistente y esperar a que termine.
- Para pruebas: `calvos-welcome --reset` borra el marcador.

## Fase 1 (lo que haremos primero)
1. **Bienvenida** — branding CalvOS y que va a pasar (2 lineas, sin muros de texto).
2. **Red** — `nmcli`: listar Wi-Fi, conectar con contrasena (teclado en pantalla si no hay fisico),
   o "ya tengo red" para saltar. Estado visible (conectado / sin red).
3. **Energia** — perfil `medio` (por defecto) o `alto` (mas rendimiento); usa `pocknix-power-profile`.
4. **Mando** — pantalla de prueba que ilumina cada boton al pulsarlo. Reutiliza el singleton
   `Pad` de `pocknix-ui` (evdev -> teclas) y muestra D-pad, A/B/X/Y, LB/RB, sticks.
5. **Recomendados** (opcional, sin bloquear) — 3-4 entradas de la tienda para instalar de golpe
   (p.ej. Flatpak, SSH, DeckStation). Reutiliza el motor: `pocknix-store install <ids>`.
6. **Listo** — marcar `done` y boton "Abrir Steam".

## Fase 2 (despues)
- Idioma/region y zona horaria.
- Restaurar snapshot (`pocknix-snapshots`) en vez de empezar de cero.
- Login de Steam asistido.
- Tema/acento y brillo inicial.

## Decisiones tecnicas
- Nada de dependencias nuevas: `pocknix-ui` + Qt + `nmcli` + systemd.
- Todos los pasos deben poder **saltarse**; el asistente nunca debe dejar el dispositivo sin salida.
- Si no hay red, se permite terminar y se recuerda en Ajustes (no bloquear el primer arranque).

## Pruebas
- Primer arranque con marcador ausente -> aparece; segunda vez -> no aparece.
- `--reset` -> vuelve a aparecer.
- Wi-Fi: conectar, contraseña incorrecta (mensaje claro), saltar.
- Mando: cada boton se ilumina; sin mando -> "saltar".
- Instalar recomendados -> aparecen como instalados en la tienda.
