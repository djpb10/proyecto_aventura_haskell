-- Módulo: Motor.Reconocedor
module Motor.Reconocedor
  ( -- * Combinadores básicos sobre ReadS
    caracter
  , cadena
  , satisfacer
  , (<|>)
  , muchos
  , muchos1
  , opcional
  , espacios
  , espacios1
    -- * Ejecución de reconocedores
  , ejecutarReconocedor
    -- * Reconocedores del dominio
  , identificador
  , direccion
  , booleanoSi
  , salida
  , reconocerMeta
  , lineaClaveValor
  ) where

import Data.Char (isDigit, isLower, isSpace)
import Data.List (stripPrefix)
import Motor.Tipos


-- Reconoce un único carácter que cumpla el predicado dado.
satisfacer :: (Char -> Bool) -> ReadS Char
satisfacer p (c : cs) | p c = [(c, cs)]
satisfacer _ _              = []

-- Reconoce un carácter específico.
caracter :: Char -> ReadS Char
caracter c = satisfacer (== c)

-- Reconoce un prefijo exacto de texto.
cadena :: String -> ReadS String
cadena prefijo entrada =
  case stripPrefix prefijo entrada of
    Just resto -> [(prefijo, resto)]
    Nothing    -> []

-- Elección entre dos reconocedores (combina sus resultados).
infixl 3 <|>
(<|>) :: ReadS a -> ReadS a -> ReadS a
(p <|> q) s = p s ++ q s

-- Cero o más repeticiones (la primera lectura es la más larga).
muchos :: ReadS a -> ReadS [a]
muchos p = muchos1 p <|> (\s -> [([], s)])

-- Una o más repeticiones.
muchos1 :: ReadS a -> ReadS [a]
muchos1 p s =
  [ (x : xs, r2)
  | (x, r1)  <- p s
  , (xs, r2) <- muchos p r1
  ]

-- Reconoce cero o una ocurrencia de un patrón.
opcional :: ReadS a -> ReadS (Maybe a)
opcional p s =
  [ (Just x, r) | (x, r) <- p s ] ++ [(Nothing, s)]

-- Consume cero o más espacios en blanco (coincidencia máxima).
espacios :: ReadS ()
espacios s = [((), dropWhile isSpace s)]

-- Consume uno o más espacios en blanco obligatorios.
espacios1 :: ReadS ()
espacios1 (c : cs) | isSpace c = [((), dropWhile isSpace cs)]
espacios1 _                    = []

-- Ejecuta un reconoceedor exigiendo que consuma toda la entrada (ignorando
-- espacios finales) y tomando la primera derivación válida.
ejecutarReconocedor :: ReadS a -> String -> Maybe a
ejecutarReconocedor r s =
  case [ x | (x, resto) <- r s, all isSpace resto ] of
    (x : _) -> Just x
    []      -> Nothing


-- Caracteres válidos para identificadoes: letras minúsculas (incluye
-- vocales acentuadas, ñ, ü porque isLower es True en Unicode), dígitos y '_'.
esCharIdentificador :: Char -> Bool
esCharIdentificador c = isLower c || isDigit c || c == '_'

-- Reconoce un identificador no vacío (coincidencia máxima para evitar
-- ambigüedad con prefijos parciales).
identificador :: ReadS String
identificador s =
  let (tok, resto) = span esCharIdentificador s
  in if null tok then [] else [(tok, resto)]

-- Reconoce una de las seis direcciones válidas.
direccion :: ReadS Direccion
direccion s =
  [ (Norte, r) | (_, r) <- cadena "norte" s ] ++
  [ (Sur, r)   | (_, r) <- cadena "sur" s   ] ++
  [ (Este, r)  | (_, r) <- cadena "este" s  ] ++
  [ (Oeste, r) | (_, r) <- cadena "oeste" s ] ++
  [ (Arriba, r)| (_, r) <- cadena "arriba" s] ++
  [ (Abajo, r) | (_, r) <- cadena "abajo" s ]

-- Reconoce el valor "si" para las claves OSCURA y LUZ (Variante Oscuridad).
booleanoSi :: ReadS Bool
booleanoSi s =
  [ (True, r) | (_, r) <- cadena "si" s ]

-- Reconoce el valor de una clave SALIDA:
-- <dirección> -> <sala> [requiere <objeto>]
salida :: ReadS (Direccion, Salida)
salida s =
  [ ((dir, Salida (IdSala dest) (fmap IdObjeto req)), r6)
  | (dir, r1)  <- direccion s
  , (_, r2)    <- espacios r1
  , (_, r3)    <- cadena "->" r2
  , (_, r4)    <- espacios r3
  , (dest, r5) <- identificador r4
  , (req, r6)  <- requisito r5
  ]
  where
    requisito r =
      [ (Just obj, r3)
      | (_, r1)   <- espacios1 r
      , (_, r2)   <- cadena "requiere" r1
      , (_, r2')  <- espacios1 r2
      , (obj, r3) <- identificador r2'
      ] ++ [(Nothing, r)]

--  Reconoce el valor de una clave META:
-- "llegar a <sala>" o "llevar <objeto> a <sala>"
reconocerMeta :: ReadS Meta
reconocerMeta = metaLlegar <|> metaLlevar
  where
    metaLlegar s =
      [ (LlegarA (IdSala dest), r4)
      | (_, r1)    <- cadena "llegar" s
      , (_, r2)    <- espacios1 r1
      , (_, r3)    <- cadena "a" r2
      , (_, r3')   <- espacios1 r3
      , (dest, r4) <- identificador r3'
      ]
    metaLlevar s =
      [ (LlevarA (IdObjeto obj) (IdSala dest), r6)
      | (_, r1)    <- cadena "llevar" s
      , (_, r2)    <- espacios1 r1
      , (obj, r3)  <- identificador r2
      , (_, r3')   <- espacios1 r3
      , (_, r4)    <- cadena "a" r3'
      , (_, r4')   <- espacios1 r4
      , (dest, r6) <- identificador r4'
      ]

-- Separa una línea en su CLAVE (en mayúsculas) y su valor (sin espacios
-- iniciales/finales). Ignora los espacios al inicio de la línea y exige ':' tras la clave.
lineaClaveValor :: ReadS (String, String)
lineaClaveValor s =
  let sLimpio = dropWhile isSpace s
      (clave, resto) = span (\c -> c /= ':' && not (isSpace c)) sLimpio
  in case resto of
       (':' : valorCrudo)
         | not (null clave) ->
             let valor = dropWhile isSpace (reverse (dropWhile isSpace (reverse valorCrudo)))
             in [( (clave, valor), "" )]
       _ -> []