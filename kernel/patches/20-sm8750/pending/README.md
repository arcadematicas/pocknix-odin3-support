# Pendiente: calibracion del frame length de la Odin 3 Portal

`2161-drm-panel-vtdr6130-allow-calibrating-the-odin3portal-frame-length.patch` (de ArmadaOS
`b031dee`, `1305-...`) **no aplica todavia**: 4 de sus 14 hunks fallan.

Depende de la interfaz de calibracion de frame length del RP6 que Armada importa de ROCKNIX
(`0508-ROCKNIX-rp6-panel-frame-length-calibration.patch`). Nuestro arbol trae
`panel-visionox-vtdr6130-cog.c` con 0104 + 0104a + 1111, pero no esa interfaz.

No es necesario para que el panel encienda: 2160 ya aporta modos 60/120 Hz, init, DSC y
supplies. Esto solo permite ajustar el frame length con el panel delante. Se retoma cuando
haya unidad Portal y, si hace falta, midiendo el refresco real.
