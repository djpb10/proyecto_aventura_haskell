module Motor.Comandos
  ( leerComando
  ) where

import Data.Char (isSpace, toLower)
import Motor.Tipos
import Motor.Reconocedor (ejecutarReconocedor, identificador, espacios1, cadena, direccion, (<|>))

-- Interpreta una línea de texto escrita por el jugador y la traduce a un Comando.
-- Es una función pura.
-- guardar y cargar se prueban primero con la línea tal cual, para no perder
-- las mayúsculas del nombre del archivo. El resto se pasa a minúsculas.
leerComando :: String -> Maybe Comando
leerComando linea =
  case ejecutarReconocedor (cmdGuardar <|> cmdCargar) limpia of
    Just c  -> Just c
    Nothing -> ejecutarReconocedor reconocerComando (map toLower limpia)
  where
    limpia = trim linea


trim :: String -> String
trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse


reconocerComando :: ReadS Comando
reconocerComando =
      cmdIr
  <|> cmdDireccionDirecta
  <|> cmdMirar
  <|> cmdTomar
  <|> cmdSoltar
  <|> cmdExaminar
  <|> cmdInventario
  <|> cmdAyuda
  <|> cmdSalir

-- Quita un artículo (el, la, los, las) al principio, si lo hay. Si la cadena
-- es solo un artículo, la deja vacía para que no se tome como identificador.
consumirArticulo :: String -> String
consumirArticulo str =
  case dropWhile isSpace str of
    ('e':'l':' ':rest)     -> dropWhile isSpace rest
    ('l':'a':' ':rest)     -> dropWhile isSpace rest
    ('l':'o':'s':' ':rest) -> dropWhile isSpace rest
    ('l':'a':'s':' ':rest) -> dropWhile isSpace rest
    "el"                   -> ""
    "la"                   -> ""
    "los"                  -> ""
    "las"                  -> ""
    _                      -> str

-- Un nombre de archivo: cualquier cosa sin espacios.
nombreArchivo :: ReadS String
nombreArchivo s =
  let (tok, resto) = span (not . isSpace) s
  in if null tok then [] else [(tok, resto)]

--- ir <dirección>
cmdIr :: ReadS Comando
cmdIr s =
  [ (Ir dir, r2)
  | (_, r1)    <- (cadena "ir" <|> cadena "mover") s
  , (_, r1')   <- espacios1 r1
  , (dir, r2)  <- (direccion <|> parseAbreviatura) r1'
  ]
  where
    parseAbreviatura str =
      [ (Norte, r) | (_, r) <- cadena "n" str ] ++
      [ (Sur, r)   | (_, r) <- cadena "s" str ] ++
      [ (Este, r)  | (_, r) <- cadena "e" str ] ++
      [ (Oeste, r) | (_, r) <- cadena "o" str ] ++
      [ (Arriba, r)| (_, r) <- cadena "u" str ] ++
      [ (Abajo, r) | (_, r) <- cadena "d" str ]

cmdDireccionDirecta :: ReadS Comando
cmdDireccionDirecta s =
  [ (Ir dir, r) | (dir, r) <- parseAbreviatura s ]
  where
    parseAbreviatura str =
      [ (Norte, r) | (_, r) <- cadena "norte" str ] ++
      [ (Sur, r)   | (_, r) <- cadena "sur" str ] ++
      [ (Este, r)  | (_, r) <- cadena "este" str ] ++
      [ (Oeste, r) | (_, r) <- cadena "oeste" str ] ++
      [ (Arriba, r)| (_, r) <- cadena "arriba" str ] ++
      [ (Abajo, r) | (_, r) <- cadena "abajo" str ]

--  mirar
cmdMirar :: ReadS Comando
cmdMirar s = [ (Mirar, r) | (_, r) <- (cadena "mirar" <|> cadena "m") s ]

--  tomar <objeto>
cmdTomar :: ReadS Comando
cmdTomar s =
  [ (Tomar (IdObjeto obj), r3)
  | (_, r1)    <- (cadena "tomar" <|> cadena "coger") s
  , (_, r2)    <- espacios1 r1
  , (obj, r3)  <- identificador (consumirArticulo r2)
  ]

--  soltar <objeto>
cmdSoltar :: ReadS Comando
cmdSoltar s =
  [ (Soltar (IdObjeto obj), r3)
  | (_, r1)    <- (cadena "soltar" <|> cadena "dejar") s
  , (_, r2)    <- espacios1 r1
  , (obj, r3)  <- identificador (consumirArticulo r2)
  ]

--  examinar <objeto>
cmdExaminar :: ReadS Comando
cmdExaminar s =
  [ (Examinar (IdObjeto obj), r3)
  | (_, r1)    <- (cadena "examinar" <|> cadena "x") s
  , (_, r2)    <- espacios1 r1
  , (obj, r3)  <- identificador (consumirArticulo r2)
  ]

--  inventario
cmdInventario :: ReadS Comando
cmdInventario s = [ (Inventario, r) | (_, r) <- (cadena "inventario" <|> cadena "inv") s ]

--  guardar <archivo>
cmdGuardar :: ReadS Comando
cmdGuardar s =
  [ (Guardar arch, r2)
  | (_, r0)    <- cadena "guardar" s
  , (_, r1)    <- espacios1 r0
  , (arch, r2) <- nombreArchivo r1
  ]

--  cargar <archivo>
cmdCargar :: ReadS Comando
cmdCargar s =
  [ (Cargar arch, r2)
  | (_, r0)    <- (cadena "cargar" <|> cadena "recuperar") s
  , (_, r1)    <- espacios1 r0
  , (arch, r2) <- nombreArchivo r1
  ]

--  ayuda
cmdAyuda :: ReadS Comando
cmdAyuda s = [ (Ayuda, r) | (_, r) <- (cadena "ayuda" <|> cadena "help") s ]

--  salir
cmdSalir :: ReadS Comando
cmdSalir s = [ (Salir, r) | (_, r) <- (cadena "salir" <|> cadena "exit" <|> cadena "q") s ]