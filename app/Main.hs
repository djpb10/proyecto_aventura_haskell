module Main (main) where

import GHC.IO.Encoding (setLocaleEncoding)
import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitSuccess, exitWith)
import System.IO (hFlush, hPutStrLn, hSetEncoding, isEOF, stderr, stdin, stdout, utf8)
import Motor.Comandos (leerComando)
import Motor.Nucleo (describirSalaActual, ejecutar, estadoInicial)
import Motor.Persistencia (cargarPartida, guardarPartida, leerArchivoMundo)
import Motor.Tipos

main :: IO ()
main = do
  setLocaleEncoding utf8
  hSetEncoding stdout utf8
  hSetEncoding stdin utf8
  args <- getArgs
  case args of
    ["--validar", ruta] -> soloValidar ruta
    [ruta]              -> jugar ruta
    _ -> do
      hPutStrLn stderr "Uso: aventura MUNDO  |  aventura --validar MUNDO"
      exitWith (ExitFailure 2)

-- aventura --validar MUNDO
soloValidar :: FilePath -> IO ()
soloValidar ruta = do
  r <- leerArchivoMundo ruta
  case r of
    Left es -> do
      mapM_ print es
      exitWith (ExitFailure 1)
    Right _ -> do
      putStrLn "Mundo válido."
      exitSuccess

-- aventura MUNDO
jugar :: FilePath -> IO ()
jugar ruta = do
  r <- leerArchivoMundo ruta
  case r of
    Left es -> do
      mapM_ print es
      exitWith (ExitFailure 1)
    Right m -> do
      let est = estadoInicial m
      putStrLn (titulo m)
      mapM_ putStrLn (describirSalaActual est)
      bucle est

-- El ciclo del juego es recursión: bucle se vuelve a llamar con el estado nuevo.
-- Termina (con código 0) al ganar, con "salir" o cuando se acaba la entrada.
bucle :: Estado -> IO ()
bucle est = do
  putStr "> "
  hFlush stdout
  fin <- isEOF
  if fin
    then do
      putStrLn ""
      exitSuccess
    else do
      linea <- getLine
      case leerComando linea of
        Nothing -> do
          putStrLn "No entiendo ese comando. Escribe «ayuda»."
          bucle est
        Just Salir -> do
          putStrLn "¡Hasta luego!"
          exitSuccess
        Just (Guardar ruta) -> do
          g <- guardarPartida ruta est
          case g of
            Left msg -> putStrLn ("No se pudo guardar: " ++ msg)
            Right () -> putStrLn ("Partida guardada en " ++ ruta ++ ".")
          bucle est
        Just (Cargar ruta) -> do
          c <- cargarPartida ruta est
          case c of
            Left msg -> do
              putStrLn ("No se pudo cargar: " ++ msg)
              bucle est
            Right est' -> do
              putStrLn "Partida cargada."
              mapM_ putStrLn (describirSalaActual est')
              bucle est'
        Just cmd -> do
          let (msgs, est') = ejecutar cmd est
          mapM_ putStrLn msgs
          if elem "*** ¡Has ganado! ***" msgs
            then exitSuccess
            else bucle est'