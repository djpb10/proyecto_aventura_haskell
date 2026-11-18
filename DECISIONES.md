# Decisiones de Arquitectura (ADR)

## D1. Representación del mundo e identificadores

* **Redactó:** David Pereira
* **Contexto:** El motor debe representar salas, objetos, salidas y metas garantizando que salas y objetos tengan espacios de nombres separados y evitando duplicados en direcciones o identificadores durante la validación y ejecución. Además, se requiere un acceso eficiente durante la partida.
* **Opciones:**
  1. Usar alias de tipo (`type IdSala = String`) y listas de asociación (`[(IdSala, Sala)]`).
  2. Usar envoltorios `newtype` (`IdSala` e `IdObjeto`) y mapas balanceados (`Data.Map.Strict`) del paquete permitido `containers`.
* **Decisión:** Elegimos la opción 2 (`newtype` junto con `Data.Map.Strict`), definida en el módulo `Motor.Tipos`.
* **Consecuencias:**
  * *Ganamos:* Seguridad estática en tiempo de compilación sin costo en ejecución (el compilador impide comparar o mezclar un `IdSala` con un `IdObjeto`) y unicidad de claves en las salidas de cada `Sala` (`Map.Map Direccion Salida`) una vez que el mundo pasa la validación. Los duplicados se detectan antes de armar el `Map`, como se explica en D7.
  * *Perdimos:* Un poco más de verbosidad al envolver y desenvolver los constructores (`IdSala` / `unIdSala`) y la necesidad de derivar `Ord` para las claves. Además, el tipo `Map` por sí solo no garantiza invariantes globales como que el destino de una `Salida` exista en el `Mundo` (eso sigue delegándose a la fase de validación en `Motor.Mundo`).

---

## D2. Representación del estado de la partida (`Estado`)

* **Redactó:** David Pereira
* **Contexto:** El núcleo del juego (`Motor.Nucleo`) debe ser puramente funcional e inmutable, recibiendo un `Estado` y devolviendo un nuevo `Estado`. Necesitábamos decidir cómo mantener los cambios dinámicos (movimiento del jugador, recolección y abandono de objetos) frente a los datos estáticos del mundo (descripciones, conexiones, oscuridad).
* **Opciones:**
  1. Almacenar dentro de `Estado` una copia modificable de toda la estructura `Mundo` (actualizando la lista `objetosInicial` dentro de cada `Sala` cada vez que se toma o suelta un objeto).
  2. Mantener la referencia inmutable al `Mundo` original y separar en campos independientes los datos mutables de la sesión: `ubicacion :: IdSala`, `inventario :: [IdObjeto]` y `objetosEnSalas :: Map.Map IdSala [IdObjeto]`.
* **Decisión:** Elegimos la opción 2 en el registro `Estado` dentro de `Motor.Tipos`.
* **Consecuencias:**
  * *Ganamos:* Separación clara entre la definición estática del mapa y el progreso del jugador. Evitamos reconstruir o mutar registros profundos dentro de `salas` al ejecutar `Tomar` o `Soltar`; basta con actualizar la lista asociada a `ubicacion` en `objetosEnSalas`.
  * *Perdimos:* Existe una ligera redundancia inicial al poblar `objetosEnSalas` a partir de `objetosInicial` en `estadoInicial`, y al guardar la partida (si se serializa todo el `Estado`) el archivo incluye la definición del `Mundo`.

---

## D3. Diseño del reconocedor sintáctico con combinadores propios

* **Redactó:** David Pereira
* **Contexto:** El proyecto prohíbe el uso de librerías externas de parsing (*Parsec*, *Megaparsec*, expresiones regulares, etc.) y exige construir reconocedores propios sobre `ReadS` para analizar las líneas del archivo de mundo (`SALIDA`, `META`, claves y valores). Además, el tipo `ReadS a` (`String -> [(a, String)]`) permite devolver múltiples derivaciones en caso de ambigüedad.
* **Opciones:**
  1. Construir todos los reconocedores (incluidos identificadores y espacios) mediante recursión con combinadores como `muchos`, generando todas las particiones de prefijos posibles y filtrando luego.
  2. Implementar los combinadores básicos sobre `ReadS` (`<|>`, `muchos`, `muchos1`, `cadena`, `satisfacer`), pero definir `identificador` y `espacios` usando `span` / `dropWhile` para consumir directamente la coincidencia máxima (*maximal munch*), exigiendo en `ejecutarReconocedor` que el resto de la cadena solo contenga espacios.
* **Decisión:** Se eligió la opción 2 en `Motor.Reconocedor`.
* **Consecuencias:**
  * *Ganamos:* Eliminamos la ambigüedad y el *backtracking* innecesario al leer identificadores y espacios, garantizando que líneas mal formadas o con basura al final sean rechazadas con precisión para reportar errores V1.
  * *Perdimos:* Los combinadores léxicos básicos (`identificador`, `espacios`) no generan múltiples derivaciones parciales como lo haría un parser, aunque esto no afecta la gramática del formato del mundo.

---

## D4. Modelado de la variante Oscuridad en los tipos y el reconocedor

* **Redactó:** David Pereira
* **Contexto:** La variante asignada (Oscuridad) introduce las claves opcionales `OSCURA: si` en las salas y `LUZ: si` en los objetos. El formato del archivo no especifica explícitamente qué ocurre si se escribe un valor distinto de `si` (como `OSCURA: no` o `OSCURA: tal_vez`).
* **Opciones:**
  1. Aceptar tanto `si` como `no` en el reconocedor y almacenar valores `Bool` (`True` para `si`, `False` para `no` o ausencia).
  2. Restringir el reconocedor `booleanoSi` en `Motor.Reconocedor` para que acepte únicamente la cadena exacta `"si"` (tratando ausencia de la clave como `False` por defecto en `Sala` y `Objeto`), rechazando cualquier otro valor como error de sintaxis V1.
* **Decisión:** Se eligió la opción 2.
* **Consecuencias:**
  * *Ganamos:* Cumplimiento estricto con la especificación de la Sección 7 (que solo define `OSCURA: si` y `LUZ: si`), detectando errores tipográficos en los archivos de mundo durante la validación sintáctica.
  * *Perdimos:* Un archivo de mundo que escriba explícitamente `OSCURA: no` será rechazado como inválido en lugar de interpretarse como sala iluminada.

---

## D5. Cómo se lee el archivo de mundo: por bloques

* **Redactó:** Rossana Ilardo
* **Contexto:** El archivo es una lista de líneas, pero cada trozo describe algo distinto (cabecera, objeto o sala) y las validaciones se hacen sobre cosas completas: una sala sin `DESC`, un campo repetido, un objeto duplicado. Además, los errores de sintaxis tienen que decir el número de línea del archivo original, así que ese número no se podía perder en el camino.
* **Opciones:**
  1. Leer línea por línea recordando en qué bloque se está (una especie de "ahora estoy dentro de una sala").
  2. Numerar todas las líneas, partir el texto en bloques en cada línea `---` y procesar cada bloque por separado.
* **Decisión:** Elegimos la opción 2 en `Motor.Mundo`. `lineasUtiles` numera primero y filtra después (vacías y comentarios), y `bloques` corta en cada separador acumulando las líneas al revés y dándolas vuelta con `invertir` al cerrar el bloque. Si aparecen dos `---` seguidos, el bloque vacío se descarta.
* **Consecuencias:**
  * *Ganamos:* Cada bloque se revisa completo e independiente, así que detectar campos faltantes o repetidos es directo. Al numerar antes de filtrar, el número de línea de los errores V1 es el real.
  * *Perdimos:* Un recorrido más sobre el texto y un tipo intermedio (`[[(Int, String)]]`). Además, los `---` repetidos no se reportan como error, simplemente se ignoran.

---

## D6. Cómo reportar todos los errores y no solo el primero

* **Redactó:** Rossana Ilardo
* **Contexto:** El enunciado exige reportar todos los errores juntos. Nuestras funciones de lectura devuelven `Either [ErrorMundo] a`, y lo natural sería encadenarlas con `do`.
* **Opciones:**
  1. Encadenar con `do` sobre `Either`. En cuanto una parte da `Left`, el resto no se evalúa, igual que `Nothing` en `Maybe`, y solo se vería el primer error.
  2. Definir un combinador propio `<+>` que, si los dos lados fallan, junta sus listas de errores, y `todas` para convertir una lista de resultados en un resultado de lista.
* **Decisión:** Elegimos la opción 2. `leerCabecera`, `leerObjeto` y `leerSala` arman el resultado con `Right (\...) <+> campo1 <+> campo2 ...`, y `conErrores` agrega los errores de las líneas mal formadas a los del bloque.
* **Consecuencias:**
  * *Ganamos:* Un bloque con dos fallos distintos (por ejemplo, una clave desconocida y un `DESC` faltante) reporta los dos.
  * *Perdimos:* No podemos usar notación `do` para esto y hubo que escribir `<+>` a mano. Además, los errores no salen ordenados por línea: `verificar` va primero dentro de cada bloque.

---

## D7. Validar sobre listas y armar los `Map` al final

* **Redactó:** Rossana Ilardo
* **Contexto:** `Mundo` guarda salas y objetos en `Map`, pero `Map.fromList` con una clave repetida se queda con la última sin avisar. Eso escondería los errores V2, V5 y V7, así que el `Map` por sí solo no asegura que las claves sean únicas.
* **Opciones:**
  1. Construir los `Map` apenas se lee cada bloque y revisar duplicados después.
  2. Leer los bloques a tipos intermedios con listas (`SalaCruda`, con `crSalidas :: [(Direccion, Salida)]`), validar todo sobre esas listas y armar los `Map` solo al final, cuando no hubo errores.
* **Decisión:** Elegimos la opción 2 en `Motor.Mundo`. `validar` detecta los duplicados con `repetidos` sobre las listas y solo si no hay errores construye el `Mundo` con `Map.fromList`.
* **Consecuencias:**
  * *Ganamos:* Los duplicados se detectan antes de que el `Map` los esconda, y el `Mundo` que sale de `leerMundo` ya está validado.
  * *Perdimos:* Dos representaciones de la sala (`SalaCruda` y `Sala`) y cierta repetición. Además, `elem` sobre listas es más lento que consultar un `Map`, lo cual no importa con mundos pequeños.

---

## D8. Qué pasa cuando hay errores de sintaxis

* **Redactó:** Rossana Ilardo
* **Contexto:** Si el archivo tiene errores V1, los datos que se leyeron pueden estar incompletos (una sala sin `DESC`, una salida mal escrita que no llega a la lista). Validar V2 a V10 sobre eso daría errores falsos.
* **Opciones:**
  1. Validar siempre y mezclar todos los errores.
  2. Si hay algún error V1, devolverlo y no intentar validar lo demás (el enunciado lo permite).
* **Decisión:** Elegimos la opción 2. En `leerMundo`, la cabecera y todos los bloques se combinan con `<+>`, y `validar` solo se llama si todo salió `Right`.
* **Consecuencias:**
  * *Ganamos:* Los errores V1 reportados son confiables y no se mezclan con errores semánticos que son consecuencia de ellos.
  * *Perdimos:* Quien arregle los errores de sintaxis tendrá que correr el motor otra vez para ver los de V2 a V10. Una sola línea mal escrita también puede traer un error extra de su bloque (por ejemplo, `falta el campo DESC` si el `DESC` era la línea rota).

---

## D9. Cómo contamos V8, V9 y V10

* **Redactó:** Rossana Ilardo
* **Contexto:** Un mismo problema puede dar varios errores. Si la meta nombra un objeto que no existe, ese objeto también "es necesario pero no está en ninguna sala". Si `INICIO` no existe, todas las salas serían no alcanzables. Eso llenaría el reporte de ruido y no coincidiría con los nueve errores que declara `invalido_semantica.txt`.
* **Opciones:**
  1. Reportar V8, V9 y V10 siempre, aunque se repitan.
  2. Reportar V10 solo para objetos que sí existen y V9 solo si `INICIO` existe, de modo que cada problema se reporte una vez, en su error más específico.
* **Decisión:** Elegimos la opción 2 en `validar`. V10 usa `elem ob oids` para filtrar, y V9 solo se calcula si `elem ini sids`. Con esos criterios `invalido_semantica.txt` da los nueve errores.
* **Consecuencias:**
  * *Ganamos:* Mensajes sin repetidos, un error por problema real.
  * *Perdimos:* Si se corrige V8 y el objeto sigue sin colocarse en una sala, V10 aparece recién en la corrida siguiente.

---

## D10. Normalización y tolerancia en la entrada de comandos del jugador

* **Redactó:** David Pereira
* **Contexto:** Durante una sesión de juego interactiva, los usuarios pueden ingresar comandos utilizando mayúsculas, espacios adicionales alrededor del texto, sinónimos naturales o abreviaturas comunes (por ejemplo, `IR norte`, `coger llave`, `inv`, `ir n`). Un parser excesivamente estricto deteriora la experiencia de uso.
* **Opciones:**
  1. Aceptar solo las formas que lista el enunciado (`ir <dirección>` con la dirección completa, `tomar`/`coger`, `inventario`/`inv`), sin artículos ni abreviaturas de dirección.
  2. Preprocesar la línea eliminando espacios externos (`trim`) y normalizando a minúsculas (`map toLower`), e incorporar mediante el combinador de elección (`<|>`) sinónimos explícitos (`coger`, `inv`, `x`), abreviaturas direccionales (`n`, `s`, `e`, `o`, `u`, `d`) y el descarte opcional de artículos (`el`, `la`, `los`, `las`) antes de los identificadores de objetos en `tomar`, `soltar` y `examinar`.
* **Decisión:** Se eligió la opción 2 en `Motor.Comandos`. Las abreviaturas de dirección solo se aceptan después de `ir` (`ir n`); las direcciones completas también valen solas (`norte`). Excepción: `guardar` y `cargar` se prueban antes de normalizar a minúsculas, para respetar el nombre del archivo (ver D15).
* **Consecuencias:**
  * *Ganamos:* Interacción mucho más natural y fluida para el jugador (admitiendo frases como `"tomar la llave"` o `"ir n"`), manteniendo intacta la representación interna del tipo algebraico `Comando`.
  * *Perdimos:* Mayor cantidad de reglas en el reconocedor sintáctico y la necesidad de asegurarse de que las abreviaturas no colisionen con identificadores o verbos completos.

---

## D11. Reconocimiento puro de comandos sobre combinadores `ReadS`

* **Redactó:** David Pereira
* **Contexto:** La arquitectura del motor exige mantener una separación estricta entre la lógica pura del juego y las operaciones de entrada/salida (`IO`), prohibiendo el uso de librerías externas de análisis sintáctico.
* **Opciones:**
  1. Dividir la entrada del usuario usando `words` y hacer coincidencia de patrones directamente sobre listas de `String`.
  2. Reutilizar la infraestructura de combinadores puros sobre `ReadS` construida en `Motor.Reconocedor` para exponer la función pura `leerComando :: String -> Maybe Comando`.
* **Decisión:** Se eligió la opción 2 en `Motor.Comandos`.
* **Consecuencias:**
  * *Ganamos:* Consistencia arquitectónica en todo el proyecto (mismo mecanismo de parsing para archivos de mundo y comandos de usuario), validación automática de que no quede texto residual sin consumir al final del comando (`ejecutarReconocedor`) y facilidad para realizar pruebas unitarias sin `IO`.
  * *Perdimos:* Requiere cuidar la aplicación parcial de los combinadores `ReadS` (combinar funciones antes de aplicar la cadena de entrada) al construir alternativas con `<|>`.

---

## D12. Reglas de visibilidad, iluminación y movimiento en la variante Oscuridad

* **Redactó:** David Pereira
* **Contexto:** La variante 0 (*Oscuridad*) establece que en una sala con `OSCURA: si`, si el jugador no lleva un objeto con `LUZ: si`, el comando `mirar` no muestra objetos ni salidas y no se puede tomar ni examinar nada de la sala.
* **Opciones:**
  1. Prohibir cualquier intento de movimiento (`ir`) desde una sala oscura sin luz y considerar iluminada la sala también si un objeto luminoso está tirado en el suelo.
  2. Exigir que el objeto con `LUZ: si` esté activamente en el `inventario` del jugador (`llevaObjetoConLuz`) para iluminar la sala, permitir `examinar` objetos que ya estén dentro del inventario, permitir `soltar` objetos (advirtiendo si la sala queda a oscuras) y permitir intentar moverse a ciegas (`ir <dirección>`), logrando cruzar solo si existe una salida válida en esa dirección y cumpliendo sus requisitos.
* **Decisión:** Se eligió la opción 2 en `Motor.Nucleo` (funciones `tieneLuz`, `describirSalaActual`, `moverJugador`, `tomarObjeto`, `soltarObjeto` y `examinarObjeto`). En una sala oscura sin luz, `mirar` solo muestra un mensaje de oscuridad: se oculta también la descripción de la sala, no solo los objetos y las salidas.
* **Consecuencias:**
  * *Ganamos:* Evita bloqueos irreversibles (*soft-locks*) si el jugador entra por accidente a una sala oscura sin linterna (puede retroceder por donde vino) y mantiene coherencia física al impedir tomar o examinar objetos del suelo sin visibilidad.
  * *Perdimos:* Un jugador que suelte su única fuente de luz dentro de una sala oscura no podrá volver a verla para recogerla, por lo que debe salir; se mitigó emitiendo una advertencia explícita en `soltarObjeto`.

---

## D13. Persistencia del requisito en salidas bloqueadas tras cruzarlas

* **Redactó:** David Pereira
* **Contexto:** Una salida declarada con `requiere <objeto>` solo puede cruzarse si el jugador lleva dicho objeto en su inventario.
* **Opciones:**
  1. Agregar un conjunto de salidas desbloqueadas (`Set (IdSala, Direccion)`) dentro de `Estado` para que, una vez cruzada, no vuelva a pedir el objeto.
  2. Mantener la evaluación sin estado adicional en `moverJugador`: cada vez que se intenta cruzar una salida con `requisito = Just reqId`, se verifica `elem reqId (inventario est)` sin consumir el objeto ni alterar el mapa estático `Mundo`.
* **Decisión:** Se eligió la opción 2 en `Motor.Nucleo` (`moverJugador`).
* **Consecuencias:**
  * *Ganamos:* El tipo `Estado` se mantiene minimalista (almacenando únicamente `mundoActual`, `ubicacion`, `inventario` y `objetosEnSalas`), evita duplicar información topológica del grafo del mundo y modela casos donde el requisito es una credencial o pase que se muestra en cada acceso (como `carnet` en `mundos/entrega.txt`).
  * *Perdimos:* Si el jugador suelta el objeto requerido tras cruzar la puerta, no podrá volver a cruzarla en sentido contrario a menos que recupere el objeto.

---

## D14. Detección pura de victoria y separación de comandos de E/S en el núcleo

* **Redactó:** David Pereira
* **Contexto:** Se exige que `Motor.Nucleo` sea 100% puro (sin `IO`) y exponga `ejecutar :: Comando -> Estado -> ([String], Estado)`, mientras que los comandos `Guardar`, `Cargar` y `Salir` requieren interacción con archivos o finalización del bucle en `Main.hs`. Asimismo, la victoria (`*** ¡Has ganado! ***`) puede producirse al entrar en una sala (`LlegarA`) o al recoger un objeto estando en la sala meta (`LlevarA`).
* **Opciones:**
  1. Añadir un campo booleano `terminado :: Bool` dentro de `Estado` y dejar que `Guardar`/`Cargar` lancen un error si llegan al núcleo.
  2. Mantener `Estado` libre de banderas de control de bucle, exportar el predicado puro `haGanado :: Estado -> Bool` evaluado mediante `verificarVictoria` al final de `moverJugador` y `tomarObjeto`, y manejar todos los constructores de `Comando` de forma total en `ejecutar` (devolviendo mensajes neutros para `Guardar`/`Cargar` que serán interceptados por `Main.hs`).
* **Decisión:** Se eligió la opción 2 en `Motor.Nucleo` (`ejecutar`, `haGanado` y `verificarVictoria`).
* **Consecuencias:**
  * *Ganamos:* Totalidad garantizada en el *pattern matching* de `ejecutar` (cero funciones parciales ni excepciones en tiempo de ejecución), serialización más limpia de `Estado` para `Motor.Persistencia` y verificación automática de victoria tanto si el jugador llega con el objeto como si entra primero a la sala meta y recoge allí el objeto.
  * *Perdimos:* El bucle principal en `app/Main.hs` debe inspeccionar explícitamente `cmd == Salir` y `haGanado nuevoEstado` para detener la ejecución y manejar `Guardar`/`Cargar` antes o junto con `ejecutar`.

---

## D15. Nombres de archivo en guardar y cargar

* **Redactó:** Rossana Ilardo
* **Contexto:** `guardar` y `cargar` reciben un nombre de archivo. La primera versión lo leía con `identificador`, que solo admite minúsculas, dígitos y `_`, así que `guardar partida.txt` daba `Nothing`. Además `leerComando` pasaba toda la línea a minúsculas, y `guardar Partida` guardaba como `partida`. Lo detectamos probando en ghci.
* **Opciones:**
  1. Dejar `identificador` y pedirle al jugador nombres de archivo sin punto y en minúsculas.
  2. Leer el nombre con un reconocedor propio, `nombreArchivo` (cualquier cosa sin espacios), y probar `guardar` y `cargar` antes de pasar la línea a minúsculas.
* **Decisión:** Elegimos la opción 2 en `Motor.Comandos`. `leerComando` intenta primero `cmdGuardar <|> cmdCargar` sobre la línea recortada; si no calza, prueba el resto de comandos sobre la línea en minúsculas.
* **Consecuencias:**
  * *Ganamos:* Se aceptan nombres como `p.sav` o `Partida.txt`, respetando mayúsculas.
  * *Perdimos:* El verbo de `guardar` y `cargar` ya no se normaliza, así que `GUARDAR x` no se reconoce. Tampoco se admiten nombres con espacios.

---

## D16. Formato de las partidas guardadas

* **Redactó:** Rossana Ilardo
* **Contexto:** `guardar` y `cargar` tienen que escribir y recuperar el estado, y el enunciado exige que, si el archivo no existe, está corrupto o es de otro mundo, el programa lo informe y siga.
* **Opciones:**
  1. Guardar solo lo que cambia (ubicación, inventario y objetos por sala) en un formato propio.
  2. Guardar el `Estado` completo con `show` y recuperarlo con `reads`, que `Estado` ya deriva.
* **Decisión:** Elegimos la opción 2 en `Motor.Persistencia`. `cargarPartida` acepta el archivo solo si `reads` da una única lectura sin texto sobrante, y si el `mundoActual` guardado es igual (`==`) al del juego en curso. `guardarPartida` atrapa `IOException` con `try`.
* **Consecuencias:**
  * *Ganamos:* No hay que escribir ningún formato a mano, y la comparación de mundos detecta una partida de otro mundo, o del mismo mundo si el archivo cambió después de guardar.
  * *Perdimos:* El archivo repite el mundo completo en cada partida. Si el archivo de mundo cambia aunque sea una descripción, las partidas viejas se rechazan. Un archivo `.sav` es difícil de leer a ojo.

---

## D17. Entrada redirigida y fin de la entrada

* **Redactó:** Rossana Ilardo
* **Contexto:** El programa debe funcionar con `aventura mundo.txt < guion.txt` y terminar normalmente al acabarse la entrada, sin excepciones.
* **Opciones:**
  1. Leer toda la entrada de una vez con `getContents` y procesar sus líneas.
  2. Leer una línea por vuelta con `getLine`, preguntando antes con `isEOF` si queda entrada.
* **Decisión:** Elegimos la opción 2 en `bucle` (`app/Main.hs`). Si `isEOF` da `True`, imprime un salto de línea y sale con código 0. El bucle es recursión: se llama con el estado nuevo. `Salir` y la victoria terminan con `exitSuccess`. `Guardar` y `Cargar` los maneja `Main` y no `ejecutar`, siguiendo D14.
* **Consecuencias:**
  * *Ganamos:* Sin `isEOF`, `getLine` lanzaría una excepción al final del archivo redirigido. El indicador `> ` se muestra antes de cada lectura y la sesión interactiva funciona igual.
  * *Perdimos:* La victoria se detecta buscando el texto `*** ¡Has ganado! ***` entre los mensajes de `ejecutar`, en lugar de usar el predicado `haGanado` que exporta el núcleo. Funciona, pero depende del texto del mensaje.

---

## D18. Codificación de texto

* **Redactó:** Rossana Ilardo
* **Contexto:** Los archivos de mundo están en UTF-8 y tienen tildes. En Windows, `readFile` usa por defecto la codificación de la consola y las tildes salían como otros caracteres (`\9500\9553ltima`).
* **Opciones:**
  1. Dejar la codificación por defecto y pedir al usuario que configure su sistema.
  2. Fijar UTF-8 al arrancar `main` con `setLocaleEncoding utf8` y `hSetEncoding` sobre `stdin` y `stdout`.
* **Decisión:** Elegimos la opción 2 en `Main`.
* **Consecuencias:**
  * *Ganamos:* La lectura y escritura de archivos y de consola es la misma en cualquier sistema.
  * *Perdimos:* Una consola de Windows que no esté en UTF-8 muestra las tildes raras aunque el programa escriba bien. Se resuelve configurando la consola, sin tocar el código.

---

## D19. Mundo propio: cómo importa la oscuridad

* **Redactó:** Rossana Ilardo
* **Contexto:** El enunciado pide que la variante importe para ganar en `mundos/mundo.txt`.
* **Opciones:**
  1. Una sala oscura decorativa, que se pueda ignorar.
  2. Poner la llave que abre la salida bloqueada dentro de una sala oscura (`archivo`), de modo que sin la linterna no se pueda tomar.
* **Decisión:** Elegimos la opción 2. La llave está en `archivo` (oscura), la escalera requiere la llave, y la meta (`llevar informe a sala_servidores`) está después de la escalera, además de otra salida que requiere el carnet. Comprobamos que sin linterna `tomar llave_servidores` responde que está demasiado oscuro.
* **Consecuencias:**
  * *Ganamos:* La linterna es obligatoria para ganar, y `guiones/mundo.txt` lo demuestra.
  * *Perdimos:* Si el jugador suelta la linterna en una sala oscura no puede recogerla, como dice D12. El mundo tiene salida, pero el jugador puede dejarse sin luz por su cuenta.