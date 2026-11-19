module NucleoSpec (pruebasNucleo) where

import Data.Char (isSpace)
import Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import Common (conMundoValido, conTextoValido)
import Motor.Comandos (leerComando)
import Motor.Nucleo (ejecutar, estadoInicial, haGanado)
import Motor.Tipos
  ( Comando (..)
  , Direccion (..)
  , Estado (..)
  , IdObjeto (..)
  , IdSala (..)
  , Mundo (..)
  , Sala (..)
  )
import Test.HUnit

-- Reúne los casos de dinámica del juego.
pruebasNucleo :: Test
pruebasNucleo =
  TestList
    [ pruebaEstadoInicial
    , pruebaPartidaEntrega
    , pruebaPartidaMundo
    , pruebaMirarOscuro
    , pruebaTomarExaminarOscuro
    , pruebaMoverseOscuro
    , pruebaSalidaBloqueada
    , pruebaRequisitoPersistente
    , pruebaVictoriaLlegar
    , pruebaVictoriaLlevar
    , pruebaTomarSoltar
    , pruebaComandosNeutros
    ]

mensajeVictoria :: String
mensajeVictoria = "*** ¡Has ganado! ***"

mensajeOscuridad :: String
mensajeOscuridad = "Está completamente oscuro. No puedes ver nada a tu alrededor."

-- Aplica una lista de comandos en orden y acumula todos los mensajes.
correr :: Estado -> [Comando] -> ([String], Estado)
correr est comandos = foldl paso ([], est) comandos
  where
    paso (msgs, actual) cmd =
      let (nuevos, siguiente) = ejecutar cmd actual
      in (msgs ++ nuevos, siguiente)

-- Lee un guion con un comando por línea. Si alguna línea no se reconoce,
-- falla el caso en lugar de omitirla.
cargarGuion :: FilePath -> IO [Comando]
cargarGuion ruta = do
  texto <- readFile ruta
  let entradas = filter (not . all isSpace) (lines texto)
  case traverse leerComando entradas of
    Just cs -> return cs
    Nothing -> do
      assertFailure ("el guion " ++ ruta ++ " contiene un comando no reconocido")
      return []

-- Mundo con una entrada iluminada, una cueva oscura y una salida, una linterna
-- que da luz y una llave que está en la cueva.
mundoOscuro :: String
mundoOscuro = unlines
  [ "MUNDO: Prueba de oscuridad"
  , "INICIO: entrada"
  , "META: llegar a salida"
  , "---"
  , "OBJETO: linterna"
  , "DESC: Una linterna."
  , "LUZ: si"
  , "---"
  , "OBJETO: llave"
  , "DESC: Una llave."
  , "---"
  , "SALA: entrada"
  , "DESC: Una entrada iluminada."
  , "SALIDA: norte -> cueva"
  , "OBJETO: linterna"
  , "---"
  , "SALA: cueva"
  , "DESC: Una cueva."
  , "OSCURA: si"
  , "SALIDA: sur -> entrada"
  , "SALIDA: norte -> salida"
  , "OBJETO: llave"
  , "---"
  , "SALA: salida"
  , "DESC: Una salida."
  , "SALIDA: sur -> cueva"
  ]

-- Mundo con una salida que exige una llave que está en la sala inicial.
mundoBloqueado :: String
mundoBloqueado = unlines
  [ "MUNDO: Prueba de salida bloqueada"
  , "INICIO: entrada"
  , "META: llegar a pasillo"
  , "---"
  , "OBJETO: llave"
  , "DESC: Una llave."
  , "---"
  , "SALA: entrada"
  , "DESC: Una entrada."
  , "SALIDA: norte -> pasillo requiere llave"
  , "OBJETO: llave"
  , "---"
  , "SALA: pasillo"
  , "DESC: Un pasillo."
  , "SALIDA: sur -> entrada"
  ]

-- Mundo cuya meta es entrar en una sala.
mundoMetaSala :: String
mundoMetaSala = unlines
  [ "MUNDO: Prueba de meta por sala"
  , "INICIO: a"
  , "META: llegar a b"
  , "---"
  , "SALA: a"
  , "DESC: Sala A."
  , "SALIDA: norte -> b"
  , "---"
  , "SALA: b"
  , "DESC: Sala B."
  , "SALIDA: sur -> a"
  ]

-- Mundo cuya meta es llevar un objeto a la sala inicial.
mundoMetaObjeto :: String
mundoMetaObjeto = unlines
  [ "MUNDO: Prueba de meta por objeto"
  , "INICIO: a"
  , "META: llevar tesoro a a"
  , "---"
  , "OBJETO: tesoro"
  , "DESC: Un tesoro."
  , "---"
  , "SALA: a"
  , "DESC: Sala A."
  , "OBJETO: tesoro"
  ]

-- Mundo con un objeto que se puede tomar y soltar sin cumplir la meta.
mundoInventario :: String
mundoInventario = unlines
  [ "MUNDO: Prueba de inventario"
  , "INICIO: a"
  , "META: llegar a b"
  , "---"
  , "OBJETO: tesoro"
  , "DESC: Un tesoro."
  , "---"
  , "SALA: a"
  , "DESC: Sala A."
  , "SALIDA: norte -> b"
  , "OBJETO: tesoro"
  , "---"
  , "SALA: b"
  , "DESC: Sala B."
  , "SALIDA: sur -> a"
  ]

-- El estado inicial parte de la sala de inicio, sin objetos y con cada objeto
-- en la sala donde fue declarado.
pruebaEstadoInicial :: Test
pruebaEstadoInicial = TestLabel "estado inicial" $ TestCase $
  conMundoValido "mundos/entrega.txt" $ \m -> do
    let est = estadoInicial m
    assertEqual "ubicación inicial" (inicio m) (ubicacion est)
    assertEqual "inventario vacío" [] (inventario est)
    assertEqual "objetos en sus salas iniciales"
      (Map.map objetosInicial (salas m))
      (objetosEnSalas est)

-- El guion del mundo de ejemplo debe terminar con la meta cumplida.
pruebaPartidaEntrega :: Test
pruebaPartidaEntrega = TestLabel "partida en el mundo de ejemplo" $ TestCase $ do
  comandos <- cargarGuion "guiones/entrega.txt"
  conMundoValido "mundos/entrega.txt" $ \m -> do
    let (msgs, est) = correr (estadoInicial m) comandos
    assertBool "termina en la meta" (haGanado est)
    assertBool "incluye el mensaje de victoria" (elem mensajeVictoria msgs)

-- El guion del mundo propio debe usar la linterna y la llave para ganar.
pruebaPartidaMundo :: Test
pruebaPartidaMundo = TestLabel "partida en el mundo propio" $ TestCase $ do
  comandos <- cargarGuion "guiones/mundo.txt"
  conMundoValido "mundos/mundo.txt" $ \m -> do
    let (msgs, est) = correr (estadoInicial m) comandos
    assertBool "termina en la meta" (haGanado est)
    assertBool "incluye el mensaje de victoria" (elem mensajeVictoria msgs)
    assertBool "lleva la linterna" (elem (IdObjeto "linterna") (inventario est))
    assertBool "lleva el informe" (elem (IdObjeto "informe") (inventario est))

-- Mirar en una sala oscura sin luz solo informa de la oscuridad.
pruebaMirarOscuro :: Test
pruebaMirarOscuro = TestLabel "mirar a oscuras" $ TestCase $
  conTextoValido mundoOscuro $ \m -> do
    let inicial = estadoInicial m
        (_, enCueva) = ejecutar (Ir Norte) inicial
        (msgs, est) = ejecutar Mirar enCueva
    assertEqual "solo el mensaje de oscuridad" [mensajeOscuridad] msgs
    assertEqual "no cambia el estado" enCueva est

-- Tomar y examinar fallan en la oscuridad y funcionan al llevar una luz.
pruebaTomarExaminarOscuro :: Test
pruebaTomarExaminarOscuro = TestLabel "tomar y examinar a oscuras" $ TestCase $
  conTextoValido mundoOscuro $ \m -> do
    let inicial = estadoInicial m
        (_, enCueva) = ejecutar (Ir Norte) inicial
        (msgsTomar, trasTomar) = ejecutar (Tomar (IdObjeto "llave")) enCueva
        (msgsExaminar, _) = ejecutar (Examinar (IdObjeto "llave")) enCueva
        sueloCueva est =
          Map.findWithDefault [] (IdSala "cueva") (objetosEnSalas est)

    assertEqual "no puede tomar sin luz"
      ["Está demasiado oscuro para buscar o tomar objetos aquí."] msgsTomar
    assertEqual "el inventario no cambia" [] (inventario trasTomar)
    assertEqual "el objeto sigue en el suelo" [IdObjeto "llave"] (sueloCueva trasTomar)
    assertEqual "no puede examinar sin luz"
      ["Está muy oscuro para examinar objetos en la sala."] msgsExaminar

    let (_, deVuelta) = ejecutar (Ir Sur) enCueva
        (_, conLinterna) = ejecutar (Tomar (IdObjeto "linterna")) deVuelta
        (_, enCuevaConLuz) = ejecutar (Ir Norte) conLinterna
        (msgsTomarConLuz, trasTomarConLuz) =
          ejecutar (Tomar (IdObjeto "llave")) enCuevaConLuz
        (msgsExaminarConLuz, _) =
          ejecutar (Examinar (IdObjeto "llave")) trasTomarConLuz

    assertEqual "toma el objeto con luz" ["Has tomado: llave."] msgsTomarConLuz
    assertBool "la llave está en el inventario"
      (elem (IdObjeto "llave") (inventario trasTomarConLuz))
    assertEqual "examina el objeto con luz" ["Una llave."] msgsExaminarConLuz

-- Moverse funciona aunque no haya luz, y al volver a una sala iluminada se
-- vuelve a ver la descripción.
pruebaMoverseOscuro :: Test
pruebaMoverseOscuro = TestLabel "moverse a oscuras" $ TestCase $
  conTextoValido mundoOscuro $ \m -> do
    let inicial = estadoInicial m
        (msgsIda, enCueva) = ejecutar (Ir Norte) inicial
    assertEqual "entra a la sala oscura" (IdSala "cueva") (ubicacion enCueva)
    assertEqual "no ve nada al entrar" [mensajeOscuridad] msgsIda

    let (msgsVuelta, deVuelta) = ejecutar (Ir Sur) enCueva
    assertEqual "vuelve a la entrada" (IdSala "entrada") (ubicacion deVuelta)
    assertBool "vuelve a ver la sala" (elem "Una entrada iluminada." msgsVuelta)

-- Una salida con requisito no se cruza sin el objeto y sí se cruza con él.
pruebaSalidaBloqueada :: Test
pruebaSalidaBloqueada = TestLabel "salida bloqueada" $ TestCase $
  conTextoValido mundoBloqueado $ \m -> do
    let inicial = estadoInicial m
        (msgsBloqueado, trasIntento) = ejecutar (Ir Norte) inicial
    assertEqual "no se mueve sin el objeto" (IdSala "entrada") (ubicacion trasIntento)
    assertBool "avisa del bloqueo" (any (isInfixOf "está bloqueado") msgsBloqueado)
    assertBool "menciona el objeto requerido" (any (isInfixOf "llave") msgsBloqueado)

    let (_, conLlave) = ejecutar (Tomar (IdObjeto "llave")) inicial
        (_, enPasillo) = ejecutar (Ir Norte) conLlave
    assertEqual "cruza con el objeto" (IdSala "pasillo") (ubicacion enPasillo)

-- El requisito se comprueba en cada cruce: si el objeto se queda atrás, la
-- salida vuelve a bloquear.
pruebaRequisitoPersistente :: Test
pruebaRequisitoPersistente = TestLabel "requisito en cada cruce" $ TestCase $
  conTextoValido mundoBloqueado $ \m -> do
    let inicial = estadoInicial m
        (_, conLlave) = ejecutar (Tomar (IdObjeto "llave")) inicial
        (_, enPasillo) = ejecutar (Ir Norte) conLlave
        (_, sinLlave) = ejecutar (Soltar (IdObjeto "llave")) enPasillo
        (_, deVuelta) = ejecutar (Ir Sur) sinLlave
        (msgs, otraVez) = ejecutar (Ir Norte) deVuelta

    assertEqual "vuelve a la entrada" (IdSala "entrada") (ubicacion deVuelta)
    assertEqual "la salida vuelve a bloquear" (IdSala "entrada") (ubicacion otraVez)
    assertBool "avisa del bloqueo" (any (isInfixOf "bloqueado") msgs)

-- Entrar en la sala de la meta por sala produce la victoria.
pruebaVictoriaLlegar :: Test
pruebaVictoriaLlegar = TestLabel "victoria al llegar" $ TestCase $
  conTextoValido mundoMetaSala $ \m -> do
    let inicial = estadoInicial m
        (msgs, est) = ejecutar (Ir Norte) inicial
    assertBool "aún no gana al inicio" (not (haGanado inicial))
    assertEqual "llega a la sala meta" (IdSala "b") (ubicacion est)
    assertBool "gana al entrar" (haGanado est)
    assertBool "incluye el mensaje de victoria" (elem mensajeVictoria msgs)

-- Tomar el objeto de la meta estando en la sala de la meta produce la victoria.
pruebaVictoriaLlevar :: Test
pruebaVictoriaLlevar = TestLabel "victoria al llevar" $ TestCase $
  conTextoValido mundoMetaObjeto $ \m -> do
    let inicial = estadoInicial m
        (msgs, est) = ejecutar (Tomar (IdObjeto "tesoro")) inicial
    assertBool "aún no gana al inicio" (not (haGanado inicial))
    assertBool "gana al tomar el objeto" (haGanado est)
    assertBool "incluye el mensaje de victoria" (elem mensajeVictoria msgs)

-- Tomar y soltar mueven el objeto entre el suelo y el inventario sin duplicarlo.
pruebaTomarSoltar :: Test
pruebaTomarSoltar = TestLabel "tomar y soltar" $ TestCase $
  conTextoValido mundoInventario $ \m -> do
    let inicial = estadoInicial m
        (msgsTomar, trasTomar) = ejecutar (Tomar (IdObjeto "tesoro")) inicial
        (msgsTomarOtraVez, trasTomarOtraVez) =
          ejecutar (Tomar (IdObjeto "tesoro")) trasTomar
        (msgsSoltar, trasSoltar) =
          ejecutar (Soltar (IdObjeto "tesoro")) trasTomarOtraVez
        (msgsSoltarOtraVez, trasSoltarOtraVez) =
          ejecutar (Soltar (IdObjeto "tesoro")) trasSoltar
        sueloA est = Map.findWithDefault [] (IdSala "a") (objetosEnSalas est)

    assertBool "avisa que tomó el objeto" (elem "Has tomado: tesoro." msgsTomar)
    assertEqual "el objeto pasa al inventario" [IdObjeto "tesoro"] (inventario trasTomar)
    assertEqual "el suelo queda vacío" [] (sueloA trasTomar)

    assertEqual "no duplica el objeto al tomarlo otra vez"
      [IdObjeto "tesoro"] (inventario trasTomarOtraVez)
    assertEqual "avisa que no ve el objeto" ["No ves 'tesoro' aquí."] msgsTomarOtraVez

    assertBool "avisa que soltó el objeto" (elem "Has soltado: tesoro." msgsSoltar)
    assertEqual "el inventario queda vacío" [] (inventario trasSoltar)
    assertEqual "el objeto vuelve al suelo" [IdObjeto "tesoro"] (sueloA trasSoltar)

    assertEqual "no duplica el objeto al soltarlo otra vez"
      [IdObjeto "tesoro"] (sueloA trasSoltarOtraVez)
    assertEqual "avisa que no lleva el objeto"
      ["No llevas 'tesoro' en tu inventario."] msgsSoltarOtraVez

-- Los comandos sin efecto sobre el mundo no cambian el estado, y soltar la
-- única luz deja la sala a oscuras.
pruebaComandosNeutros :: Test
pruebaComandosNeutros = TestLabel "comandos sin efecto" $ TestCase $
  conTextoValido mundoOscuro $ \m -> do
    let inicial = estadoInicial m
        neutros =
          [ Mirar
          , Inventario
          , Ayuda
          , Salir
          , Guardar "partida.txt"
          , Cargar "partida.txt"
          ]
    mapM_
      (\cmd ->
        assertEqual ("no cambia el estado con " ++ show cmd)
          inicial
          (snd (ejecutar cmd inicial)))
      neutros

    let (_, conLinterna) = ejecutar (Tomar (IdObjeto "linterna")) inicial
        (_, enCueva) = ejecutar (Ir Norte) conLinterna
        (msgsSoltar, sinLinterna) = ejecutar (Soltar (IdObjeto "linterna")) enCueva
        (msgsMirar, _) = ejecutar Mirar sinLinterna

    assertBool "avisa que soltó la linterna"
      (elem "Has soltado: linterna." msgsSoltar)
    assertBool "avisa que la sala queda oscura"
      (elem "Al soltar linterna, la sala queda sumida en la oscuridad." msgsSoltar)
    assertEqual "la sala queda a oscuras" [mensajeOscuridad] msgsMirar
