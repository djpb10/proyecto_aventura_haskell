module Main (main) where

import System.Exit (exitFailure, exitSuccess)
import Test.HUnit (Counts (..), Test (..), runTestTT)
import ReconocedorSpec (pruebasReconocedor)

-- Punto de entrada de la suite: reúne los grupos de casos y traduce el
-- resultado a un código de salida distinto de cero si algo falla.
main :: IO ()
main = do
  counts <- runTestTT (TestList [pruebasReconocedor])
  if errors counts + failures counts == 0
    then exitSuccess
    else exitFailure
