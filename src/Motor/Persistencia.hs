module Motor.Persistencia
  ( leerArchivoMundo
  , guardarPartida
  , cargarPartida
  ) where

import Control.Exception (IOException, try)
import Data.Char (isSpace)
import System.Directory (doesFileExist)
import Motor.Tipos
import Motor.Mundo (leerMundo)

-- lee el archivo de mundo y se lo pasa a leerMundo, si no existe, devuelve un error en vez de caerse
leerArchivoMundo :: FilePath -> IO (Either [ErrorMundo] Mundo)
leerArchivoMundo ruta = do
  existe <- doesFileExist ruta
  if existe
    then do
      texto <- readFile ruta
      return (leerMundo texto)
    else return (Left [ErrorValidacion ("no se encontró el archivo " ++ ruta)])

-- guarda el estado completo con show. Si no se puede escribir porque carpeta que no existe o sin permiso, devuelve el motivo
guardarPartida :: FilePath -> Estado -> IO (Either String ())
guardarPartida ruta est = do
  r <- try (writeFile ruta (show est)) :: IO (Either IOException ())
  case r of
    Left _  -> return (Left ("no se pudo escribir en " ++ ruta))
    Right _ -> return (Right ())

-- carga una partida. actual -> estado en curso, sirve para comprobar eue la partida guardada es del mismo mundo
cargarPartida :: FilePath -> Estado -> IO (Either String Estado)
cargarPartida ruta actual = do
  existe <- doesFileExist ruta
  if not existe
    then return (Left ("no existe el archivo " ++ ruta))
    else do
      texto <- readFile ruta
      case reads texto of
        [(est, resto)]
          | all isSpace resto ->
              if mundoActual est == mundoActual actual
                then return (Right est)
                else return (Left "esa partida es de otro mundo")
        _ -> return (Left "el archivo de partida está corrupto")