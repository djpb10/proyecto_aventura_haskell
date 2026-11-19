module Main (main) where

import GHC.IO.Encoding (setLocaleEncoding, utf8)
import System.Exit (exitFailure, exitSuccess)
import Test.HUnit (Counts (..), Test (..), runTestTT)
import ComandosSpec (pruebasComandos)
import MundoSpec (pruebasMundo)
import NucleoSpec (pruebasNucleo)
import PersistenciaSpec (pruebasPersistencia)
import ReconocedorSpec (pruebasReconocedor)

-- Punto de entrada de la suite: fija la codificación de los archivos, reúne
-- los grupos de casos y traduce el resultado a un código de salida distinto
-- de cero si algo falla.
main :: IO ()
main = do
  setLocaleEncoding utf8
  counts <-
    runTestTT
      (TestList
        [ pruebasReconocedor
        , pruebasMundo
        , pruebasComandos
        , pruebasNucleo
        , pruebasPersistencia
        ])
  if errors counts + failures counts == 0
    then exitSuccess
    else exitFailure
