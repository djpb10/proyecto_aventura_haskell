module PersistenciaSpec (pruebasPersistencia) where

import Control.Exception (bracket)
import Data.List (isInfixOf)
import Common (conMundoValido)
import Motor.Nucleo (estadoInicial)
import Motor.Persistencia (cargarPartida, guardarPartida, leerArchivoMundo)
import System.Directory (getTemporaryDirectory, removeFile)
import System.FilePath ((</>))
import System.IO (hClose, openTempFile)
import Test.HUnit

-- Reúne los casos de guardado y carga de partidas.
pruebasPersistencia :: Test
pruebasPersistencia =
  TestList
    [ pruebaGuardarCargar
    , pruebaArchivoInexistente
    , pruebaArchivoCorrupto
    , pruebaOtroMundo
    , pruebaRutasInvalidas
    ]

-- Crea un archivo temporal con el contenido dado y lo borra al terminar.
conArchivoTemporal :: String -> (FilePath -> IO a) -> IO a
conArchivoTemporal contenido accion = bracket crear removeFile accion
  where
    crear = do
      dir <- getTemporaryDirectory
      (ruta, mango) <- openTempFile dir "aventura-test"
      hClose mango
      writeFile ruta contenido
      return ruta

-- Reserva una ruta temporal que ya no existe al devolverla.
conRutaLibre :: (FilePath -> IO a) -> IO a
conRutaLibre accion = do
  dir <- getTemporaryDirectory
  (ruta, mango) <- openTempFile dir "aventura-libre"
  hClose mango
  removeFile ruta
  accion ruta

-- Una partida guardada se recupera con el mismo estado.
pruebaGuardarCargar :: Test
pruebaGuardarCargar = TestLabel "guardar y cargar" $ TestCase $
  conMundoValido "mundos/entrega.txt" $ \m ->
    conArchivoTemporal "" $ \ruta -> do
      let inicial = estadoInicial m
      guardado <- guardarPartida ruta inicial
      assertEqual "guarda la partida" (Right ()) guardado

      cargado <- cargarPartida ruta inicial
      assertEqual "recupera el mismo estado" (Right inicial) cargado

-- Cargar una ruta que no existe devuelve un error en vez de una excepción.
pruebaArchivoInexistente :: Test
pruebaArchivoInexistente = TestLabel "archivo inexistente" $ TestCase $
  conMundoValido "mundos/entrega.txt" $ \m ->
    conRutaLibre $ \ruta -> do
      resultado <- cargarPartida ruta (estadoInicial m)
      case resultado of
        Left msg -> assertBool "menciona que no existe" (isInfixOf "no existe" msg)
        Right _ -> assertFailure "se esperaba un error por archivo inexistente"

-- Un archivo que no contiene un estado devuelve un error de corrupción.
pruebaArchivoCorrupto :: Test
pruebaArchivoCorrupto = TestLabel "archivo corrupto" $ TestCase $
  conMundoValido "mundos/entrega.txt" $ \m ->
    conArchivoTemporal "esto no es una partida" $ \ruta -> do
      resultado <- cargarPartida ruta (estadoInicial m)
      case resultado of
        Left msg -> assertBool "menciona archivo corrupto" (isInfixOf "corrupto" msg)
        Right _ -> assertFailure "se esperaba un error por archivo corrupto"

-- Una partida guardada con otro mundo no se puede cargar.
pruebaOtroMundo :: Test
pruebaOtroMundo = TestLabel "partida de otro mundo" $ TestCase $
  conMundoValido "mundos/entrega.txt" $ \mEntrega ->
    conMundoValido "mundos/mundo.txt" $ \mPropio ->
      conArchivoTemporal "" $ \ruta -> do
        _ <- guardarPartida ruta (estadoInicial mEntrega)
        resultado <- cargarPartida ruta (estadoInicial mPropio)
        case resultado of
          Left msg -> assertBool "menciona otro mundo" (isInfixOf "otro mundo" msg)
          Right _ -> assertFailure "se esperaba un error por partida de otro mundo"

-- Escribir en una ruta sin carpeta y leer un archivo ausente devuelven errores.
pruebaRutasInvalidas :: Test
pruebaRutasInvalidas = TestLabel "rutas inválidas" $ TestCase $ do
  dir <- getTemporaryDirectory
  let rutaSinCarpeta = dir </> "aventura-carpeta-inexistente" </> "partida.sav"

  conMundoValido "mundos/entrega.txt" $ \m -> do
    guardado <- guardarPartida rutaSinCarpeta (estadoInicial m)
    case guardado of
      Left msg ->
        assertBool "menciona que no se pudo escribir"
          (isInfixOf "no se pudo escribir" msg)
      Right () -> assertFailure "se esperaba un error al escribir en una ruta inválida"

  conRutaLibre $ \ruta -> do
    resultado <- leerArchivoMundo ruta
    case resultado of
      Left es ->
        assertBool "menciona que no se encontró el archivo"
          (any (isInfixOf "no se encontró" . show) es)
      Right _ -> assertFailure "se esperaba un error por archivo inexistente"
