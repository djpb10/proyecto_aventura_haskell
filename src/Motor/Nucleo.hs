module Motor.Nucleo
  ( estadoInicial
  , ejecutar
  , describirSalaActual
  , haGanado
  ) where

import Data.List (intercalate)
import qualified Data.Map.Strict as Map
import Motor.Tipos


-- Construye el estado inicial de la partida a partir de un Mundo validado.
estadoInicial :: Mundo -> Estado
estadoInicial m = Estado
  { mundoActual    = m
  , ubicacion      = inicio m
  , inventario     = []
  , objetosEnSalas = Map.map objetosInicial (salas m)
  }

-- Indica si se cumple la condición de victoria (META) en el estado actual.
haGanado :: Estado -> Bool
haGanado est =
  case meta (mundoActual est) of
    LlegarA s    -> ubicacion est == s
    LlevarA ob s -> ubicacion est == s && elem ob (inventario est)


-- Ejecuta un comando sobre el estado actual y devuelve (mensajes, nuevoEstado).
ejecutar :: Comando -> Estado -> ([String], Estado)
ejecutar cmd est =
  case cmd of
    Mirar          -> (describirSalaActual est, est)
    Inventario     -> (mostrarInventario est, est)
    Ayuda          -> (textoAyuda, est)
    Salir          -> (["¡Hasta luego!"], est)
    Ir dir         -> moverJugador dir est
    Tomar objId    -> tomarObjeto objId est
    Soltar objId   -> soltarObjeto objId est
    Examinar objId -> examinarObjeto objId est
    Guardar _      -> (["Guardando partida..."], est)
    Cargar _       -> (["Cargando partida..."], est)


-- Determina si el jugador puede ver en su sala actual.
tieneLuz :: Estado -> Bool
tieneLuz est =
  case Map.lookup (ubicacion est) (salas (mundoActual est)) of
    Nothing   -> False
    Just sala -> not (esOscura sala) || llevaObjetoConLuz est

-- Comprueba si algún objeto en el inventario del jugador emite luz.
llevaObjetoConLuz :: Estado -> Bool
llevaObjetoConLuz est = any esFuenteDeLuz (inventario est)
  where
    objs = objetos (mundoActual est)
    esFuenteDeLuz oid =
      case Map.lookup oid objs of
        Just obj -> daLuz obj
        Nothing  -> False

-- Genera la descripción de la sala actual respetando la regla de Oscuridad.
describirSalaActual :: Estado -> [String]
describirSalaActual est =
  case Map.lookup (ubicacion est) (salas (mundoActual est)) of
    Nothing -> ["Error interno: sala actual inexistente."]
    Just sala
      | not (tieneLuz est) ->
          [ "Está completamente oscuro. No puedes ver nada a tu alrededor." ]
      | otherwise ->
          [ descSala sala ]
          ++ listarObjetosEnSala est
          ++ listarSalidas sala

listarObjetosEnSala :: Estado -> [String]
listarObjetosEnSala est =
  let idsEnSuelo = Map.findWithDefault [] (ubicacion est) (objetosEnSalas est)
  in case idsEnSuelo of
       [] -> []
       xs -> [ "Objetos aquí: " ++ intercalate ", " (map unIdObjeto xs) ]

listarSalidas :: Sala -> [String]
listarSalidas sala =
  let dirs = Map.keys (salidas sala)
  in case dirs of
       [] -> [ "No hay salidas visibles." ]
       xs -> [ "Salidas: " ++ intercalate ", " (map dirTexto xs) ]


-- Mueve al jugador en una dirección si existe salida y cumple los requisitos.
moverJugador :: Direccion -> Estado -> ([String], Estado)
moverJugador dir est =
  case Map.lookup (ubicacion est) (salas (mundoActual est)) of
    Nothing -> (["Error interno: sala actual inexistente."], est)
    Just sala ->
      case Map.lookup dir (salidas sala) of
        Nothing ->
          let msg = if tieneLuz est
                      then "No puedes ir hacia " ++ dirTexto dir ++ "."
                      else "Tanteas en la oscuridad hacia " ++ dirTexto dir ++ ", pero chocas con un muro."
          in ([msg], est)
        Just sal ->
          case requisito sal of
            Just reqId | not (elem reqId (inventario est)) ->
              (["El paso hacia " ++ dirTexto dir ++ " está bloqueado. Requiere: " ++ unIdObjeto reqId ++ "."], est)
            _ ->
              let est' = est { ubicacion = destino sal }
                  desc = describirSalaActual est'
              in verificarVictoria desc est'

-- Toma un objeto de la sala actual y lo mueve al inventario.
tomarObjeto :: IdObjeto -> Estado -> ([String], Estado)
tomarObjeto oid est
  | not (tieneLuz est) =
      (["Está demasiado oscuro para buscar o tomar objetos aquí."], est)
  | otherwise =
      let actual  = ubicacion est
          enSuelo = Map.findWithDefault [] actual (objetosEnSalas est)
      in if elem oid enSuelo
           then
             let nuevoSuelo = quitarPrimero oid enSuelo
                 nuevoMap   = Map.insert actual nuevoSuelo (objetosEnSalas est)
                 est'       = est { inventario     = oid : inventario est
                                  , objetosEnSalas = nuevoMap
                                  }
             in verificarVictoria ["Has tomado: " ++ unIdObjeto oid ++ "."] est'
           else
             (["No ves '" ++ unIdObjeto oid ++ "' aquí."], est)

-- Suelta un objeto del inventario en la sala actual.
soltarObjeto :: IdObjeto -> Estado -> ([String], Estado)
soltarObjeto oid est
  | not (elem oid (inventario est)) =
      (["No llevas '" ++ unIdObjeto oid ++ "' en tu inventario."], est)
  | otherwise =
      let actual   = ubicacion est
          enSuelo  = Map.findWithDefault [] actual (objetosEnSalas est)
          nuevoMap = Map.insert actual (oid : enSuelo) (objetosEnSalas est)
          est'     = est { inventario     = quitarPrimero oid (inventario est)
                           , objetosEnSalas = nuevoMap
                           }
          avisoLuz = if not (tieneLuz est')
                       then ["Al soltar " ++ unIdObjeto oid ++ ", la sala queda sumida en la oscuridad."]
                       else []
      in (["Has soltado: " ++ unIdObjeto oid ++ "."] ++ avisoLuz, est')

-- Muestra la descripción de un objeto en el inventario o en la sala actual.
examinarObjeto :: IdObjeto -> Estado -> ([String], Estado)
examinarObjeto oid est =
  let enInv   = elem oid (inventario est)
      enSuelo = tieneLuz est && elem oid (Map.findWithDefault [] (ubicacion est) (objetosEnSalas est))
  in if enInv || enSuelo
       then case Map.lookup oid (objetos (mundoActual est)) of
              Just obj -> ([descObjeto obj], est)
              Nothing  -> (["No encuentras detalles sobre ese objeto."], est)
       else if not (tieneLuz est)
              then (["Está muy oscuro para examinar objetos en la sala."], est)
              else (["No ves '" ++ unIdObjeto oid ++ "' ni aquí ni en tu inventario."], est)

-- Lista los objetos que lleva el jugador.
mostrarInventario :: Estado -> [String]
mostrarInventario est =
  case inventario est of
    [] -> [ "Tu inventario está vacío." ]
    xs -> [ "Llevas contigo: " ++ intercalate ", " (map unIdObjeto xs) ]


-- Comprueba si se ha cumplido la meta del mundo y añade el mensaje oficial.
verificarVictoria :: [String] -> Estado -> ([String], Estado)
verificarVictoria msgs est =
  if haGanado est
    then (msgs ++ ["*** ¡Has ganado! ***"], est)
    else (msgs, est)

--  Elimina únicamente la primera aparición de un elemento en una lista.
quitarPrimero :: Eq a => a -> [a] -> [a]
quitarPrimero _ [] = []
quitarPrimero x (y:ys)
  | x == y    = ys
  | otherwise = y : quitarPrimero x ys

dirTexto :: Direccion -> String
dirTexto Norte  = "norte"
dirTexto Sur    = "sur"
dirTexto Este   = "este"
dirTexto Oeste  = "oeste"
dirTexto Arriba = "arriba"
dirTexto Abajo  = "abajo"

textoAyuda :: [String]
textoAyuda =
  [ "Comandos disponibles:"
  , "  ir <dirección>     - Moverse (norte, sur, este, oeste, arriba, abajo)"
  , "  mirar              - Describir la sala actual"
  , "  tomar <objeto>     - Recoger un objeto de la sala (sinónimo: coger)"
  , "  soltar <objeto>    - Dejar un objeto del inventario en la sala"
  , "  examinar <objeto>  - Ver la descripción de un objeto"
  , "  inventario         - Listar objetos que llevas (sinónimo: inv)"
  , "  guardar <archivo>  - Guardar la partida actual"
  , "  cargar <archivo>   - Cargar una partida guardada"
  , "  ayuda              - Mostrar esta ayuda"
  , "  salir              - Salir del juego"
  ]