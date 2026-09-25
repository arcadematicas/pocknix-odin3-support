# Changelog — Pocknix Odin 3

*La historia de qué se ha añadido y quitado en el proyecto, en orden. Para el detalle
técnico fino ver `AGENTS.md` y `docs/`.*

Este fichero resume el historial real del repositorio `pocknix-odin3-support` (209
registros, del 25/08/2026 al 25/09/2026), agrupado por semanas y explicado en lenguaje
normal: qué se hace, qué se quita y por qué. Los identificadores técnicos aparecen
solo entre comillas invertidas cuando hacen falta para buscar el detalle.

- `✅` = problema resuelto
- `🚀` = cosa nueva
- `⚠️` = problema abierto o solución provisional
- `🧹` = limpieza / algo retirado

---

## 📅 Semana del 22–25 de septiembre 2026

La semana más intensa en emuladores: se reparan los últimos fallos del gestor de
emuladores, se añaden sistemas nuevos y se integra todo con Steam. También es la
semana del incidente de arranque del día 25.

### Añadido

- 🚀 **Emuladores nuevos para el brazo del Odin**: se incorporan **RPCS3** (PlayStation 3)
  y **Xenia Edge** (Xbox 360) al instalador de emuladores, y se amplía el catálogo de
  ficheros de BIOS con Xbox, Nintendo DS, PS3, Amiga, GameCube, Cemu, PS Vita, Sega CD,
  MSX, PC Engine CD y 3DO. Para PS3 y Xbox 360 se crean además sus lanzadores propios:
  sin ellos no aparecerían en el menú de emuladores.
- 🚀 **Convertidor de ROMs integrado**: OpenROM 3.0.0 entra dentro de DeckStation para pasar
  tus juegos al formato que necesita cada emulador.
- 🚀 **Biseles (marcos decorativos) por fin visibles**: se instalan dentro de RetroArch
  (antes se quedaban a medio camino y no se veían) sin duplicarlos, y se limpia el
  temporal que dejaba el instalador. Además el instalador ya no se cuelga y **detecta solo
  dónde está la instalación**, en vez de tener la ruta del PC escrita a mano.
- 🚀 **Control de cómo se reparten el procesador y el disco**: se generaliza el sistema de
  "perfiles de rendimiento" y se **enlaza con los perfiles de energía del menú rápido de
  Steam** (bajo / medio / alto). La microSD pasa a usar la política de lectura `bfq`, pensada
  para que la carga de juegos vaya más fluida. En el plugin del menú de juego se muestra
  qué política está realmente activa, y se añaden dos herramientas: un diagnóstico y un
  script que manda los cambios a la consola sin recompilar nada.
- ✅ **El menú rápido de Steam y el indicador de FPS ya no quedan tapados por el juego**:
  se fuerza la composición de las capas para que se pinten por encima.
- El menú de emuladores **muestra solo los núcleos que están de verdad instalados** (antes
  aparecían en la lista cosas que no estaban).
- El gestor de emuladores ahora **abre a pantalla completa**, **no salta el teclado en
  pantalla**, se puede cerrar con una opción "Salir" o con Esc/B, y se corrigió un fallo
  que lo cerraba de golpe.
- Se añaden **configuraciones básicas para los emuladores que se usan sueltos** (aceleración
  por hardware y dónde buscar ROMs y BIOS), y los lanzadores de interfaz del sistema
  "Emuladores" del menú.
- El gestor de emuladores **valida los ficheros de BIOS por su huella digital (MD5)** y
  acepta rutas con subcarpetas. Se corrige la carpeta de PS2: el núcleo de PCSX2 de RetroArch la busca en otro
  sitio y por eso no encontraba nada.
- **Xenia se hace portátil** (tiene su propia carpeta de datos) y **MelonDS ya trae el mapeo
  del mando de Xbox**. Se activa la mejora de imagen (FSR) en RPCS3.
- Se añaden imágenes nuevas al programa de emuladores (logo, cabecera, portada e icono).
- Se traen al centro (este repositorio) las comprobaciones automáticas de que la copia del
  gestor de emuladores no se desvía de la del compañero, ampliadas con la lista de núcleos.
- Se ignoran las copias de seguridad de imágenes al guardar en el repositorio, para que no
  se suban por error.
- Se escribe la **guía completa de repositorio, versiones, paquetes y actualizaciones**.

### Corregido / solucionado

- ✅ **Arranque más robusto tras un corte de luz**: la tarjeta se monta con opciones que
  evitan que se rompa si apagas la consola de golpe.
- ✅ **Se documenta el incidente del 25/09**: la Odin entró en bucle de reinicio con el
  núcleo en pánico al flashear la imagen nueva. El análisis concluye que **el contenido de
  la imagen es correcto**, así que la causa más probable es la transferencia o el flasheo,
  no nuestro software. Aun así se refuerza el arranque (protecciones de montaje + arranque
  visible y diagnosticable) por si vuelve a pasar.
- ✅ **Herramientas para mandar cambios a la consola por red**: el uso de `sudo` se comía los
  datos que se enviaban por el canal de copia; ahora se empaqueta en un fichero temporal y se
  manda aparte.
- ⚠️ Se deja anotado que falta **instalar y probar en la consola** el enlace entre los perfiles
  de energía de Steam y las políticas de procesador/disco (ya está implementado aquí, pero
  sin verificar en vivo).

### Cambiado / notas

- La **integración de DeckStation en Steam pasa a ser automática** (ya no hay que activarla a
  mano) y añade las imágenes al estilo de la biblioteca de juegos. Además se detecta mejor si
  estamos en modo juego, y deja de ser "opcional".
- Se retira la opción "DeckStation BIOS" del menú de herramientas de Pocknix: era redundante
  porque ya está dentro del gestor de emuladores.
- 🧹 **Se retira el programa de instalación antiguo de aplicaciones** (lista de repositorios escrita a
  mano que no estaba conectada a nada); su trabajo pasa al gestor de emuladores. PPSSPP
  también pasa a instalarse desde ahí.
- Se unifica en un solo sitio el **documento de contexto del proyecto** (el que se carga solo
  al trabajar aquí), que estaba repartido entre el PC y el repositorio.

---

## 📅 Semana del 15–21 de septiembre 2026 — segunda mitad (17–21)

Semana grande de emulación. Se rescata la tarjeta corrupta, se vuelve al núcleo bueno, se
consigue **que la pantalla gire sin usar la GPU**, el gestor de emuladores se convierte en el
instalador de verdad y el plugin del menú de juego se amplía mucho.

### Añadido

- 🚀 **El gestor de emuladores pasa a ser también el instalador inicial**: desde las
  herramientas de Pocknix se prepara todo el entorno y se instalan los ~30 emuladores de una
  tacada. Se documenta la idea de fondo: *"dos puertas, un único motor"* — una para instalar
  (una sola vez) y otra para gestionar siempre, pero el motor es el mismo, para que un fallo
  de la ventana no deje al usuario sin poder instalar.
- 🚀 **254 núcleos de emulación** (se pasa de 165 a esa cifra) y **RetroArch completo ya en la
  primera instalación**, con los **perfiles que más usa Fransis** y los efectos de imagen
  (Mega Bezel, CRT y el de consolas) guardados en el repositorio.
- 🚀 **El núcleo de Suyu (Nintendo Switch) ya está compilado para el brazo del Odin** y entra
  en la imagen, con un parche nuestro que **añade la opción de idioma de la consola** → los
  juegos de Switch salen en español (antes salían siempre en inglés). También se prepara ese
  mismo núcleo para PC (x86), compilándolo dentro de un contenedor con una biblioteca
  antigua, para poder usarlo en un Deck o un PC.
- 🚀 **Herramientas nuevas**:
  - "¿Están al día los controladores de la GPU?" (`check-mesa.sh`).
  - "Sostén la tarjeta" (`check-deckstation-libs.sh`): revisa qué librerías les faltan a los
    emuladores.
  - Poner y recuperar el núcleo de la consola (`flash-kernel.sh` y
    `restore-kernel-from-sd.sh`).
  - `reflash-sd.sh`: re-flashear la tarjeta de forma robusta.
  - Herramientas para trabajar sin re-flashear la tarjeta: *(añadidas el día 16, ver la
    sección siguiente)*.
- 🚀 **Juego remoto (Moonlight) y DeckStation aparecen en el modo juego de Steam**, y la
  preparación de DeckStation ofrece además WProton con su propia entrada.
- 🚀 **"Distribuidor de BIOS del usuario"**: el usuario deja sus ficheros donde quiera y el
  script los reparte a la carpeta correcta de cada sistema. Se documenta la instalación
  inicial completa.
- 🚀 **Plugin del menú de juego ampliado**:
  - **Luz de color en los joysticks**: el mando se ilumina del color que elijas, y **ahora
    se puede apagar solo el izquierdo o solo el derecho** conservando su color y brillo.
  - **Estado del cuidado del panel (OLED)**: la pestaña de luces muestra cuándo se ha
    refrescado la pantalla y por qué se ha saltado (antes no había ningún aviso y parecía
    que no funcionaba).
  - Nueva pestaña **"Limpieza"**: cachés y registros, más un analizador de espacio en disco.
  - Nueva pestaña **"Sistema"**: incluye WProton y los emuladores.
- ✅ **El cuidado del panel ya no refresca la pantalla mientras estás jugando** y vuelve a
  detectar los mandos/lectores al reanudar.
- Se despliega el script de configuración a los emuladores y **se hacen legibles sus
  configuraciones**; ya no hace falta descargar un paquete de configuración de un servidor
  externo (era solo para PC).
- Se **sincroniza nuestra copia del gestor de emuladores con el repositorio del compañero**
  (stshunz) trae muchas mejoras: el menú de emuladores (ES-DE) se baja ya de la fuente
  oficial, dependencias reales (7zip), requisitos documentados, corrección de la ruta de los
  núcleos de RetroArch, un núcleo por defecto en cada sistema, carpeta propia para cada
  emulador instalado, y un plan de portabilidad a otras distribuciones.
- Se añaden notas de sesión de los días 17 y 18 (núcleos, configuraciones, BIOS, cuidado del
  panel) y se actualizan los huecos conocidos.

### Corregido / solucionado

- ✅ **La tarjeta SD se había corrompido y era irrecuperable** (el sistema de ficheros no
  montaba). Se recupera lo posible, se **re-flashea desde cero**, se reformatea la partición
  de Windows (que también estaba corrupta) y se restauran los datos del usuario y la carpeta
  de programas. El re-flasheo también se arregla para que no lleve escrito el número de
  usuario del PC (en la Odin es otro).
- ✅ **Se vuelve al núcleo bueno (7.2.4)**: el 7.2.6 traía **dos regresiones graves** (pantalla
  negra y WiFi que no arranca) y queda descartado. Se documenta por qué, con medidas.
- 🚀 **Rotación de pantalla sin usar la GPU conseguida**: la pantalla gira sin coste de GPU (lo
  hace el chip de vídeo por su cuenta). Se documenta con guía de verificación, incluidas las
  dos trampas que hubo que superar.
- Se traen los parches de rotación del proyecto de referencia (ROCKNIX) y se **limpian los
  parches que ya vienen incluidos** en esa versión.
- ✅ **Los emuladores instalados quedaban sin poder arrancarse**: faltaba el lanzador y su
  carpeta de datos. Ahora se despliega automáticamente desde tres sitios (la instalación, el
  propio lanzador al arrancar y el gestor tras cada instalación), así que se auto-repara.
- ✅ **Cinco fallos impedían instalar los 30 emuladores**: si uno fallaba, se paraba la cola
  entera. Ahora se anota el fallo y se sigue con el siguiente, con un resumen al final.
- ✅ **El gestor de emuladores se abría en negro** cuando arrancaba Steam: elegía el modo de
  pantalla equivocado. Se corrige para que funcione tanto en sesión gráfica como en la de
  Steam.
- ✅ **El instalador inicial ya no descarga RetroArch de Android**: eso rompía RetroArch en una
  instalación limpia. Ahora baja solo los recursos de la interfaz y enlaza los núcleos que ya
  trae el sistema.
- ✅ **Librería `libxss`**: se declara como dependencia y se revierte (el entorno de compilación
  no la puede resolver). Se pasa a "cosecharla" del propio Steam en el momento de instalar.
- ✅ **El gestor de emuladores en versión de brazo**: se corrigen las rutas de los
  emuladores, que apuntaban donde no era.
- ✅ **El camino de instalación del gestor** (carpetas con subcarpetas) y el apartado de BIOS
  (faltaba la rama en el menú) quedan activados.
- ✅ **La ruta del fichero compilado del núcleo de Switch** estaba mal, así que no se
  encontraba.
- ✅ **Gestión de ficheros compartidos (Samba)**: la instalación fallaba por el formato de
  versión de los paquetes (había que instalar la familia entera junta, no un paquete suelto).
- Se corrigió el **uso de las librerías de emulación antiguas** (fuera del camino obligatorio
  de compilación) y se trajeron al centro los paquetes de núcleos que solo vivían en el
  árbol de compilación (se perdían en silencio).
- Se anotan y se dejan escritas dos decisiones pendientes: la prueba del limitador de FPS del
  menú de Steam y si conviene un tipo de fichero distinto en el disco interno.
- Se aplica un ajuste de rendimiento (evitar copias al escribir) en los registros, la caché y
  la biblioteca de Steam.

### Cambiado / notas

- 🧹 **Este repositorio se convierte en EL CENTRO del proyecto**: se reescribe el README (que
  estaba desfasado desde antes de la reorganización) y se documenta la deriva entre la consola
  y el repositorio, incluidos dos fallos de sincronización encontrados (el cargador de arranque
  y la capa de gráficos).
- Se documenta **cómo se añaden paquetes** a la imagen, incluidas las tres trampas que han
  mordido y dónde va cada cosa.
- Se deja escrito que el interruptor de MangoHud está bien como está y **no se toca**: el
  indicador de FPS funciona perfectamente desde Steam (se había dudado de ello).
- Se documenta la **segunda pasada del estudio de ArmadaOS/ROCKNIX**: qué queda por
  aprovechar.
- Notas de la primera imagen oficial (`v0.4-odin3-1`).
- Se retiran de la documentación las cosas que se decide no hacer (el script puntual del
  núcleo de Switch para PC).

---

## 📅 Semana del 15–21 de septiembre 2026 — primera mitad (15–16)

Semana de orden interno y de arreglo de los fallos de arranque. Se reorganiza el proyecto
para que nada se pierda, y se corrigen tres problemas que impedían que la consola arrancara
bien.

### Añadido

- 🧹 **Reorganización: este repositorio pasa a ser EL CENTRO del proyecto**. Se crean las
  carpetas de paquetes, herramientas y ficheros que van al sistema, y se escriben dos
  herramientas nuevas: una que **copia el centro al sistema que se compila** y otra que
  **comprueba que no se ha quedado nada atrás** (la propia compilación la llama y para si no
  cuadran). Regla de oro documentada: se edita siempre aquí.
- Nuevo **paquete de "sistema base" para el chip SM8750** + metapaquete, que agrupa los
  servicios y ficheros propios del Odin.
- 🚀 **Pantalla de arranque del Odin 3** (la animación de encendido) dibujada directamente en
  pantalla, y **reducida** (960x540, 24 MB) porque la versión completa ralentizaba el arranque.
- 🎤 **Los 3 huecos de la auditoría**: micrófono, pantalla de arranque y refresco del panel.
- **Herramientas para trabajar sin re-flashear la tarjeta** cada vez: mandar un cambio a la
  consola por red o copiar un fichero suelto. Esto cambió la forma de trabajar del día a día.
- **Guía `BUILD.md`**: cómo compilar el Odin 3 desde cero, para colaboradores. Verificada
  clonando el repositorio en limpio.
- **MAKO** (escalado sin pérdida y generación de frames) queda integrado en el plugin, y se
  documenta por qué **no puede funcionar en la Odin**: su motor es solo para PC, y aquí los
  juegos de PC se traducen al vuelo. La integración queda lista y se abre una petición en su
  proyecto pidiendo una versión para ARM.

### Corregido / solucionado

- ✅ **El audio volvía a romperse entero** al añadir la configuración del micrófono → se
  revierte (el micrófono, de momento, no queda soportado).
- ✅ **Bucle de reinicios (434 seguidos)**: un servicio de sensores se quedaba reiniciándose
  solo. Se desactiva ese servicio concreto y se activan los que sí sirven.
- ✅ **Bucle de reinicio del asistente inicial de Steam**: al mezclar la actualización del
  proyecto original **se perdieron 6 cambios nuestros**; se recuperan y, sobre todo, se activa
  de verdad el servicio que marca el asistente (que se había quedado sin arrancar).
- ✅ **El parche de rotación de la GPU no llegaba a la imagen**: faltaba añadir el chip
  SM8750 a la lista del paquete que se instala.
- Se regenera el parche de la GPU Adreno que no aplicaba, y se rehace el paquete de sistema
  base sobre la versión ya verificada (el nuestro estaba duplicado).
- Se recupera lo que faltaba del núcleo y del cargador de arranque en la rama del proyecto.
- Se integra el parche del **limitador de FPS del menú rápido de Steam**.
- La **compilación usa todos los núcleos del PC** de forma permanente, y la capa de emulación
  antigua del proyecto original pasa a ser opcional (ya no estorba para compilar).
- Se corrigen rutas en el script de comprobación.

### Cambiado / notas

- Se documenta el modelo de ramas del proyecto y el "detector de regresiones" que hay que
  pasar tras cada actualización del proyecto original (porque ya nos ha pisado cosas tres
  veces).

---

## 📅 Semana del 8–14 de septiembre 2026

Semana de **batería cargando**, **escritorio que ya ve la pantalla**, **suspensión real**, y
el **arranque a 20 segundos**. Es el salto de "arranca pero a medias" a "arranca bien".

### Añadido

- 🚀 **Estudio completo de ArmadaOS** (el sistema que trae la Odin de fábrica, con el que se
  puede hacer comparativa directa) con informe, **scripts de referencia guardados** en el
  repositorio e índice.
- 🚀 **Se implementan varias mejoras venidas de ese estudio**:
  - Los interruptores que SteamOS activa (frecuencia variable, HDR, varias capas, etc.): antes
    no activábamos ninguno.
  - Un módulo que pasa las variables de pantalla a los servicios de la sesión: **arregla un
    fallo del servicio de pantalla** que se caía al cambiar de sesión.
  - El envoltorio de los juegos de Windows: **inyecta las librerías de mando que faltaban**
    (el mando estaba muerto), **repara un mando que se quedaba atascado** y desactiva la
    superposición del indicador de FPS.
- 📘 **Guía de los botones del mando del Odin 3**: el botón "atrás" pasa a "Acceso Rápido"
  para que funcione el menú de Steam, y **se conserva** el atajo del indicador de FPS.
- **Notas para el proyecto original**: el texto del PR de soporte del Odin 3 y la nota del
  asistente inicial de Steam. También se atendieron las peticiones del creador (petición #54) y
  se dejó constancia en el comentario.
- **Se re-sincroniza la rama limpia del PR con ROCKNIX** y se compila el núcleo 7.2.0. Por el
  camino se arregla un detalle que impedía compilar en un PC: los programas de arquitectura
  ARM no podían instalar dependencias por un problema de permisos.
- Se crea el **fork propio del repositorio del sistema** y la rama de trabajo del proyecto.
- Documentación: cómo activar el modo de pantalla completa de la capa de gráficos y dónde
  está el mecanismo de HDR; los ficheros de configuración de la sesión, el mapeo de mandos y
  la traducción de programas de PC de ArmadaOS.

### Corregido / solucionado

- ✅ **La batería ya carga en Pocknix** (¡hito!). La causa era que el firmware del cargador
  echaba a la batería a "modo de prueba" por no reconocerla. Se resolvió con el fichero de
  configuración adecuado, se dejó **permanente en la compilación** y se escribió una guía para
  poder reproducirlo. Se corrige también una lectura de diagnóstico que se interpretaba al revés.
- ✅ **El botón de encendido ya suspende de verdad** y la pantalla se enciende al despertar.
  Antes solo parpadeaba. Se documenta el problema y los dos bloqueos que hubo que quitar.
- ✅ **Ajustes → Pantalla ya ve el monitor** en el escritorio: faltaba instalar un paquete.
  El paquete de escritorio completo ya lo incluye de serie. Además se aclara que el aviso rojo
  del servicio de pantalla al cambiar de sesión es un falso positivo, no un fallo.
- ✅ **El servicio de la pantalla ya no falla** (usaba una ruta que ya no existe) y
  **Bluetooth queda activado** (se había quedado bloqueado sin dar error).
- ✅ **El arranque baja a ~20 segundos** (medido: 11 s de núcleo + 9 s de usuario): el
  diagnóstico ya no bloquea el arranque y Steam **espera a que la pantalla esté conectada**
  antes de arrancar (si no, se lanzaba antes y la salida se quedaba a oscuras).
- ✅ **El asistente inicial de Steam ya no entra en bucle de reinicios**: faltaba el fichero
  que lo marca, y además el programa de actualización **decía "hecho" cuando no había nada que
  hacer**, así que Steam pedía reiniciar en bucle. Verificado: el asistente termina y llega
  al inicio de sesión.
- ⚠️ **La imagen limpia arrancaba sin WiFi ni sonido**. Se documenta la causa: los ficheros de
  firmware del Odin 3 **no vienen en el paquete estándar de Linux** (ni el del WiFi, ni el
  del audio, ni el del procesador de sonido). Referencia: `docs/FIRMWARE-ISSUE.md`.
- Se corrige el apagado lento (el WiFi se reconectaba solo y lo bloqueaba) y se deja escrito
  el recetario de la sesión de juego (reinicio/apagado desde Steam, pantalla negra recuperable).

### Cambiado / notas

- Se deja constancia de la pista nueva para el problema de carga (abierta en el proyecto de
  ArmadaOS) y de las notas de DeckStation.
- Se escribe una **petición de ayuda en inglés** para el Discord de AYN/Armada sobre el
  problema de carga.
- Se crea el documento de contexto del proyecto con el estado de carga ya documentado.

---

## 📅 Semana del 1–7 de septiembre 2026

Primeros resultados en serio: el mando por cable, los juegos de Windows, el menú rápido de
Steam y el porcentaje de batería.

### Añadido

- 🚀 **Se adopta el modelo de SteamOS** para la sesión de juego: la capa que dibuja los juegos
  como proceso independiente y Steam como proceso hermano, más un servicio que gestiona el
  interruptor del indicador de FPS de forma resistente.
- 🚀 **Gestor de SteamOS**: un programa pequeño que se hace pasar por el gestor oficial para
  poder cambiar el **perfil de rendimiento (bajo / medio / alto) desde el menú rápido de Steam**
  — y para volver al escritorio o al modo juego de verdad.
- Se integra el **parche que arregla el limitador de FPS del menú rápido en arquitectura ARM**
  (venía de otro proyecto, Nova-Deck).
- Se amplía el plugin del menú de juego: **gestión de potencia** (ventilador, velocidad del
  procesador, perfiles), **indicador de FPS adaptado al chip del Odin**, y una **pantalla de
  vigilancia** que reinicia lo que se cuelga.
- Se mejora el plugin para que detecte los juegos que no pasan por el lanzador de Pocknix y
  para que los ajustes por juego se apliquen **en vivo** al guardar.
- Se escribe la **guía de reproducción del arreglo de carga de la batería** y el documento de
  contexto del proyecto.
- Se ignoran las copias binarias del núcleo al guardar en el repositorio.

### Corregido / solucionado

- ✅ **El porcentaje de batería ya no se queda congelado** y avisa antes de apagarse: antes
  solo se leía al arrancar, así que se quedaba clavado y los apagones por batería no daban
  aviso.
- ✅ **El porcentaje de batería ya no marca siempre lo mismo**: se calculaba con un valor de
  voltaje que el firmware solo informa una vez; ahora se estima con el voltaje real, corrigiendo
  la caída por la resistencia interna de la batería.
- ✅ **El mando por cable ya funciona en los juegos de Windows**: le faltaban permisos de
  lectura, así que no lo veían ni Proton ni WProton.
- Se investiga la carga a fondo: **desensamblando el módulo de Android se descubren los
  códigos que el firmware de esta unidad espera** y se escribe el parche correspondiente. Al
  día siguiente **se revierte** (el código original era el correcto, verificado contra el
  proyecto de referencia) y **se deja documentado el hallazgo** para cuando haga falta.
- Se añade el parche de activación de carga de referencia y el programa que cambia de sesión
  de verdad.

### Cambiado / notas

- Se cambia la estimación de batería a "v5": voltaje de la curva de una batería de iones de
  litio en vez del contador de coulomb (que en esta placa no existe).

---

## 🚀 Del 25 de agosto al 2 de septiembre 2026 — el punto de partida

Cuatro días que montan casi todo lo que luego se ha ido puliendo. Es el registro grande que
presenta el soporte del Odin 3.

### Añadido

- 🚀 **Soporte de la AYN Odin 3 (chip SM8750 / GPU Adreno 830)** en el repositorio del sistema.
  Trae el fichero de descripción del dispositivo (panel, WiFi, mando) y **un arreglo para el
  fallo de la GPU** que reiniciaba el controlador y dejaba la pantalla en negro.
- **Audio, batería, menú rápido de Steam, rotación de pantalla, suspensión y sensores** como
  parte del paquete propio (no como parches sueltos).
- **Suspensión falsa** (apagar pantalla y poner el procesador en ahorro) como medida
  temporal: se evita un cuelgue que se atribuía al hardware y **más tarde se confirmó que la
  premisa era falsa** (lo que cuelga es la suspensión profunda, no la normal) — se resolvió
  con la suspensión real el 11/09.
- **Cuidado automático del panel OLED** y **arreglo de la traducción de programas de PC**
  (FEX).
- **Cuaderno de ideas** (`IDEAS.md`) con lo que queda por plantear.
- Se integran los ficheros de configuración **reales de Android** para los sensores (los que
  trae la consola de fábrica) en el servicio de sensores.
- Se corrige la **ruta del firmware de audio y procesador** en la descripción del dispositivo,
  y se empieza con el **núcleo 7.1.0** (que luego resultó no servir: el bueno es el 7.2).
- **Controlador del mando por cable del Odin 3** (portado a la versión 7.2): sin él, el
  mando no se detectaba.

### Corregido / solucionado

- ✅ **Pantalla negra al cambiar de sesión**: documentado y resuelto (era la ruta que usaba
  la capa de pantallas).

### Cambiado / notas

- ⚠️ **Problema abierto desde el día 1**: Ajustes → Pantalla no ve el monitor en el escritorio
  (se resolvió el 11/09 installando el paquete que faltaba).
- Ajustes de sesión para el sonido, el control de ficheros abiertos, el mapeo de mandos y
  la red (WiFi).
