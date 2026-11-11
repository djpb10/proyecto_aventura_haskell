.PHONY: build run test clean

# Compila y copia automáticamente el binario real a la raíz
build:
	cabal build exe:aventura
	cp $$(cabal list-bin exe:aventura) .

# Compila (si es necesario) y corre el juego con el mundo de ejemplo
run: build
	./aventura mundos/entrega.txt

# Ejecuta la suite de pruebas del proyecto
test:
	cabal test

# Limpia los binarios y archivos temporales de compilación
clean:
	cabal clean
	rm -f aventura aventura.exe