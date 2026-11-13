module Motor.Mundo where

import Data.Char (isSpace)

invertir :: [a] -> [a]
invertir = foldl (\acc x -> x : acc) []

-- quita los espacios del principio y del final de una línea
recortar :: String -> String
recortar = dropWhile isSpace . invertir . dropWhile isSpace . invertir

-- número a cada línea, empezando por n
numerar :: Int -> [String] -> [(Int, String)]
numerar _ []     = []
numerar n (l:ls) = (n, l) : numerar (n + 1) ls

-- una línea se ignora si está vacía o si empieza con #
esIgnorable :: String -> Bool
esIgnorable ""      = True
esIgnorable ('#':_) = True
esIgnorable _       = False

-- devuelve las líneas que importan, cada una con su número original
lineasUtiles :: String -> [(Int, String)]
lineasUtiles texto =
  filter (not . esIgnorable . snd)
         (map (\(n, l) -> (n, recortar l)) (numerar 1 (lines texto)))