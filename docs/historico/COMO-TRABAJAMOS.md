# Cómo trabajamos en esto — para David y para el agente IA (Jarvis)

Documento de entrada. Si acabas de llegar al proyecto, **léete esto primero**: explica
dónde está cada cosa, quién manda sobre qué, y cómo se trabaja para no liarla.

Escrito el 25/09/2026 por Fransis para que David y Jarvis puedan colaborar desde el día uno.

---

## 1. Qué es este proyecto, en dos frases

Estamos haciendo que **Pocknix** (una distribución de Linux para consolas Android, hecha por
gente de fuera) funcione bien en la **AYN Odin 3**, una handheld. Pocknix es software libre
y ya soporta otras consolas; nosotros estamos añadiendo el soporte de la Odin 3 y todo lo
que le queremos encima: emulación, efectos, ahorro de batería, controles, etc.

---

## 2. Dónde vive cada cosa (lo único que hay que memorizar)

Hay **dos repositorios** y nada más. Antes estaban repartidos en tres sitios, pero desde
el 15/09/2026 ya está centralizado: **lo nuestro vive en un único sitio.**

| Repositorio | Qué es | Quién manda aquí |
|---|---|---|
| **`arcadematicas/pocknix-odin3-support`** | **EL CENTRO.** Todo lo nuestro: paquetes, parches, herramientas, documentación. | **Nosotros.** Aquí se edita. |
| **`arcadematicas/pocknix-os`** | El sistema base, para poder compilar. Rama `odin3-sm8750`. | Casi nadie. Es la copia de Pocknix + lo que le copiamos del centro. |

### ¿Por qué no está todo en un solo sitio?

Porque **Pocknix es software libre con licencia GPL**, y esa licencia obliga a que el sistema
base siga en su repositorio original (`shuuri-labs/pocknix-os`) para poder seguir actualizándolo
sin perder nada. Es una obligación legal, no una chapuza.

Pero **todo lo que es nuestro de verdad** (los paquetes, el kernel parcheado, las herramientas)
está en el centro, y de ahí se copia al sistema para compilar.

### La regla de oro

> **Se edita SIEMPRE en el centro. NUNCA se edita a mano en el sistema.**

Y luego se ejecuta `tools/sync-to-os.sh` para volcarlo al sistema. El sistema se puede
regenerar desde el centro en cualquier momento, así que **si se pierde, no se pierde nada**
mientras que el centro esté intacto.

---

## 3. El flujo de trabajo (para Jarvis y para David)

```
   1. Editar          →  pocknix-odin3-support  (el centro)
        │
   2. Sincronizar     →  tools/sync-to-os.sh          (copia centro → sistema)
        │
   3. Comprobar       →  tools/check-sync.sh         (falla si algo se desvió)
        │
   4. Compilar        →  en pocknix-os:  make build  (DEVICE=sm8750)
        │
   5. Probar en la Odin
        │
   6. Commit y push   →  con un mensaje que explique qué se hizo y por qué
```

**Antes de tocar nada**, ejecuta `tools/check-sync.sh`. Si dice que todo va bien, el centro y
el sistema están sincronizados y puedes trabajar tranquilo.

**Y si algo falla al compilar**, casi siempre es que se editó el sistema sin pasar por el centro.
La solución es siempre la misma: volver a lanzar `tools/sync-to-os.sh`.

> El paso 4 (`make build`) es para **distribuir**: genera la imagen entera y tarda 30-45 min.
> Si lo que quieres es **probar un cambio en la Odin que ya tienes delante**, no hace falta
> flashear: compila solo ese paquete e instálalo por SSH con `tools/deploy-to-device.sh`
> (ver la sección 7).

---

## 3-bis. Los comandos de git (copia y pega)

### Clonar los DOS repos (una vez)

```bash
git clone https://github.com/arcadematicas/pocknix-odin3-support        # EL CENTRO (aquí se edita)
git clone -b odin3-sm8750 https://github.com/arcadematicas/pocknix-os   # el sistema (para compilar)
```

### Mandar un cambio (el día a día)

```bash
cd pocknix-odin3-support
git pull                       # SIEMPRE antes de empezar
# ... editar ...
tools/check-sync.sh            # comprobar que el centro y el sistema cuadran
git add -A
git commit -m "fix(kernel): 0081 manda el mensaje en formato Android (opcode 0x16)"
git push                       # aqui 'origin' SI es el nuestro
```

El mensaje del commit: **qué** se hizo y **por qué**, en español, pensando en quien lo lea dentro de
seis meses.

### ⚠️ LA TRAMPA: en `pocknix-os`, `origin` NO es nuestro

```bash
cd pocknix-os
git remote -v
# origin        -> shuuri-labs/pocknix-os     <-- UPSTREAM. Solo 'git fetch'. NO se pushea aqui.
# arcadematicas -> arcadematicas/pocknix-os   <-- NUESTRO. Aqui SI.

git push arcadematicas odin3-sm8750     # ✅ correcto
# git push origin odin3-sm8750          # ❌ "Permission denied" (es el repo de shuuri-labs)
```

**Si clonaste del upstream por error**, añade nuestro fork y ponte en la rama del proyecto:

```bash
git remote add arcadematicas https://github.com/arcadematicas/pocknix-os.git
git fetch arcadematicas
git switch odin3-sm8750
```

### Si te dice que no tienes permiso

1. **¿Has aceptado la invitación?** En GitHub → campana de notificaciones → *Invitations*.
2. Si el error es `403` / `bad credentials`: tu token (PAT) necesita el scope **`repo`** y no estar
   caducado.
3. **¿A qué repositorio empujas?** Mira "LA TRAMPA" de arriba: en `pocknix-os` es a
   **`arcadematicas`**, nunca a `origin`.

---

## 4. Reglas para no liarla

1. **Se edita en el centro, nunca en el sistema.** Si no, se pierde en el siguiente sync.
2. **Cada cambio, un commit**, con un mensaje que diga *qué* se hizo y *por qué*.
   Ese mensaje es la documentación del proyecto. Escribidlo pensando en el que lea dentro
   de seis meses (o en seis días).
3. **Antes de dar algo por bueno, probar en la Odin.** No sirve de nada si compila.
4. **Si algo no funciona, dejar constancia en `docs/`.** Existe la costumbre ya: hay
   documentos como `BATTERY-ISSUE.md`, `SUSPEND-ISSUE.md`… uno por problema.
5. **No tocar la rama `odin3-pr`.** Es la rama "limpia" que le mandamos a los creadores de
   Pocknix para que acepten nuestro soporte. Solo se toca para responderles.

---

## 5. Cómo se sabe qué se está haciendo ahora

- `docs/PENDIENTE-*.md` — lo que está a medias en cada momento.
- `CHANGELOG.md` — **la historia de todo lo que se ha añadido o quitado**, en orden y
  en lenguaje normal. Si quieres saber "qué lleva hecho el proyecto", míralo.
- `AGENTS.md` — la memoria técnica del proyecto. Es largo, pero es donde está el detalle fino
  de cada problema. Buscar antes de preguntar.

---

## 6. Quién hace qué

- **Fransis** — decide la dirección del proyecto, aprueba los cambios grandes.
- **David (DaViDuSkY)** — colaborador técnico, acceso de escritura a los dos repos.
- **Jarvis** — agente IA de David. Puede escribir código en los repos, siempre que siga
  las reglas de este documento y del `AGENTS.md`.

**Los dos ya tienen acceso de escritura** a `pocknix-odin3-support` y a `pocknix-os`.
Quien vaya a tocar algo, que haga un commit con su nombre: así se sabe al instante
qué hizo cada uno.

---

## 7. Iterar sin flashear: `tools/deploy-to-device.sh`

Flashear la imagen entera son 30-45 minutos y solo hace falta para distribuir. Para
**probar un cambio en la Odin** no hace falta: se compila solo el paquete afectado y se
instala en caliente por SSH. Eso es `tools/deploy-to-device.sh`.

```bash
tools/deploy-to-device.sh pocknix-bsp-sm8750          # compila e instala en la Odin
tools/deploy-to-device.sh pocknix-decky pocknix-tools  # varios de golpe
```

Hace, en este orden: `sync-to-os.sh` → `make packages PKG=…` → `scp` del `.pkg.tar` →
`pacman -U` en la Odin → reinicio de los daemons afectados → `systemctl --failed` y el
desfase que queda.

### Opciones que hay que conocer

| Opción | Qué hace |
|---|---|
| `--check` | **No instala nada.** Compara la versión de cada paquete nuestro instalado en la Odin contra la del PKGBUILD del centro y lista el desfase. Sale con **0** si está todo igualado y **1** si hay desfase. No necesita sudo. |
| `--check --strict` | Como `--check`, pero también falla si un paquete del centro **no está instalado** en la Odin. |
| `--dry-run` | Muestra los 6 pasos sin hacer ninguno. |

```bash
tools/deploy-to-device.sh --check        # ¿la Odin está igualada al centro?
```

### Variables de entorno

| Variable | Por defecto | Para qué |
|---|---|---|
| `DEVICE_HOST` | `odin-local` (192.168.4.22, la de casa) | Cambia de Odin. `DEVICE_HOST=odin` va por Tailscale. |
| `DEVICE_SUDO_PASS` | `pocknix` | sudo de `deck` en la Odin. |
| `PC_SUDO_PASS` | — | sudo del **PC**, solo lo necesita el `make packages` (monta un chroot aarch64). |
| `NO_RESTART=1` | — | No reinicia ningún servicio al terminar. |
| `FORCE_RESTART=1` | — | Reinicia el loader de Decky aunque haya Steam. |

### ⚠️ Tres cosas que el script hace por ti (y por qué)

1. **El loader de Decky NO se reinicia si hay Steam o sesión gráfica.** Reiniciarlo en
   caliente con Steam en modo juego provoca el **crash loop de steamwebhelper** que
   documenta el `AGENTS.md`. El script lo comprueba y, si la sesión está viva, lo dice y
   lo deja para que lo reinicies tú desde el escritorio.
2. **`--overwrite` solo en dos rutas**, `/opt/deckstation/*` y `/usr/share/decky-plugins/*`.
   Esos árboles los crean en tiempo de ejecución `deckstation-setup.sh` y
   `deploy-lanzar-sh.sh` (~2900 ficheros sin dueño) y el plugin de Decky, así que
   `pacman -U` fallaba siempre por conflicto. Limitado a propósito: un `--overwrite '*'`
   taparía también `/usr/bin` y `/etc`.
3. **La contraseña va con `SUDO_ASKPASS`, nunca en la línea de órdenes.** El script sube
   un askpass a `/tmp` de la Odin, modo 700, usa `sudo -A` y lo borra al salir.

Y ojo con esto: **el script instala lo compilado, no cambia el repo**. Si pruebas algo a
mano en la Odin, tráelo al centro después (regla de oro del punto 2).

---

## 7-bis. DeckStation vive en DOS sitios (y esto se olvida)

DeckStation (el lanzador de emuladores) está en **dos repositorios a la vez**:

| Sitio | Qué es | Para qué |
|---|---|---|
| **`stshunz/deckstation-arm`** (GitHub) | **El repo del proyecto DeckStation** | Compartido con stshunz, David y Jarvis |
| **`packages/deckstation-arm/`** (aquí, en el centro) | **Nuestra copia**, la que acaba en la imagen de la Odin | Para que el sistema lleve los cambios |

**La regla**: cualquier cambio que hagamos en DeckStation **para nuestro sistema**
(wrapper de Steam, cores, configs de RetroArch, ES-DE, scripts, arte…) tiene que quedar
**en los dos sitios**. Está en el `AGENTS.md` del centro, pero se olvida, así que aquí va
el flujo concreto:

```bash
C=/home/fransis/pocknix-odin3-project/pocknix-odin3-support
D=/home/fransis/deckstation-arm

# 1. editar en el centro (fuente de verdad de nuestro sistema)
# 2. copiarlo al repo
cp "$C/packages/deckstation-arm/<ruta>" "$D/<ruta>"
# 3. subir los dos
git -C "$D" add -A && git -C "$D" commit -m "..." && git -C "$D" push
git -C "$C" add -A && git -C "$C" commit -m "..." && git -C "$C" push
# 4. desplegarlo a la Odin (si hay que probarlo ya)
"$C/tools/deploy-to-device.sh" deckstation-arm
# 5. comprobar que no queda nada descuadrado
diff -rq "$C/packages/deckstation-arm" "$D"
```

⚠️ **Los scripts de DeckStation (`scripts/*.sh`) no los gestiona ningún paquete** — los
despliega el propio DeckStation en `/opt/deckstation/scripts/`. Si tocas uno, además de
subirlo a los dos sitios, **cópialo a mano a la Odin**, o se queda viejo sin que nadie se
entere (nos ha pasado: tres arreglos de Jarvis llevaban semanas sin llegar a la consola).

---

## 8. Resumen en 30 segundos

- Todo lo nuestro está en **`arcadematicas/pocknix-odin3-support`**. Ese es el sitio donde se trabaja.
- El otro repo (`pocknix-os`) es la copia del sistema libre, solo para poder compilar. **No se toca a mano.**
- Después de editar: `tools/sync-to-os.sh`, luego `make build`, probar en la Odin, y commit.
- Para **probar en la Odin sin flashear**: `tools/deploy-to-device.sh <paquete>`
  (y `--check` para ver el desfase sin instalar nada).
- ¿Qué lleva hecho? `CHANGELOG.md`. ¿Detalles técnicos? `AGENTS.md` y `docs/`.
