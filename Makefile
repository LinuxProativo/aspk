# @file Makefile
# Compiles ASM project into build directory

ASM    = nasm
LD     = ld
BUILD  = build
STRIP  = strip

# >>> NOME DO PROGRAMA (MUDE AQUI QUANDO QUISER)
APP    = aspk

all: $(BUILD)/$(APP)

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/$(APP): aspk.asm | $(BUILD)
	$(ASM) -f elf64 aspk.asm -o $(BUILD)/$(APP).o
	$(LD) -nostdlib -static $(BUILD)/$(APP).o -o $(BUILD)/$(APP)
	$(STRIP) build/$(APP)

clean:
	rm -rf $(BUILD)
