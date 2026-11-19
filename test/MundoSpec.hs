module MundoSpec (pruebasMundo) where

import qualified Data.Map.Strict as Map
import Data.List (sort)
import Data.Maybe (isJust, mapMaybe)
import Common (conMundoInvalido, conMundoValido, conTextoValido, tieneError)
import Motor.Mundo (leerMundo)
import Motor.Tipos
  ( ErrorMundo (..)
  , IdObjeto (..)
  , IdSala (..)
  , Meta (..)
  , Mundo (..)
  , Objeto (..)
  , Sala (..)
  , Salida (..)
  )
import Test.HUnit

-- Reúne los casos de lectura y validación de mundos.
pruebasMundo :: Test
pruebasMundo =
  TestList
    [ pruebaMundoEntrega
    , pruebaMundoPropio
    , pruebaInvalidoSemantica
    , pruebaInvalidoSintaxis
    , pruebaDuplicados
    , pruebaImposible
    , pruebaSintaxisOscuridad
    , pruebaComentariosYVacios
    ]

-- El mundo de ejemplo debe leerse sin errores y conservar su título, sus
-- salas, sus objetos y su meta.
pruebaMundoEntrega :: Test
pruebaMundoEntrega = TestLabel "mundos/entrega.txt" $ TestCase $
  conMundoValido "mundos/entrega.txt" $ \m -> do
    assertEqual "título" "Entrega a última hora" (titulo m)
    assertEqual "cantidad de salas" 9 (Map.size (salas m))
    assertEqual "cantidad de objetos" 5 (Map.size (objetos m))
    assertEqual "meta"
      (LlevarA (IdObjeto "proyecto_impreso") (IdSala "oficina_del_profesor"))
      (meta m)

-- El mundo propio debe leerse sin errores y conservar los elementos de la
-- variante: salas oscuras, un objeto que da luz y salidas con requisito.
pruebaMundoPropio :: Test
pruebaMundoPropio = TestLabel "mundos/mundo.txt" $ TestCase $
  conMundoValido "mundos/mundo.txt" $ \m -> do
    let listaSalas = Map.elems (salas m)
        listaObjetos = Map.elems (objetos m)
        todasLasSalidas = concatMap (Map.elems . salidas) listaSalas
        conRequisito = filter (isJust . requisito) todasLasSalidas

    assertEqual "cantidad de objetos" 6 (length listaObjetos)
    assertBool "al menos 8 salas" (length listaSalas >= 8)
    assertEqual "salidas con requisito" 2 (length conRequisito)
    assertBool "al menos una sala oscura" (any esOscura listaSalas)
    assertBool "al menos un objeto que da luz" (any daLuz listaObjetos)

-- Un mundo con errores semánticos debe devolver exactamente esos errores y
-- ninguno de sintaxis.
pruebaInvalidoSemantica :: Test
pruebaInvalidoSemantica = TestLabel "mundos/invalido_semantica.txt" $ TestCase $
  conMundoInvalido "mundos/invalido_semantica.txt" $ \es -> do
    assertEqual "cantidad de errores" 9 (length es)
    assertBool "todos los errores son de validación" (all esValidacion es)

-- Distingue los errores que describen una incoherencia del mundo de los que
-- describen una línea mal escrita.
esValidacion :: ErrorMundo -> Bool
esValidacion (ErrorValidacion _) = True
esValidacion (ErrorSintaxis _ _) = False

-- Un mundo con líneas mal escritas debe devolver exactamente esos errores y
-- ninguno de validación.
pruebaInvalidoSintaxis :: Test
pruebaInvalidoSintaxis = TestLabel "mundos/invalido_sintaxis.txt" $ TestCase $
  conMundoInvalido "mundos/invalido_sintaxis.txt" $ \es -> do
    assertEqual "cantidad de errores" 4 (length es)
    assertBool "todos los errores son de sintaxis" (all esSintaxis es)

-- Indica si un error corresponde a una línea mal escrita e incluye el número
-- de línea donde apareció.
esSintaxis :: ErrorMundo -> Bool
esSintaxis (ErrorSintaxis _ _) = True
esSintaxis (ErrorValidacion _) = False

-- Un mundo con definiciones repetidas debe reportar las salas duplicadas, las
-- salidas repetidas, los objetos inexistentes y los objetos colocados dos veces.
pruebaDuplicados :: Test
pruebaDuplicados = TestLabel "mundos/invalidos/duplicados.txt" $ TestCase $
  conMundoInvalido "mundos/invalidos/duplicados.txt" $ \es -> do
    assertEqual "cantidad de errores" 4 (length es)
    assertBool "sala definida más de una vez"
      (tieneError "la sala cuarto está definida más de una vez" es)
    assertBool "salidas repetidas en la misma dirección"
      (tieneError "la sala pasillo tiene dos salidas al norte" es)
    assertBool "objeto inexistente dentro de una sala"
      (tieneError "el objeto fantasma, que no está definido" es)
    assertBool "objeto colocado más de una vez"
      (tieneError "el objeto vela está colocado más de una vez" es)

-- Un mundo sin forma de cumplir la meta debe reportar el requisito inexistente,
-- la meta mal referida, la sala inalcanzable y los objetos que faltan.
pruebaImposible :: Test
pruebaImposible = TestLabel "mundos/invalidos/imposible.txt" $ TestCase $
  conMundoInvalido "mundos/invalidos/imposible.txt" $ \es -> do
    assertEqual "cantidad de errores" 5 (length es)
    assertBool "requisito inexistente"
      (tieneError "requiere el objeto llave_magica, que no existe" es)
    assertBool "meta hacia una sala inexistente"
      (tieneError "META nombra una sala que no existe: boveda" es)
    assertBool "sala inalcanzable"
      (tieneError "la sala sotano no es alcanzable desde INICIO" es)
    assertBool "objeto necesario fuera del mundo: tesoro"
      (tieneError "el objeto tesoro es necesario pero no está en ninguna sala" es)
    assertBool "objeto necesario fuera del mundo: pase"
      (tieneError "el objeto pase es necesario pero no está en ninguna sala" es)

-- Un mundo con valores inválidos de las claves de oscuridad debe reportar las
-- cuatro líneas afectadas.
pruebaSintaxisOscuridad :: Test
pruebaSintaxisOscuridad =
  TestLabel "mundos/invalidos/sintaxis_oscuridad.txt" $ TestCase $
    conMundoInvalido "mundos/invalidos/sintaxis_oscuridad.txt" $ \es -> do
      assertEqual "cantidad de errores" 4 (length es)
      assertEqual "líneas con error" [14, 18, 19, 20] (lineasConError es)
      assertBool "error en el valor de LUZ" (tieneError "LUZ" es)
      assertBool "error en el valor de OSCURA" (tieneError "OSCURA" es)

-- Extrae el número de línea de un error de sintaxis.
lineaDeError :: ErrorMundo -> Maybe Int
lineaDeError (ErrorSintaxis n _) = Just n
lineaDeError (ErrorValidacion _) = Nothing

-- Reúne y ordena las líneas señaladas por errores de sintaxis.
lineasConError :: [ErrorMundo] -> [Int]
lineasConError = sort . mapMaybe lineaDeError

-- Las líneas comentadas y las vacías no afectan la lectura, pero un texto sin
-- ninguna línea útil no alcanza a formar un mundo.
pruebaComentariosYVacios :: Test
pruebaComentariosYVacios = TestLabel "comentarios y líneas vacías" $ TestCase $ do
  conTextoValido textoMundo $ \m -> do
    assertEqual "título" "Mundo mínimo" (titulo m)
    assertEqual "cantidad de salas" 1 (Map.size (salas m))

  case leerMundo "" of
    Left es ->
      assertBool "el texto vacío produce un error de sintaxis" (any esSintaxis es)
    Right _ ->
      assertFailure "el texto vacío no debería producir un mundo"
  where
    textoMundo = unlines
      [ "# cabecera"
      , ""
      , "MUNDO: Mundo mínimo"
      , "INICIO: sala"
      , ""
      , "META: llegar a sala"
      , "# separador"
      , "---"
      , "SALA: sala"
      , "DESC: Una sala."
      , ""
      ]
