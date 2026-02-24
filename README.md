# Demo SDL3 in C (senza Zig)

Questa demo apre una finestra SDL3 e disegna un rettangolo animato orizzontalmente.

## Requisiti

- Un compilatore C (`gcc` o `clang`)
- SDL3 installato con `pkg-config` configurato

## Compilazione (Linux / WSL)

```bash
gcc -std=c11 -O2 -Wall -Wextra src/main.c -o hello-sdl3-c $(pkg-config --cflags --libs sdl3) -lm
```

Oppure con `clang`:

```bash
clang -std=c11 -O2 -Wall -Wextra src/main.c -o hello-sdl3-c $(pkg-config --cflags --libs sdl3) -lm
```

## Esecuzione

```bash
./hello-sdl3-c
```

## Note (Windows/MSYS2)

Con MSYS2 (UCRT64), dopo aver installato SDL3 e toolchain:

```bash
gcc -std=c11 -O2 -Wall -Wextra src/main.c -o hello-sdl3-c $(pkg-config --cflags --libs sdl3) -lm
```
