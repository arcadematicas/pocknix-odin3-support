# Procedencia y licencias de los shaders

Estos shaders **no son nuestros**: se distribuyen aquí para que una instalación
nueva de DeckStation tenga efectos listos sin que el usuario tenga que buscarlos.
Cada pack mantiene la licencia de su autor.

| Carpeta | Qué es | Autoría | Licencia |
|---|---|---|---|
| `shaders_slang/bezel/Mega_Bezel` | Mega Bezel (marcos, reflejos, CRT sobre bezel) | HyperspaceMadness y colaboradores | **GPLv3** (lo declara su `README.md`, incluido en la carpeta) |
| `shaders_slang/crt` | Familia CRT (Guest Advanced, Royale, Beans, etc.) | guest.r, Themaister, TroggleMonkey y otros | **Por shader**: la mayoría GPL/CC. Van incluidos los `LICENSE` de los packs que lo traen (`crt-royale/LICENSE.TXT`, `crt-beans/LICENSE`) |
| `shaders_slang/handheld` | Efectos de pantallas portátiles (LCD, Game Boy, etc.) | Varios | **Por shader**, igual que `crt` |
| `shaders_slang/retro crisis` | Presets de **Retro Crisis** (`RC GDV-NTSC - ...`) en 720p/1080p/1440p/4K | Retro Crisis | **Compartidos gratuitamente por el autor** (confirmado por el usuario). Son ficheros `.slangp` que **solo referencian el pack `crt`**, así que no arrastran dependencias |

Los packs `crt` y `handheld` proceden del repositorio oficial
[`libretro/slang-shaders`](https://github.com/libretro/slang-shaders), que **no tiene
un LICENSE de nivel superior**: cada shader lleva la suya. Si vas a redistribuir
esto por tu cuenta, revisa el fichero de licencia del shader concreto que uses.

## Cómo se despliegan

El manifiesto (`configs/deploy-manifest.txt`) los copia a
`{HOME:RetroArch}/.config/retroarch/shaders` con política **`keep`**, que hace
mezcla **por fichero**: se añaden los que falten y **no se toca** ninguno que el
usuario haya puesto por su cuenta. Es decir, puedes añadir tus propios shaders sin
miedo: una actualización no te los borra.

## Si quieres añadir más

Deja el pack en `configs/retroarch/shaders/shaders_slang/` y vuelve a ejecutar
`deckstation-configs.sh`. Recuerda revisar su licencia antes de subirlo a un repo
público.
