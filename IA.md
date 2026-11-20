# Declaración de Uso de Asistentes de IA (IA.md)

Para el desarrollo del proyecto se consultaron herramientas de asistencia basada en IA: **DeepSeek** y **Gemini**.

## Herramientas y Propósito de Uso

* **DeepSeek:** Se utilizó como apoyo en la definición y directrices iniciales de los tipos de datos algebraicos del dominio (`Motor.Tipos`), particularmente en el modelado de la variante con tipos como `Objeto` (campo `daLuz :: Bool`) y `Sala` (campo `esOscura :: Bool`), así como en el diseño de representaciones intermedias como `SalaCruda` para la lectura por bloques en `Motor.Mundo`.
* **Gemini:** Se utilizó para consultar estrategias en el módulo de persistencia (`Motor.Persistencia`), evaluando el manejo seguro de excepciones de entrada/salida (`IOException`) al guardar y el uso de `reads` para validar la integridad de partidas, tambien para estructurar el maquetado y diseño modular de la suite de pruebas con HUnit (`test/`), organizando los casos de prueba requeridos para el reconocedor, la semántica del mundo, los comandos y las dinámicas del núcleo.

## Sugerencias Rechazadas o Corregidas

1. **Uso de librerías externas o mónadas complejas para parsing:** Una sugerencia inicial propuso usar `Parsec` o encapsular el reconocedor en un transformador monádico (`StateT`). Fue rechazada para apegarse estrictamente a las restricciones del enunciado, implementando combinadores propios y directos sobre `ReadS`.
2. **Serialización parcial del estado en persistencia:** Se propuso guardar un formato textual personalizado que almacenara solo los identificadores modificados. Se descartó en favor de guardar el `Estado` completo derivando `Show`/`Read`, lo que permitió validar de forma directa si una partida pertenece a otro mundo comparando `mundoActual`.
3. **Manejo de salidas bloqueadas mediante mutación de estado:** Una sugerencia planteaba guardar un conjunto de salidas desbloqueadas en el `Estado` para que no volvieran a solicitar el objeto tras cruzarlas una vez. Fue rechazada para mantener el `Estado` simple y evaluar el requisito en cada intento de cruce, modelando adecuadamente llaves o carnets que deben portarse continuamente.
