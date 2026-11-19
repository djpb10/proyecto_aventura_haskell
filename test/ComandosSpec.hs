module ComandosSpec (pruebasComandos) where

import Motor.Comandos (leerComando)
import Motor.Tipos
  ( Comando (..)
  , Direccion (..)
  , IdObjeto (..)
  )
import Test.HUnit

-- Reúne los casos de interpretación de comandos.
pruebasComandos :: Test
pruebasComandos =
  TestList
    [ pruebaComandosExactos
    , pruebaSinonimos
    , pruebaDirecciones
    , pruebaArticulosYEspacios
    , pruebaGuardarCargar
    , pruebaInvalidos
    , pruebaBasuraFinal
    ]

-- Cada comando escrito en su forma completa se traduce al constructor que le
-- corresponde.
pruebaComandosExactos :: Test
pruebaComandosExactos = TestLabel "comandos exactos" $ TestCase $
  mapM_ comprobarComando
    [ ("ir norte", Ir Norte)
    , ("mirar", Mirar)
    , ("tomar llave", Tomar (IdObjeto "llave"))
    , ("soltar llave", Soltar (IdObjeto "llave"))
    , ("examinar llave", Examinar (IdObjeto "llave"))
    , ("inventario", Inventario)
    , ("guardar partida.txt", Guardar "partida.txt")
    , ("cargar partida.txt", Cargar "partida.txt")
    , ("ayuda", Ayuda)
    , ("salir", Salir)
    ]

-- Las formas alternativas de cada comando producen el mismo constructor que la
-- forma principal.
pruebaSinonimos :: Test
pruebaSinonimos = TestLabel "sinónimos" $ TestCase $
  mapM_ comprobarComando
    [ ("coger llave", Tomar (IdObjeto "llave"))
    , ("dejar llave", Soltar (IdObjeto "llave"))
    , ("x llave", Examinar (IdObjeto "llave"))
    , ("inv", Inventario)
    , ("help", Ayuda)
    , ("exit", Salir)
    , ("q", Salir)
    , ("mover norte", Ir Norte)
    , ("recuperar p.sav", Cargar "p.sav")
    ]

-- Las direcciones se aceptan después de "ir" en forma completa o abreviada,
-- y también solas cuando se escriben completas. Una abreviatura suelta no
-- basta para producir un movimiento.
pruebaDirecciones :: Test
pruebaDirecciones = TestLabel "direcciones" $ TestCase $ do
  mapM_ comprobarComando
    [ ("ir n", Ir Norte)
    , ("ir s", Ir Sur)
    , ("ir e", Ir Este)
    , ("ir o", Ir Oeste)
    , ("ir u", Ir Arriba)
    , ("ir d", Ir Abajo)
    , ("norte", Ir Norte)
    , ("sur", Ir Sur)
    , ("este", Ir Este)
    , ("oeste", Ir Oeste)
    , ("arriba", Ir Arriba)
    , ("abajo", Ir Abajo)
    ]
  mapM_ comprobarRechazo ["n", "s", "e", "o", "u", "d"]

-- Los comandos ignoran mayúsculas y espacios sobrantes, y los comandos con
-- objeto aceptan un artículo antes del nombre.
pruebaArticulosYEspacios :: Test
pruebaArticulosYEspacios =
  TestLabel "artículos, mayúsculas y espacios" $ TestCase $
    mapM_ comprobarComando
      [ ("  TOMAR LA llave  ", Tomar (IdObjeto "llave"))
      , ("coger las llaves", Tomar (IdObjeto "llaves"))
      , ("X el carnet", Examinar (IdObjeto "carnet"))
      , ("  MIRAR  ", Mirar)
      ]

-- El nombre de archivo de guardar y cargar conserva mayúsculas y puntos, y
-- ambos comandos exigen un nombre.
pruebaGuardarCargar :: Test
pruebaGuardarCargar = TestLabel "guardar y cargar" $ TestCase $ do
  mapM_ comprobarComando
    [ ("guardar Partida.txt", Guardar "Partida.txt")
    , ("cargar p.sav", Cargar "p.sav")
    ]
  comprobarRechazo "guardar"
  comprobarRechazo "cargar"

-- Entradas vacías, palabras desconocidas, comandos incompletos o comandos con
-- texto sobrante no producen ningún comando.
pruebaInvalidos :: Test
pruebaInvalidos = TestLabel "comandos inválidos" $ TestCase $
  mapM_ comprobarRechazo
    [ ""
    , "volar"
    , "ir"
    , "tomar"
    , "tomar la"
    , "ir nortex"
    , "inventarios"
    ]

-- Un comando reconocido no admite texto adicional después de sus argumentos.
pruebaBasuraFinal :: Test
pruebaBasuraFinal = TestLabel "texto sobrante" $ TestCase $
  mapM_ comprobarRechazo
    [ "mirar ahora"
    , "salir ya"
    , "ir norte por favor"
    ]

-- Comprueba que una entrada produce el comando esperado.
comprobarComando :: (String, Comando) -> Assertion
comprobarComando (entrada, esperado) =
  assertEqual ("reconoce " ++ entrada) (Just esperado) (leerComando entrada)

-- Comprueba que una entrada no produce ningún comando.
comprobarRechazo :: String -> Assertion
comprobarRechazo entrada =
  assertEqual ("no reconoce " ++ entrada) Nothing (leerComando entrada)
