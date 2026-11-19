module Common
  ( cargarMundo
  , conMundoInvalido
  , conMundoValido
  , conTextoValido
  , tieneError
  ) where

import Data.List (isInfixOf)
import Motor.Mundo (leerMundo)
import Motor.Tipos (ErrorMundo, Mundo)
import Test.HUnit (Assertion, assertFailure)

-- Lee el contenido de un archivo y lo convierte en un mundo.
cargarMundo :: FilePath -> IO (Either [ErrorMundo] Mundo)
cargarMundo ruta = do
  texto <- readFile ruta
  return (leerMundo texto)

-- Aplica una comprobación a un mundo que debe ser válido. Si la lectura
-- devuelve errores, falla el caso indicando cuántos encontró.
conMundoValido :: FilePath -> (Mundo -> Assertion) -> Assertion
conMundoValido ruta verificacion = do
  resultado <- cargarMundo ruta
  case resultado of
    Left es ->
      assertFailure
        ("se esperaba un mundo válido, pero hay " ++ show (length es) ++ " errores")
    Right m -> verificacion m

-- Aplica una comprobación a la lista de errores de un mundo que debe ser
-- inválido. Si la lectura no produce errores, falla el caso.
conMundoInvalido :: FilePath -> ([ErrorMundo] -> Assertion) -> Assertion
conMundoInvalido ruta verificacion = do
  resultado <- cargarMundo ruta
  case resultado of
    Left es -> verificacion es
    Right _ -> assertFailure "se esperaba un mundo inválido, pero la lectura no dio errores"

-- Indica si la descripción de algún error contiene el fragmento dado.
tieneError :: String -> [ErrorMundo] -> Bool
tieneError fragmento = any (isInfixOf fragmento . show)

-- Aplica una comprobación al mundo que resulta de leer un texto. Si la
-- lectura produce errores, falla el caso con la cantidad encontrada.
conTextoValido :: String -> (Mundo -> Assertion) -> Assertion
conTextoValido texto verificacion =
  case leerMundo texto of
    Left es ->
      assertFailure
        ("se esperaba un mundo válido, pero hay " ++ show (length es) ++ " errores")
    Right m -> verificacion m
