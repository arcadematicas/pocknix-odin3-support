# Entrada para Telegram — CalvOS 1.3 (Odin 3)

Grupo de releases: https://t.me/+Pz1kfKX8UZs0OWE0
Release en GitHub: https://github.com/arcadematicas/pocknix-odin3-support/releases/tag/calvos-1.3
Notas completas: `docs/RELEASE-CalvOS-1.3.md`

---

## Versión media (recomendada, ~2.300 caracteres)

🎮 **CalvOS 1.3 — AYN Odin 3** · 1/11/2026

Imagen nueva: **suspensión arreglada** y **0,14 %/h** en reposo (antes 0,44). Se graba en microSD; la
interna no se toca.

🔄 **Actualizaciones de verdad**
• Repos propios firmados: [pocknix], [pocknix-shared], [pocknix-base] (fuera [aur]).
• Base ALARM espejada: los `-Syu` van contra el snapshot congelado, no contra la ALARM viva.
• Kernel siempre por paquete + `pocknix-kernel-guard`, que repara si módulos y KERNEL no coinciden.
• Publicado el refactor de escritorio que en 1.2 rompía las actualizaciones.

🖥 **Escritorio y personalización**
• Plasma Mobile + homescreen táctil, KScreen, branding (splash, fondo PocknixOS), coredumps a 1 GB,
  systemd-oomd.
• Baloo apagado por defecto y un solo dueño por fichero: se acaban los conflictos al actualizar.
• Panel de Control v0.76 y tema Eclipse 0.3.5 (se instala una vez y lo actualiza el panel).

🔋 **Batería**
• Salud real: 98,6 % (7.838.000 µAh), 35,11 Wh y tiempo de carga en upower.
• MangoHUD con % y tiempo correctos (coulomb counter).
• Perfiles fiables desde el arranque: 832 MHz / 2,84 GHz en *medio*, 4,32 GHz / 1,1 GHz en *alto*.
• Ventilador sin oscilaciones (rango 27-59).

😴 **Suspensión**
• `deep` por defecto: 0,14 %/h (13h31, 1,85 % de batería) frente a 0,44 con `s2idle`.
• Fuera `a6xx_gmu_resume`, GMU OOB y preemption al despertar (kernel 28).
• ath12k: el hook saca el PCI al dormir y `wlan0` vuelve sola.
• SoCCP en D3 e isla SSC apagada: el SoC colapsa de verdad.

🎧 **Audio**
• Auriculares: volumen real (0 dB), sin chisporroteo y conmutación en ~17 ms.
• Altavoz: arreglada la ruta, no el volumen.
• Micrófono: UCM listo (`Mic` y `Headset`), pero la captura sigue a cero → próximo objetivo.

🎮 **GPU y juegos**
• Iris completo + low latency, Mesa 26.3.0 y Turnip de Valve por juego.
• gamescope OGC con HDR de armada; HDR apagado por defecto (QAM delante), toggle disponible.
• Mando: arreglada la carrera de `uhid`; los atajos de Steam ya no desaparecen; QAM estable en juego.
• Moonlight 6.2.0 + Sunshine; captura 1080p60 por hardware con `calvos-grabar`.

🛠 **Herramientas**
• `calvos-doctor` + botón "Enviar informe" del panel → issues en `calvOS-reports`.
• `pocknix-sleep-report`, `dock-check`, instalación en flash interna.

📦 **Descarga**: 3 trozos 7-Zip (abrir `.001` y extraer).
🔐 SHA256:
317049c5a7109e2bb0ddddf1e166f23924bb77cb03652d714bead4c669375a4d
d34caf76e3c132d34120f1ba41d019e7d40e9f6a1d665d800fd61a423d15cbe7
e501fc94f464a0f3a6892d1db8bc1ceb7576aa63575b283c59678ca3cb5d62f9

📄 Notas completas: https://github.com/arcadematicas/pocknix-odin3-support/releases/tag/calvos-1.3

---

## Versión corta (3-4 líneas)

🔥 **CalvOS 1.3 para AYN Odin 3** — suspensión arreglada y **0,14 %/h** en reposo (antes 0,44).
Repos propios firmados, escritorio Plasma Mobile con branding, batería con salud real, auriculares
resueltos (micro pendiente), Iris completo y captura 1080p60 por hardware.
📄 https://github.com/arcadematicas/pocknix-odin3-support/releases/tag/calvos-1.3
