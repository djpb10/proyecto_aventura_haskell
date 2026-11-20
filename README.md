# Aventura: motor de aventuras de texto en Haskell

CI-3661 Laboratorio de Lenguajes de Programación I, Sep-Dic 2026.

## Integrantes

- Rossana Ilardo, 20-10043
- David Pereira, 18-10245

## Variante

Se suman los carnets sin el guion: 2010043 + 1810245 = 3820288.
3820288 mod 4 = 0, así que nos tocó la variante 0: **Oscuridad**.

Una sala puede tener `OSCURA: si` y un objeto `LUZ: si`. En una sala oscura,
si el jugador no lleva un objeto con luz, `mirar` no muestra nada de la sala y
no se puede tomar ni examinar lo que hay en ella. Las claves de otras variantes
(`CAPACIDAD`, `PESO`, `TURNOS`, `RECETA`) se rechazan como desconocidas (D20).

## Cómo compilar, correr y probar

Requiere GHC y cabal (se instalan con GHCup).

    cabal build
    cabal test

Jugar un mundo:

    cabal run aventura -- mundos/mundo.txt

Solo validar un mundo (imprime `Mundo válido.` o los errores, y sale con 0 o 1):

    cabal run aventura -- --validar mundos/mundo.txt

Con entrada redirigida desde un guion. En PowerShell el operador `<` no existe,
así que se usa `cmd`:

    cmd /c "cabal run aventura -- mundos/mundo.txt < guiones/mundo.txt"

En Linux o Mac basta con `cabal run aventura -- mundos/mundo.txt < guiones/mundo.txt`.

### Correr el binario directamente

Con `make build` se compila y se copia el ejecutable a la raíz, y se puede usar así:

    ./aventura mundos/entrega.txt
    ./aventura --validar mundos/mundo.txt
    ./aventura mundos/mundo.txt

En Windows, si las tildes salen raras, ejecutar antes en PowerShell:
`[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`.

## Material

- `mundos/entrega.txt` y `guiones/entrega.txt`: mundo de ejemplo y su guion.
- `mundos/mundo.txt` y `guiones/mundo.txt`: nuestro mundo («Apagón en la
  facultad») y el guion que lo gana. La linterna es obligatoria para ganar.
- `mundos/invalidos/`: tres mundos inválidos; cada uno empieza con un comentario
  que lista los errores esperados.
- `mundos/invalido_semantica.txt` e `invalido_sintaxis.txt`: los del material.

## Estructura

- `src/Motor/Tipos.hs`, `Reconocedor.hs`, `Mundo.hs`, `Comandos.hs`,
  `Nucleo.hs`, `Persistencia.hs`: la biblioteca. Solo `Persistencia` toca archivos.
- `app/Main.hs`: argumentos y bucle de juego.
- `test/`: la test-suite (HUnit).

## Documentación

- [DECISIONES.md](DECISIONES.md): decisiones de diseño.
- [IA.md](IA.md): declaración de uso de IA.