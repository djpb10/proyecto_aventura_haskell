module Motor.Persistencia
  ( leerArchivoMundo
  , guardarPartida
  , cargarPartida
  ) where

import Control.Exception (IOException, evaluate, try)
import Data.Char (isSpace)
import System.Directory (doesFileExist)
import Motor.Tipos
import Motor.Mundo (leerMundo)

-- Lee el archivo de mundo y se lo pasa a leerMundo (que es pura).
-- Si el archivo no existe, devuelve un error en vez de caerse.
-- evaluate (length texto) fuerza la lectura completa, para que el
-- archivo quede cerrado (readFile es perezoso).
leerArchivoMundo :: FilePath -> IO (Either [ErrorMundo] Mundo)
leerArchivoMundo ruta = do
  existe <- doesFileExist ruta
  if existe
    then do
      texto <- readFile ruta
      _ <- evaluate (length texto)
      return (leerMundo texto)
    else return (Left [ErrorValidacion ("no se encontró el archivo " ++ ruta)])

-- Guarda el estado completo con show. Si no se puede escribir
-- (carpeta que no existe, sin permiso...), devuelve el motivo.
guardarPartida :: FilePath -> Estado -> IO (Either String ())
guardarPartida ruta est = do
  r <- try (writeFile ruta (show est)) :: IO (Either IOException ())
  case r of
    Left _  -> return (Left ("no se pudo escribir en " ++ ruta))
    Right _ -> return (Right ())

-- Carga una partida. 'actual' es el estado en curso: sirve para comprobar
-- que la partida guardada es del mismo mundo.
cargarPartida :: FilePath -> Estado -> IO (Either String Estado)
cargarPartida ruta actual = do
  existe <- doesFileExist ruta
  if not existe
    then return (Left ("no existe el archivo " ++ ruta))
    else do
      texto <- readFile ruta
      _ <- evaluate (length texto)
      case reads texto of
        [(est, resto)]
          | all isSpace resto ->
              if mundoActual est == mundoActual actual
                then return (Right est)
                else return (Left "esa partida es de otro mundo")
        _ -> return (Left "el archivo de partida está corrupto")