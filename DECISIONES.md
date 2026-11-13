# Decisiones de Arquitectura (ADR)

## D1. Representación del mundo e identificadores

* **Contexto:** El motor debe representar salas, objetos, salidas y metas garantizando que salas y objetos tengan espacios de nombres separados y evitando duplicados en direcciones o identificadores durante la validación y ejecución. Además, se requiere un acceso eficiente durante la partida.
* **Opciones:** 
  1. Usar alias de tipo (`type IdSala = String`) y listas de asociación (`[(IdSala, Sala)]`).
  2. Usar envoltorios `newtype` (`IdSala` e `IdObjeto`) y mapas balanceados (`Data.Map.Strict`) del paquete permitido `containers`.
* **Decisión:** Elegimos la opción 2 (`newtype` junto con `Data.Map.Strict`), definida en el módulo `Motor.Tipos`.
* **Consecuencias:** 
  * *Ganamos:* Seguridad estática en tiempo de compilación sin costo en ejecución (el compilador impide comparar o mezclar un `IdSala` con un `IdObjeto`) y unicidad de claves garantizada por construcción en las salidas de cada `Sala` (`Map.Map Direccion Salida`).
  * *Perdimos:* Un poco más de verbosidad al envolver y desenvolver los constructores (`IdSala` / `unIdSala`) y la necesidad de derivar `Ord` para las claves. Además, el tipo `Map` por sí solo no garantiza invariantes globales como que el destino de una `Salida` exista en el `Mundo` (eso sigue delegándose a la fase de validación en `Motor.Mundo`).

  ---

## D2. Representación del estado de la partida (`Estado`)

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

* **Contexto:** El proyecto prohíbe el uso de librerías externas de parsing (*Parsec*, *Megaparsec*, expresiones regulares, etc.) y exige construir reconocedores propios sobre `ReadS` para analizar las líneas del archivo de mundo (`SALIDA`, `META`, claves y valores). Además, el tipo `ReadS a` (`String -> [(a, String)]`) permite devolver múltiples derivaciones en caso de ambigüedad.
* **Opciones:**
  1. Construir todos los reconocedores (incluidos identificadores y espacios) mediante recursión con combinadores como `muchos`, generando todas las particiones de prefijos posibles y filtrando luego.
  2. Implementar los combinadores básicos sobre `ReadS` (`<|>`, `muchos`, `muchos1`, `cadena`, `satisfacer`), pero definir `identificador` y `espacios` usando `span` / `dropWhile` para consumir directamente la coincidencia máxima (*maximal munch*), exigiendo en `ejecutarReconocedor` que el resto de la cadena solo contenga espacios.
* **Decisión:** Se eligió la opción 2 en `Motor.Reconocedor`.
* **Consecuencias:**
  * *Ganamos:* Eliminamos la ambigüedad y el *backtracking* innecesario al leer identificadores y espacios, garantizando que líneas mal formadas o con basura al final sean rechazadas con precisión para reportar errores V1.
  * *Perdimos:* Los combinadores léxicos básicos (`identificador`, `espacios`) no generan múltiples derivaciones parciales como lo haría un parser, aunque esto no afecta la gramática del formato del mundo.

## D4. Modelado de la variante Oscuridad en los tipos y el reconocedor

* **Contexto:** La variante asignada (Oscuridad) introduce las claves opcionales `OSCURA: si` en las salas y `LUZ: si` en los objetos. El formato del archivo no especifica explícitamente qué ocurre si se escribe un valor distinto de `si` (como `OSCURA: no` o `OSCURA: tal_vez`).
* **Opciones:**
  1. Aceptar tanto `si` como `no` en el reconocedor y almacenar valores `Bool` (`True` para `si`, `False` para `no` o ausencia).
  2. Restringir el reconocedor `booleanoSi` en `Motor.Reconocedor` para que acepte únicamente la cadena exacta `"si"` (tratando ausencia de la clave como `False` por defecto en `Sala` y `Objeto`), rechazando cualquier otro valor como error de sintaxis V1.
* **Decisión:** Se eligió la opción 2.
* **Consecuencias:**
  * *Ganamos:* Cumplimiento estricto con la especificación de la Sección 7 (que solo define `OSCURA: si` y `LUZ: si`), detectando errores tipográficos en los archivos de mundo durante la validación sintáctica.
  * *Perdimos:* Un archivo de mundo que escriba explícitamente `OSCURA: no` será rechazado como inválido en lugar de interpretarse como sala iluminada.

## D5. Cómo se lee el archivo de mundo: por bloques

* **Contexto:** El archivo es una lista de líneas, pero cada trozo describe algo distinto (cabecera, objeto o sala) y las validaciones se hacen sobre cosas completas: una sala sin `DESC`, un campo repetido, un objeto duplicado. Además, los errores de sintaxis tienen que decir el número de línea del archivo original, así que ese número no se podía perder en el camino
* **Opciones:**
  1. Leer línea por línea recordando en qué bloque se está (una especie de "ahora estoy dentro de una sala")
  2. Numerar todas las líneas, partir el texto en bloques en cada línea `---` y procesar cada bloque por separado
* **Decisión:** Elegimos la opción 2 en `Motor.Mundo`. `lineasUtiles` numera primero y filtra después (vacías y comentarios), y `bloques` corta en cada separador acumulando las líneas al revés y dándolas vuelta con `invertir` al cerrar el bloque. Si aparecen dos `---` seguidos, el bloque vacío se descarta
* **Consecuencias:**
  * *Ganamos:* Cada bloque se revisa completo e independiente, así que detectar campos faltantes o repetidos es directo. Al numerar antes de filtrar, el número de línea de los errores V1 es el real
  * *Perdimos:* Un recorrido más sobre el texto y un tipo intermedio (`[[(Int, String)]]`). Además, los `---` repetidos no se reportan como error, simplemente se ignoran

---

## D6. Cómo reportar todos los errores y no solo el primero

* **Contexto:** El enunciado nos exige reportar todos los errores juntos. Nuestras funciones de lectura devuelven `Either [ErrorMundo] a`, y lo natural sería encadenarlas con `do`
* **Opciones:**
  1. Encadenar con `do` sobre `Either`, pero en cuanto una parte da `Left`, el resto no se evalúa, igual que `Nothing` en `Maybe`, y solo se vería el primer error
  2. Definir un combinador propio `<+>` que, si los dos lados fallan, junta sus listas de errores, y `todas` para convertir una lista de resultados en un resultado de lista
* **Decisión:** Elegimos la opción 2. `leerCabecera`, `leerObjeto` y `leerSala` arman el resultado con `Right (\...) <+> campo1 <+> campo2 ...`, y `conErrores` agrega los errores de las líneas mal formadas a los del bloque
* **Consecuencias:**
  * *Ganamos:* Un bloque con dos fallos distintos como una clave desconocida y un `DESC` faltante, reporta los dos
  * *Perdimos:* No podemos usar notación `do` para esto y hubo que escribir `<+>` a mano, los errores no salen ordenados por línea: `verificar` va primero dentro de cada bloque

---

## D7. Validar sobre listas y armar los `Map` al final

* **Contexto:** `Mundo` guarda salas y objetos en `Map`, pero `Map.fromList` con una clave repetida se queda con la última sin avisar. Eso escondería los errores v2, v5 y v7. De ahí que el diseño por sí solo no asegure que las claves sean únicas, como decía D1 antes de la validación
* **Opciones:**
  1. Construir los `Map` apenas se lee cada bloque y revisar duplicados después
  2. Leer los bloques a tipos intermedios con listas (`SalaCruda`, con `crSalidas :: [(Direccion, Salida)]`), validar todo sobre esas listas y armar los `Map` solo al final, cuando no hubo errores
* **Decisión:** Elegimos la opción 2 en `Motor.Mundo`. `validar` detecta los duplicados con `repetidos` sobre las listas y solo si no hay errores construye el `Mundo` con `Map.fromList`
* **Consecuencias:**
  * *Ganamos:* Los duplicados se detectan antes de que el `Map` los esconda, y el `Mundo` que sale de `leerMundo` ya está validado.
  * *Perdimos:* Dos representaciones de la sala (`SalaCruda` y `Sala`) y cierta repetición. Además, `elem` sobre listas es más lento que consultar un `Map`, lo cual no importa con mundos pequeños

---

## D8. Qué pasa cuando hay errores de sintaxis

* **Contexto:** Si el archivo tiene errores v1, los datos que se leyeron pueden estar incompletos como una sala sin `DESC`, una salida mal escrita que no llega a la lista. Validar v2 a v10 sobre eso daría errores falsos
* **Opciones:**
  1. Validar siempre y mezclar todos los errores
  2. Si hay algún error v1, devolverlo y no intentar validar lo demás (el enunciado lo permite)
* **Decisión:** Elegimos la opción 2. En `leerMundo`, la cabecera y todos los bloques se combinan con `<+>`, y `validar` solo se llama si todo salió `Right`
* **Consecuencias:**
  * *Ganamos:* Los errores V1 reportados son confiables y no se mezclan con errores semánticos que son consecuencia de ellos
  * *Perdimos:* Quien arregle los errores de sintaxis tendrá que correr el motor otra vez para ver los de v2 a v10. Una sola línea mal escrita también puede traer un error extra de su bloque 

---

## D9. Cómo contamos V8, V9 y V10

* **Contexto:** Un mismo problema puede dar varios errores. Si la meta nombra un objeto que no existe, ese objeto también "es necesario pero no está en ninguna sala". Si `INICIO` no existe, todas las salas serían no alcanzables. Eso llenaría el reporte de ruido y no coincidiría con los nueve errores que declara `invalido_semantica.txt`
* **Opciones:**
  1. Reportar v8, v9 y v10 siempre, aunque se repitan
  2. Reportar v10 solo para objetos que sí existen y v9 solo si `INICIO` existe, de modo que cada problema se reporte una vez, en su error más específico
* **Decisión:** Elegimos la opción 2 en `validar`. v10 usa `elem ob oids` para filtrar, y v9 solo se calcula si `elem ini sids`. Con esos criterios `invalido_semantica.txt` da los nueve errores 
* **Consecuencias:**
  * *Ganamos:* Mensajes sin repetidos, un error por problema real
  * *Perdimos:* Si se corrige v8 y el objeto sigue sin colocarse en una sala, v10 aparece recién en la corrida siguiente