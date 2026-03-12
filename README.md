<p align="center">
  <img src="logo.png" width="300">
</p>

<h1 align="center"> ⚙️ aspk - Assembly Shell Pack</h1> 
<h3 align="center">Transform your shell scripts (sh/bash) into self-contained ELF executables with zero dependencies.</h3>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux-FCC624?&logo=linux&style=flat-square"/>
  <img src="https://img.shields.io/github/actions/workflow/status/LinuxProativo/aspk/makefile.yml?label=Test&style=flat-square&logo=github"/>
  <img src="https://img.shields.io/badge/Arch-x86__64-00599c?style=flat-square&logo=chainlink"/>
  <img src="https://img.shields.io/badge/Binary_Size-9_KiB-44cc11?style=flat-square&logo=paperlessngx"/>
  <img src="https://img.shields.io/badge/Language-Assembly-2b5b75?style=flat-square&logo=assemblyscript&logoColor=white"/>
  <img src="https://img.shields.io/badge/Build-Makefile-444444?style=flat-square&logo=gnu&logoColor=white"/>
  <img src="https://img.shields.io/github/license/LinuxProativo/aspk?color=673ab7&label=License&style=flat-square&logo=opensourcehardware&logoColor=white"/>
</p>

## 🚀 What is ASPK?

**ASPK** (Assembly Shell Pack) is a minimalistic shell script packer written entirely
 in x86-64 assembly. It converts traditional shell scripts into fully standalone ELF
 executables, embedding both runtime logic and the original script directly inside
 the binary.

The generated file behaves like a native Linux program while preserving the original
shell semantics — no interpreter flags, no external loaders, and no runtime dependencies.

## ✨ Features

- **Auto-detection** 🎯   
  Automatically detects `#!/bin/sh` or `#!/bin/bash`

- **Standalone** 📦  
  Fully standalone binaries with embedded scripts

- **Static** ⚡  
  Zero libc and zero dynamic dependencies

- **Simple** 🔧   
  One command to pack, one binary to distribute, no runtime overhead

- **Small** 🪶  
  Extremely small runtime footprint (~9 KiB)

- **Portability** 🐧   
  Portable across all x86-64 Linux systems

## 🛠️ Building

```bash
$ git clone https://github.com/LinuxProativo/aspk.git
$ cd aspk
$ make

# Optional: Install system-wide
$ sudo cp build/aspk /usr/local/bin/
```

## 📖 Usage

```bash
aspk <script.sh>
```

ASPK validates the script header, embeds the contents into a handcrafted ELF binary, and outputs a ready-to-run executable using the `.aspk` extension.

**Input**: Any shell script with `#!/bin/sh` or `#!/bin/bash` shebang  
**Output**: Binary with `.aspk` extension

## 📝 Examples

### Basic Example
```bash
$ cat hello.sh
#!/bin/sh
echo "Hello from Assembly Shell Pack!"

$ ./aspk hello.sh
Success: Binary created -> hello.aspk

$ ./hello.aspk
Hello from Assembly Shell Pack!
```

### Bash Features
```bash
$ cat info.sh
#!/bin/bash
echo "Bash version: $BASH_VERSION"
declare -a fruits=("apple" "banana")
echo "Fruits: ${fruits[@]}"

$ ./aspk info.sh
Success: Binary created -> info.aspk

$ ./info.aspk
Bash version: 5.1.16(1)-release
Fruits: apple banana
```

## 🏗️ Execution Flow

### 📦 Packing Phase

- **Read target script**  
  ASPK reads target script for embed

- **Validates interpreter**  
  Validate the correct shebang for run script

- generates an ELF binary  
  Builds ELF header manually for generate binary

- **Appends runtime loader**  
  Runtime code to detect interpreter (sh vs bash)

- **complete script embedded**  
  Embeds script data directly in binary

### ⚡ Runtime Phase

- **Detect Interpreter**  
  Resolves its own memory position (PIC) and detect the interpreter from embedded shebang

- **Extact script**  
  Extracts embedded script to execute

- **Write script to temp file**  
  Writes the script to secure temporary buffer

- **Run Script**  
  Executes using correct interpreter (`/bin/sh` or `/bin/bash`)

## ⚙️ Technical Details

- **Platform**: Linux (tested on Slackware)
- **Assembler**: NASM
- **Binary size**: 9.0 KiB
- **Binary Runtime size**: Original script + ~300 bytes overhead
- **Dependencies**: None (runtime)

## 🎯 Use Cases

- ✅ Distribute CLI tools without requiring users to have the script
- ✅ Create standalone installers
- ✅ Package deployment scripts
- ✅ Build portable utilities
- ✅ Simplify script distribution

## ⚠️ Limitations

- Only supports `#!/bin/sh` and `#!/bin/bash`
- Requires `/tmp` to be writable
- Scripts are embedded unencrypted (anyone can extract them)
- x86-64 Linux only

## 🐛 Troubleshooting

- **"Usage: shellpack <script.sh>"**  
  ➜ Provide a script file as argument

- **"Incompatible script"**  
  ➜ Shebang must be exactly `#!/bin/sh` or `#!/bin/bash`

- **"Could not open or read"**  
  ➜ Check file exists and has read permissions

- **Binary doesn't execute**  
  ➜ Verify `/tmp/` is writable and executable

## 📜 GNU General Public License

This repository has scripts that were created to be free software.  
Therefore, they can be distributed and/or modified within the terms of the ***GNU General Public License***.

> ### See the [General Public License](LICENSE) file for details.

## 📬 Contact & Support

* 📧 **Email:** [m10ferrari1200@gmail.com](mailto:m10ferrari1200@gmail.com)
* 📧 **Email:** [contatolinuxdicaspro@gmail.com](mailto:contatolinuxdicaspro@gmail.com)

<p align="center">
  <i>Made with ❤️ and assembly.</i>
</p>
