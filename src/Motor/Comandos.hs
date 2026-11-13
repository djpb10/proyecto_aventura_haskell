module Motor.Comandos
  ( leerComando
  ) where

import Data.Char (isSpace, toLower)
import Motor.Tipos
import Motor.Reconocedor (ejecutarReconocedor, identificador, espacios1, cadena, direccion, (<|>))

-- Interpreta una línea de texto escrita por el jugador y la traduce a un Comando.
-- Es una función pura.
leerComando :: String -> Maybe Comando
leerComando linea =
  let lineaLimpia = map toLower (trim linea)
  in ejecutarReconocedor reconocerComando lineaLimpia


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
  <|> cmdGuardar
  <|> cmdCargar
  <|> cmdAyuda
  <|> cmdSalir

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
  [ (Tomar (IdObjeto obj), r5)
  | (_, r1)    <- (cadena "tomar" <|> cadena "coger") s
  , (_, r2)    <- espacios1 r1
  , let r2' = consumirArticulo r2
  , (obj, r5)  <- identificador r2'
  ]
  where
    consumirArticulo str =
      case dropWhile isSpace str of
        ('e':'l':' ':rest)     -> dropWhile isSpace rest
        ('l':'a':' ':rest)     -> dropWhile isSpace rest
        ('l':'o':'s':' ':rest) -> dropWhile isSpace rest
        ('l':'a':'s':' ':rest) -> dropWhile isSpace rest
        _                      -> str

--  soltar <objeto>
cmdSoltar :: ReadS Comando
cmdSoltar s =
  [ (Soltar (IdObjeto obj), r4)
  | (_, r1)    <- (cadena "soltar" <|> cadena "dejar") s
  , (_, r2)    <- espacios1 r1
  , let r2' = consumirArticulo r2
  , (obj, r4)  <- identificador r2'
  ]
  where
    consumirArticulo str =
      case dropWhile isSpace str of
        ('e':'l':' ':rest)  -> dropWhile isSpace rest
        ('l':'a':' ':rest)  -> dropWhile isSpace rest
        _                   -> str

--  examinar <objeto>
cmdExaminar :: ReadS Comando
cmdExaminar s =
  [ (Examinar (IdObjeto obj), r4)
  | (_, r1)    <- (cadena "examinar" <|> cadena "x") s
  , (_, r2)    <- espacios1 r1
  , (obj, r4)  <- identificador r2
  ]

--  inventario
cmdInventario :: ReadS Comando
cmdInventario s = [ (Inventario, r) | (_, r) <- (cadena "inventario" <|> cadena "inv") s ]

--  guardar <archivo>
cmdGuardar :: ReadS Comando
cmdGuardar s =
  [ (Guardar arch, r3)
  | (_, r1)    <- cadena "guardar" s
  , (_, r2)    <- espacios1 r1
  , (arch, r3) <- identificador r2
  ]

--  cargar <archivo>
cmdCargar :: ReadS Comando
cmdCargar s =
  [ (Cargar arch, r3)
  | (_, r1)    <- (cadena "cargar" <|> cadena "recuperar") s
  , (_, r2)    <- espacios1 r1
  , (arch, r3) <- identificador r2
  ]

--  ayuda
cmdAyuda :: ReadS Comando
cmdAyuda s = [ (Ayuda, r) | (_, r) <- (cadena "ayuda" <|> cadena "help") s ]

--  salir
cmdSalir :: ReadS Comando
cmdSalir s = [ (Salir, r) | (_, r) <- (cadena "salir" <|> cadena "exit" <|> cadena "q") s ]