module Motor.Mundo where

import Data.Char (isSpace)
import qualified Data.Map.Strict as Map
import Motor.Tipos
import Motor.Reconocedor

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

-- una línea es separador si ya recortada, es ---
esSeparador :: (Int, String) -> Bool
esSeparador (_, l) = l == "---"

-- líneas en bloques, cortando en cada separador. actual guarda el bloque que se está armando, al revés
bloques :: [(Int, String)] -> [[(Int, String)]]
bloques = aux []
  where
    aux actual []     = cerrar actual []
    aux actual (x:xs)
      | esSeparador x = cerrar actual (aux [] xs)
      | otherwise     = aux (x : actual) xs

    -- si el bloque tiene algo, lo da vuelta y lo agrega; si está vacío, lo descarta
    cerrar [] resto     = resto
    cerrar actual resto = invertir actual : resto         

-- número de línea, clave y valor
type Campo = (Int, String, String)

leerCampo :: (Int, String) -> Either ErrorMundo Campo
leerCampo (n, l) =
  case ejecutarReconocedor lineaClaveValor l of
    Just (clave, valor) -> Right (n, clave, valor)
    Nothing -> Left (ErrorSintaxis n "la línea no tiene la forma CLAVE: valor")

-- todos los left, todos los right
separar :: [Either a b] -> ([a], [b])
separar = foldr paso ([], [])
  where
    paso (Left e)  (es, bs) = (e : es, bs)
    paso (Right b) (es, bs) = (es, b : bs)    

-- combina dos resultados sin cortar en el primer error
infixl 4 <+>
(<+>) :: Either [e] (a -> b) -> Either [e] a -> Either [e] b
Left e1 <+> Left e2 = Left (e1 ++ e2)
Left e1 <+> Right _ = Left e1
Right _ <+> Left e2 = Left e2
Right f <+> Right x = Right (f x)

-- resultado de lista, juntando errores
todas :: [Either [e] a] -> Either [e] [a]
todas = foldr (\x acc -> fmap (:) x <+> acc) (Right [])

conErrores :: [e] -> Either [e] a -> Either [e] a
conErrores [] r         = r
conErrores es (Left e)  = Left (es ++ e)
conErrores es (Right _) = Left es

buscar :: String -> [Campo] -> [Campo]
buscar clave = filter (\(_, k, _) -> k == clave)

-- un error por cada clave que el bloque no admite
verificar :: [String] -> [Campo] -> [ErrorMundo]
verificar permitidas cs =
  [ ErrorSintaxis n ("clave desconocida: " ++ k)
  | (n, k, _) <- cs, not (elem k permitidas) ]

--  valor de un campo con un reconocedor de david
valorCon :: ReadS a -> String -> Campo -> Either [ErrorMundo] a
valorCon r msg (n, _, v) =
  case ejecutarReconocedor r v of
    Just x  -> Right x
    Nothing -> Left [ErrorSintaxis n (msg ++ ": " ++ v)]

-- una clave que debe aparecer exactamente una vez
unico :: Int -> String -> ReadS a -> String -> [Campo] -> Either [ErrorMundo] a
unico n clave r msg cs =
  case buscar clave cs of
    [c] -> valorCon r msg c
    [] -> Left [ErrorSintaxis n ("falta el campo " ++ clave)]
    (_ : (m, _, _) : _) ->
      Left [ErrorSintaxis m ("el campo " ++ clave ++ " está repetido")]

opcionalBool :: Int -> String -> [Campo] -> Either [ErrorMundo] Bool
opcionalBool n clave cs =
  case buscar clave cs of
    [] -> Right False
    _  -> unico n clave booleanoSi ("el valor de " ++ clave ++ " debe ser si") cs

-- cualquier cosa, pero no vacío
textoLibre :: ReadS String
textoLibre s
  | null s    = []
  | otherwise = [(s, "")]

primeraLinea :: [(Int, String)] -> Int
primeraLinea ((n, _) : _) = n
primeraLinea []           = 0

conCampos :: (Int -> [Campo] -> Either [ErrorMundo] a)
          -> [(Int, String)] -> Either [ErrorMundo] a
conCampos f ls = conErrores errs (f (primeraLinea ls) cs)
  where (errs, cs) = separar (map leerCampo ls)

-- titulo, sala inicial y meta
data Cabecera = Cabecera String IdSala Meta

leerCabecera :: Int -> [Campo] -> Either [ErrorMundo] Cabecera
leerCabecera n cs =
  conErrores (verificar ["MUNDO", "INICIO", "META"] cs)
    (  Right Cabecera
   <+> unico n "MUNDO" textoLibre "el título está vacío" cs
   <+> fmap IdSala (unico n "INICIO" identificador "identificador de sala inválido" cs)
   <+> unico n "META" reconocerMeta "META mal formada" cs )

-- sala cruda
data SalaCruda = SalaCruda
  { crId      :: IdSala
  , crDesc    :: String
  , crOscura  :: Bool
  , crSalidas :: [(Direccion, Salida)]
  , crObjetos :: [IdObjeto]
  }

data Bloque = BObjeto Objeto | BSala SalaCruda

leerObjeto :: Int -> [Campo] -> Either [ErrorMundo] Objeto
leerObjeto n cs =
  conErrores (verificar ["OBJETO", "DESC", "LUZ"] cs)
    (  Right (\i d l -> Objeto (IdObjeto i) d l)
   <+> unico n "OBJETO" identificador "identificador de objeto inválido" cs
   <+> unico n "DESC" textoLibre "la descripción está vacía" cs
   <+> opcionalBool n "LUZ" cs )

leerSala :: Int -> [Campo] -> Either [ErrorMundo] SalaCruda
leerSala n cs =
  conErrores (verificar ["SALA", "DESC", "OSCURA", "SALIDA", "OBJETO"] cs)
    (  Right (\i d o ss os -> SalaCruda (IdSala i) d o ss os)
   <+> unico n "SALA" identificador "identificador de sala inválido" cs
   <+> unico n "DESC" textoLibre "la descripción está vacía" cs
   <+> opcionalBool n "OSCURA" cs
   <+> todas (map (valorCon salida "SALIDA mal formada") (buscar "SALIDA" cs))
   <+> todas (map (fmap IdObjeto . valorCon identificador "identificador de objeto inválido")
                  (buscar "OBJETO" cs)) )

leerBloque :: [(Int, String)] -> Either [ErrorMundo] Bloque
leerBloque = conCampos porTipo
  where
    porTipo n cs =
      case cs of
        ((_, "SALA", _) : _)   -> fmap BSala (leerSala n cs)
        ((_, "OBJETO", _) : _) -> fmap BObjeto (leerObjeto n cs)
        ((m, k, _) : _) ->
          Left [ErrorSintaxis m ("el bloque debe empezar con SALA u OBJETO, no con " ++ k)]
        [] -> Left []    