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

## 7. Resumen en 30 segundos

- Todo lo nuestro está en **`arcadematicas/pocknix-odin3-support`**. Ese es el sitio donde se trabaja.
- El otro repo (`pocknix-os`) es la copia del sistema libre, solo para poder compilar. **No se toca a mano.**
- Después de editar: `tools/sync-to-os.sh`, luego `make build`, probar en la Odin, y commit.
- ¿Qué lleva hecho? `CHANGELOG.md`. ¿Detalles técnicos? `AGENTS.md` y `docs/`.
