# SDL3 su Ubuntu (WSL) + Zig — Setup completo + build Windows

Questa guida documenta la “trafila” per far funzionare **SDL3** su **Ubuntu in WSL** (con finestra) e per compilare il progetto Zig.
Include anche le opzioni per produrre un eseguibile Windows.

> Nota: su Windows 11 è consigliato usare **WSLg** (GUI integrata). Su Windows 10 la GUI richiede un X server esterno.

---

## 0) Prerequisiti WSL (GUI)

### Verifica WSLg (Windows 11)

```bash
echo "$WAYLAND_DISPLAY"
echo "$DISPLAY"
```

Se almeno uno dei due è valorizzato (tipicamente `WAYLAND_DISPLAY=wayland-0`), la GUI è attiva.

Se non lo è, su Windows 11 aggiorna WSL (da PowerShell):

```powershell
wsl --update
wsl --shutdown
```

Poi riapri Ubuntu.

---

## 1) Dipendenze di build (X11/Wayland + audio + GL)

Installa i pacchetti necessari (coprono le dipendenze tipiche richieste da SDL3 su Linux):

```bash
sudo apt update
sudo apt install -y \
  build-essential cmake ninja-build pkg-config git \
  libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxinerama-dev libxxf86vm-dev \
  libxss-dev libxtst-dev \
  libwayland-dev wayland-protocols libxkbcommon-dev \
  libegl1-mesa-dev libgl1-mesa-dev \
  libasound2-dev libpulse-dev
```

> Se CMake segnala ulteriori dipendenze mancanti, di solito sono sempre pacchetti `libXXXX-dev`.

---

## 2) Installazione SDL3

### Opzione A — via apt (se disponibile sulla tua Ubuntu)

Prova prima:

```bash
sudo apt install -y libsdl3-dev
pkg-config --modversion sdl3
```

Se `pkg-config` stampa una versione, SDL3 è installata.

### Opzione B — build da sorgente (fallback, funziona sempre)

```bash
cd ~
git clone https://github.com/libsdl-org/SDL.git -b main SDL3-src
cd SDL3-src

rm -rf build
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
ninja -C build
sudo ninja -C build install
sudo ldconfig
```

Verifica:

```bash
pkg-config --modversion sdl3
pkg-config --cflags --libs sdl3
```

---

## 3) Se `pkg-config` non trova SDL3 dopo l’install

Quando SDL3 viene installata in `/usr/local`, i file `.pc` possono finire in:

- `/usr/local/lib/pkgconfig`
- `/usr/local/share/pkgconfig`

Trova il file `.pc`:

```bash
sudo find /usr/local -name "sdl3.pc" -o -name "SDL3.pc"
```

Aggiungi al `PKG_CONFIG_PATH` (bash):

```bash
echo 'export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:$PKG_CONFIG_PATH"' >> ~/.bashrc
source ~/.bashrc
```

Riprova:

```bash
pkg-config --modversion sdl3
```

---

## 4) Se Zig non linka SDL3 (lib non trovata)

Controlla che il linker veda `libSDL3.so`:

```bash
ldconfig -p | grep -i sdl3
```

Se non compare ma esiste in `/usr/local/lib`, aggiungi `/usr/local/lib` alle librerie di sistema:

```bash
echo '/usr/local/lib' | sudo tee /etc/ld.so.conf.d/usr-local-lib.conf
sudo ldconfig
ldconfig -p | grep -i sdl3
```

---

## 5) Zig: build.zig moderno (Zig 0.15+)

Con Zig recente, `root_source_file` non è più in `addExecutable`: va creato un modulo.

Esempio `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "hello-sdl3",
        .root_module = root_mod,
    });

    exe.linkSystemLibrary("SDL3");
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```

Build & run:

```bash
zig build run
```

Release:

```bash
zig build -Doptimize=ReleaseFast run
```

---

## 6) SDL3 + Zig: nota importante sui return value

In SDL3 diverse funzioni tornano `bool`/`int` e Zig non permette di ignorare valori non-void.

Esempio:

❌

```zig
c.SDL_RenderPresent(renderer);
```

✅

```zig
_ = c.SDL_RenderPresent(renderer);
```

Oppure (consigliato) controlla l’errore:

```zig
if (!c.SDL_RenderPresent(renderer)) {
    std.log.err("SDL_RenderPresent failed: {s}", .{c.SDL_GetError()});
}
```

---

# Build per Windows

Ci sono due approcci:

1) **Compilare nativamente su Windows** (più semplice per dipendenze)
2) **Cross-compilare da WSL con Zig** (fattibile, ma serve SDL3 per Windows)

---

## A) Metodo consigliato: build nativo su Windows

### Requisiti

- Zig installato su Windows
- SDL3 dev per Windows (DLL + import library + include)

Opzione pratica:

- scarica/builda SDL3 per Windows
- metti:
  - `SDL3.dll` vicino all’eseguibile
  - import library in `deps/SDL3-win/lib`:
    - `SDL3.lib` (MSVC) **oppure**
    - `libSDL3.dll.a` (MinGW)
  - header in `deps/SDL3-win/include/SDL3/...`

Poi configuri `build.zig` come nella sezione “Cross-compilazione” (stessa logica, cambia solo il target).

---

## B) Cross-compilare da WSL (Zig) → .exe

### Importante

Zig può cross-compilare il tuo codice in `.exe`, ma per linkare SDL3 devi avere **SDL3 compilata per Windows**:

- `SDL3.dll` + import library (`.lib` o `.a`)
- include headers

### 1) Prepara una cartella deps (nel repo)

Esempio:

```
deps/
  SDL3-win/
    include/SDL3/...
    lib/
      SDL3.dll
      libSDL3.dll.a        (per target windows-gnu)
```

> Se usi MSVC (`windows-msvc`) avrai `SDL3.lib` invece di `libSDL3.dll.a`.
> Il percorso più lineare da WSL è usare **windows-gnu** (MinGW) con `.a`.

### 2) Aggiorna build.zig per supportare Windows

Aggiungi una branch: se target è Windows, linka dalla cartella `deps/SDL3-win`.

Esempio minimal:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "hello-sdl3",
        .root_module = root_mod,
    });

    if (target.result.os.tag == .windows) {
        exe.addIncludePath(b.path("deps/SDL3-win/include"));
        exe.addLibraryPath(b.path("deps/SDL3-win/lib"));
        exe.linkSystemLibrary("SDL3");
    } else {
        exe.linkSystemLibrary("SDL3");
    }

    exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```

### 3) Compila per Windows (GNU)

```bash
zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseFast
```

L’output sarà in:

```
zig-out/bin/hello-sdl3.exe
```

### 4) Distribuzione

Per far partire l’eseguibile su Windows, devi avere `SDL3.dll` nella stessa cartella dell’exe (oppure in PATH):

```
hello-sdl3.exe
SDL3.dll
```

---

## Troubleshooting rapido (WSL)

- **Finestra non si apre**:
  - verifica WSLg: `echo $WAYLAND_DISPLAY` / `echo $DISPLAY`
  - esegui l’app e guarda stderr/log

- **pkg-config non trova sdl3**:
  - controlla `PKG_CONFIG_PATH` e dove sta `sdl3.pc`

- **linker non trova libSDL3.so**:
  - controlla `ldconfig -p | grep -i sdl3`
  - aggiungi `/usr/local/lib` a `ld.so.conf.d` e `sudo ldconfig`

---

## Comandi utili

Verifica SDL3 installata:

```bash
pkg-config --modversion sdl3
pkg-config --cflags --libs sdl3
ldconfig -p | grep -i sdl3
```

Build pulita SDL3 (sorgente):

```bash
cd ~/SDL3-src
rm -rf build
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
ninja -C build
sudo ninja -C build install
sudo ldconfig
```
