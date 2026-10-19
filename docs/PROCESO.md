# Cómo trabajamos en este proyecto (19/10/2026)

Guía corta para que Fransis no tenga que llevar la mecánica: él define **qué** quiere,
Alfred lleva el **cómo**.

## Reparto de papeles
| Quién | Decide / hace |
|---|---|
| **Fransis** | Qué quiere en la consola y con qué prioridad. Las pruebas subjetivas (audio, mandos, QAM, fps, sensación). Aprobar lo arriesgado (kernel nuevo, reinicios, cambios que puedan no arrancar). El acceso físico (encender, despertar, meter SD). |
| **Alfred** | Arquitectura y versiones, builds, empaquetado, publicación, documentación, investigación de upstream, delegación a agentes, y el **orden** de las cosas. |
| **Agentes** (`coder`, `general`, `explore`) | Trabajo concreto: rebasar parches, analizar, buscar. |

## Fuente de verdad
- **Código**: fork `arcadematicas/pocknix-os`, rama **`odin3-sm8750`**.
- **Paquetes y docs**: `pocknix-odin3-support` (BSP, docs, scripts).
- **Distribución**: R2 (`pocknix/sm8750`, `pocknix/shared`) — de ahí instala la consola.
- **Upstream** (pocknix, ROCKNIX, armada): **solo fuente de parches** que evaluamos. No se
  rebasa (decisión 19/10). Se revisa cada 2-4 semanas y se trae lo que interese.

## Ciclo de un cambio
1. **Preparar** en el fork (rama corta si es arriesgado).
2. **Compilar** en el PC (`make kernel` / `make packages`).
3. **Probar primero en la SD** si toca kernel, boot, suspend o algo que pueda no arrancar.
4. **Instalar en la consola** (`pacman -U` / `pacman -S`), verificar con checklist.
5. **Publicar** en R2.
6. **Documentar** en `docs/` + apuntar en la memoria persistente.

Regla de oro: **lo que puede dejarte sin consola se prueba en la SD**.

## Versiones (control nuestro)
Steam, MangoHUD, FEX, Mesa, gamescope, kernel… los fijamos nosotros. Cuando upstream saca
algo interesante, lo evaluamos y lo llevamos **si nos convence**; no seguimos su ritmo.

## Rollback (siempre disponible)
- Kernel: `/flash/KERNEL.bak` (lo deja el hook en cada actualización) + el paquete anterior
  en la caché de pacman.
- Sistema: **snapshots** btrfs (`pocknix-rollback`).
- SD de pruebas: se reflashea, no hay riesgo para el sistema diario.

## Cómo se pide/decide el trabajo
- Hay una **lista de pendientes priorizada** (en memoria + docs). Fransis dice "vamos a X"
  o "esto primero", y Alfred ordena el resto.
- Si un cambio es arriesgado, Alfred lo dice **antes** (qué puede fallar y cómo se vuelve).
- Si algo no se puede probar sin la consola, se queda "listo para instalar" y se prueba
  cuando Fransis está delante.

## Lo único que se le pide a Fransis
1. Decidir **prioridades** (no hace falta saber el cómo).
2. Estar delante para lo que necesita manos (reiniciar/despertar, meter SD) y aprobar lo
   arriesgado.
3. Probar lo subjetivo y decir "va bien" o "esto no".

Todo lo demás (versiones, parches, builds, docs, rollback) va por nuestra cuenta.
