module ReconocedorSpec (pruebasReconocedor) where

import Data.Maybe (listToMaybe)
import Motor.Reconocedor
  (ejecutarReconocedor, identificador, lineaClaveValor, reconocerMeta, salida)
import Motor.Tipos (Direccion (..), IdObjeto (..), IdSala (..), Meta (..), Salida (..))
import Test.HUnit

-- Reúne los casos del reconocedor.
pruebasReconocedor :: Test
pruebasReconocedor =
  TestList
    [ pruebaLineaClaveValor
    , pruebaIdentificador
    , pruebaSalida
    , pruebaMeta
    ]

-- lineaClaveValor separa una línea en su clave y su valor. La clave termina
-- en el primer ':' y el valor se recorta por ambos extremos.
pruebaLineaClaveValor :: Test
pruebaLineaClaveValor = TestLabel "lineaClaveValor" $ TestCase $ do
  assertEqual "separa clave y valor"
    (Just ("CLAVE", "valor"))
    (ejecutarReconocedor lineaClaveValor "CLAVE: valor")

  assertEqual "ignora espacios al inicio y recorta el valor"
    (Just ("MUNDO", "Entrega a última hora"))
    (ejecutarReconocedor lineaClaveValor "   MUNDO:   Entrega a última hora   ")

  assertEqual "admite los dos puntos pegados al valor"
    (Just ("SALA", "cuarto"))
    (ejecutarReconocedor lineaClaveValor "SALA:cuarto")

  assertEqual "rechaza una línea sin dos puntos"
    Nothing
    (ejecutarReconocedor lineaClaveValor "sin dos puntos")

  assertEqual "rechaza una clave vacía"
    Nothing
    (ejecutarReconocedor lineaClaveValor ": valor")

  assertEqual "rechaza una línea en blanco"
    Nothing
    (ejecutarReconocedor lineaClaveValor "   ")

-- identificador consume letras minúsculas, dígitos y guiones bajos, y se
-- detiene en el primer carácter ajeno a esa familia.
pruebaIdentificador :: Test
pruebaIdentificador = TestLabel "identificador" $ TestCase $ do
  assertEqual "acepta letras, dígitos y guion bajo"
    (Just "llave_2")
    (ejecutarReconocedor identificador "llave_2")

  assertEqual "acepta letras acentuadas"
    (Just "año")
    (ejecutarReconocedor identificador "año")

  assertEqual "acepta un identificador que empieza con guion bajo"
    (Just "_x")
    (ejecutarReconocedor identificador "_x")

  assertEqual "consume la coincidencia más larga"
    (Just ("llave_2", " resto"))
    (listToMaybe (identificador "llave_2 resto"))

  assertEqual "rechaza mayúsculas"
    Nothing
    (ejecutarReconocedor identificador "Llave")

  assertEqual "rechaza un guion al inicio"
    Nothing
    (ejecutarReconocedor identificador "-x")

  assertEqual "rechaza la entrada vacía"
    Nothing
    (ejecutarReconocedor identificador "")

-- salida reconoce una dirección, una flecha y una sala de destino, con un
-- requisito opcional introducido por la palabra "requiere".
pruebaSalida :: Test
pruebaSalida = TestLabel "salida" $ TestCase $ do
  assertEqual "reconoce una salida abierta"
    (Just (Norte, Salida (IdSala "sala") Nothing))
    (ejecutarReconocedor salida "norte -> sala")

  assertEqual "reconoce una salida con requisito"
    (Just (Oeste, Salida (IdSala "b") (Just (IdObjeto "llave"))))
    (ejecutarReconocedor salida "oeste -> b requiere llave")

  assertEqual "rechaza una dirección inexistente"
    Nothing
    (ejecutarReconocedor salida "noreste -> b")

  assertEqual "rechaza texto después del destino"
    Nothing
    (ejecutarReconocedor salida "norte -> b por favor")

-- reconocerMeta acepta las dos formas de meta: llegar a una sala o llevar un
-- objeto a una sala.
pruebaMeta :: Test
pruebaMeta = TestLabel "reconocerMeta" $ TestCase $ do
  assertEqual "reconoce llegar a una sala"
    (Just (LlegarA (IdSala "x")))
    (ejecutarReconocedor reconocerMeta "llegar a x")

  assertEqual "reconoce llevar un objeto a una sala"
    (Just (LlevarA (IdObjeto "gema") (IdSala "torre")))
    (ejecutarReconocedor reconocerMeta "llevar gema a torre")

  assertEqual "rechaza llegar sin la preposición"
    Nothing
    (ejecutarReconocedor reconocerMeta "llegar x")

  assertEqual "rechaza llevar sin el objeto"
    Nothing
    (ejecutarReconocedor reconocerMeta "llevar a x")
