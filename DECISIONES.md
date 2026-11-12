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