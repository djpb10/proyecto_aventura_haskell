-- Módulo: Motor.Tipos
-- Define el modelo de dominio puro del motor de aventuras de texto,
-- incluyendo el soporte para la variante Oscuridad.
module Motor.Tipos
( -- * Identificadores y Direcciones
  IdSala(..)
  ,IdObjeto(..)
  ,Direccion(..)
-- * Elementos del Mundo
  ,Salida(..)
  ,Meta(..)
  ,Objeto(..)
  ,Sala(..)
  ,Mundo(..)
-- * Dinámica del Juego y Comandos
  ,Estado(..)
  ,Comando(..)
-- * Manejo de Errores
  ,ErrorMundo(..)
) where

import qualified Data.Map.Strict as Map

-- Identificador único de una sala.
-- Se usa newtype para evitar confundir identificadores de salas y objetos
-- en tiempo de compilación, ya que tienen espacios de nombres separados.
newtype IdSala = IdSala { unIdSala :: String }
  deriving (Show, Read, Eq, Ord)

-- Identificador único de un objeto.
newtype IdObjeto = IdObjeto { unIdObjeto :: String }
  deriving (Show, Read, Eq, Ord)

-- Direcciones válidas para desplazarse entre salas.
data Direccion = Norte
  | Sur
  | Este
  | Oeste
  | Arriba
  | Abajo
  deriving (Show, Read, Eq, Ord, Enum, Bounded)

-- Representa una salida desde una sala hacia otra.
-- Puede estar abierta (Nothing) o bloqueada requiriendo un objeto (Just IdObjeto).
data Salida = Salida
  { destino   :: IdSala
  , requisito :: Maybe IdObjeto
  } deriving (Show, Read, Eq)

-- Condición de victoria del mundo.
data Meta = LlegarA IdSala
  | LlevarA IdObjeto IdSala
  deriving (Show, Read, Eq)

-- Definición estática de un objeto del mundo.
-- Incluye el atributo 'daLuz' correspondiente a la variante Oscuridad.
data Objeto = Objeto
  { idObjeto   :: IdObjeto
  , descObjeto :: String
  , daLuz      :: Bool      -- True si el objeto declara LUZ: si
  } deriving (Show, Read, Eq)

-- Definición estática de una sala del mundo.
-- Incluye el atributo 'esOscura' correspondiente a la variante Oscuridad.
data Sala = Sala
  { idSala         :: IdSala
  , descSala       :: String
  , salidas        :: Map.Map Direccion Salida
  , objetosInicial :: [IdObjeto]
  , esOscura       :: Bool      -- True si la sala declara OSCURA: si
  } deriving (Show, Read, Eq)

-- Representación completa e inmutable del mundo validado.
data Mundo = Mundo
  { titulo  :: String
  , inicio  :: IdSala
  , meta    :: Meta
  , salas   :: Map.Map IdSala Sala
  , objetos :: Map.Map IdObjeto Objeto
  } deriving (Show, Read, Eq)

-- Representa el estado de una partida en curso.
-- Separa la definición estática del mundo de los elementos que cambian
-- durante la partida (ubicación, inventario y ubicación actual de los objetos).
data Estado = Estado
  { mundoActual    :: Mundo
  , ubicacion      :: IdSala
  , inventario     :: [IdObjeto]
  , objetosEnSalas :: Map.Map IdSala [IdObjeto]
  } deriving (Show, Read, Eq)

-- Comandos que el jugador puede ejecutar en el bucle de juego.
data Comando = Ir Direccion
  | Mirar
  | Tomar IdObjeto
  | Soltar IdObjeto
  | Examinar IdObjeto
  | Inventario
  | Guardar FilePath
  | Cargar FilePath
  | Ayuda
  | Salir
  deriving (Show, Read, Eq)

-- Errores de sintaxis (V1) y validación semántica (V2 - V10).
data ErrorMundo = ErrorSintaxis Int String  -- Número de línea y descripción del error (V1)
  | ErrorValidacion String    -- Descripción del error semántico (V2 - V10)
  deriving (Eq)

-- Instancia personalizada de Show para ErrorMundo.
-- Garantiza que todo mensaje de error comience exactamente con "Error: ",
instance Show ErrorMundo where
  show (ErrorSintaxis linea msg) = "Error: línea " ++ show linea ++ ": " ++ msg
  show (ErrorValidacion msg) = "Error: " ++ msg