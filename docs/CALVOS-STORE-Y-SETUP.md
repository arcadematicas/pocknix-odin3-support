# CalvOS Store + Asistente de primer arranque (idea a proyecto)

## Qué queremos
1. **CalvOS Store**: catálogo visual para instalar/quitar nuestras piezas opcionales
   (DeckStation, WProton, Suyu, ES-DE, Proton-GE/CachyOS, Tailscale, WireGuard, Moonlight…).
2. **CalvOS Setup**: asistente que, en el primer arranque del escritorio y/o al terminar el
   asistente de Steam, guíe de forma visual por lo que hoy vive en CalvOS Tools (escritorio,
   mando, almacenamiento, red, emulación, perfil de energía).

## Qué reutilizamos y qué es nuestro
| Pieza | Origen | Decisión |
|---|---|---|
| `pocknix-ui` (motor QML/C++, `pocknix-job`, `pocknix-pacman`) | upstream | **Dependencia.** Es fontanería y está bien hecha; nos ahorra escribir la base |
| `pocknix-store` (app + catálogo) | upstream | **No adoptar tal cual.** Su catálogo apunta a `pocknix-emu-*` y a `pocknix-tiles`, que no tenemos |
| Catálogo `.conf` | nuestro | **Nuestro**, uno por pieza, apuntando a nuestros paquetes y servicios |
| Asistente | nuestro | App nueva sobre el mismo motor |

Regla de branding: lo visible dice **CalvOS** (títulos, `Name=`, textos). No se tocan el import
`Pocknix.Ui`, rutas `/usr/share/pocknix-*`, nombres de binario ni de paquete (identificadores).

## Por qué el catálogo es barato
Cada entrada es un `.conf` con `name`, `section`, `description`, `icon`, `packages`, `services`,
`note` y `setup`. La app **oculta** las entradas cuyos paquetes no estén en los repos, así que
podemos empezar con pocas y añadir sin tocar código.

## Catálogo inicial propuesto
| id | Sección | Paquete(s) | Nota |
|---|---|---|---|
| `deckstation` | emulación | `deckstation-arm` | frontend + cores de CalvOS |
| `wproton` | compatibilidad | `wproton-arm` | juegos Windows (x86/ARM) |
| `suyu` | emulación | `suyu-libretro` | Nintendo Switch (libretro) |
| `esde` | emulación | `es-de` | frontend ES-DE |
| `proton-ge` | compatibilidad | `proton-ge` | Proton alternativo para juegos x86 |
| `proton-cachyos` | compatibilidad | `proton-cachyos` | variante CachyOS |
| `tailscale` | red | `tailscale` | acceso remoto (setup `tailscale-operator`) |
| `wireguard` | red | `wireguard-tools` | VPN |
| `moonlight` | streaming | `moonlight-qt` | streaming desde PC |

Cada entrada lleva `note` (“dónde se enciende”) y, si aplica, `services` a habilitar `--now`.

## Asistente (CalvOS Setup)
Pasos, todos **omitibles** y repetibles desde CalvOS Tools:
1. **Bienvenida**: modelo, batería y aviso de que se puede salir y volver luego.
2. **Escritorio**: elegir Plasma de escritorio (ya por defecto) o no instalarlo.
3. **Emulación**: instalar DeckStation + WProton + Suyu, con espacio estimado.
4. **Mando**: lanzar la calibración existente (`pocknix-gamepad-calibration`).
5. **Almacenamiento**: montar SD / comprobar expansión de la raíz.
6. **Red**: SSH, Samba, Tailscale (con el flujo `tailscale-operator`).
7. **Actualizaciones**: primera pasada y canal.
8. **Energía**: perfil `bajo/medio/alto` y límites.
9. **Fin**: marcar completado; no vuelve a salir solo.

Disparadores: marcador de primer arranque (ya tenemos el del OOBE) y, opcionalmente, al cerrar el
asistente de Steam. **Nunca** bloquea el arranque: si falla, se registra y se puede relanzar.

## Fases
1. **Fase 1 (corta)**: catálogo propio + app de tienda con branding CalvOS, instalada como
   paquete `calvos-store` que depende de `pocknix-ui`. Probar instalar/quitar 2-3 entradas reales.
2. **Fase 2**: asistente `calvos-setup` sobre el mismo motor, con los 9 pasos, marcador y
   lanzador desde CalvOS Tools.
3. **Fase 3**: pulido (iconos, textos, traducción) y empaquetado en la imagen.

## Decisiones pendientes de Fransis
1. **¿Apps propias que dependen de `pocknix-ui`** (mi recomendación: sí) o fork completo del motor
   con nombre CalvOS (más identidad, más mantenimiento)?
2. **¿Qué entra en el catálogo inicial?** La tabla de arriba es una propuesta.
3. **¿El asistente sustituye a CalvOS Tools** en el primer arranque, o solo lo complementa
   (mi recomendación: complementa; Tools sigue siendo la puerta de entrada)?
