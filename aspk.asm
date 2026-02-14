; @file aspk.asm
; @brief Assembly Shell Pack - Transform shell scripts into standalone binaries
; @author maurixnovatrento
; @version 1.0
; @date 2026
;
; Assembly Shell Pack converts shell scripts (sh/bash) into self-contained ELF executables.
; The generated binaries detect the interpreter and execute accordingly.

section .data
    ; --- ELF 64 Header ---
    elf_header:
        db 0x7F, "ELF", 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
        dw 2, 62
        dd 1
        dq 0x400078   ; Entry point
        dq 64, 0
        dd 0
        dw 64, 56, 1, 0, 0, 0

    program_header:
        dd 1, 7
        dq 0, 0x400000, 0x400000
    p_filesz_offset:
        dq 0              ; Este valor será preenchido dinamicamente (p_filesz)
    p_memsz_offset:
        dq 0              ; Este valor será preenchido dinamicamente (p_memsz)
        dq 0x1000

    ; --- Runtime Code ---
    ; Este código executa o script embutido usando sh ou bash
    runtime_code:
        ; Descobrir endereço base
        call .get_rip
    .get_rip:
        pop rbx                     ; rbx = RIP atual
        
        ; Calcular offset para o script
        ; Script está após o runtime_code
        lea rsi, [rbx + script_offset_placeholder - .get_rip]
        
        ; Criar arquivo temporário
        lea rdi, [rbx + temp_path - .get_rip]
        mov rax, 2                  ; sys_open
        mov rsi, 577                ; O_CREAT|O_WRONLY|O_TRUNC
        mov rdx, 0o700
        syscall
        test rax, rax
        js .error
        mov r12, rax                ; r12 = fd
        
        ; Escrever script
        lea rsi, [rbx + script_offset_placeholder - .get_rip]
        mov rax, 1                  ; sys_write
        mov rdi, r12
        mov rdx, [rbx + script_size_placeholder - .get_rip]
        syscall
        
        ; Fechar arquivo
        mov rax, 3
        mov rdi, r12
        syscall
        
        ; Executar com interpretador correto
        ; Detectar pelo byte [7] do script
        lea rsi, [rbx + script_offset_placeholder - .get_rip]
        mov al, byte [rsi + 7]
        cmp al, 's'
        je .use_sh
        
        ; Usar bash
        lea rdi, [rbx + bash_path - .get_rip]
        jmp .exec
        
    .use_sh:
        lea rdi, [rbx + sh_path - .get_rip]
        
    .exec:
        ; Preparar argv
        lea rsi, [rbx + argv - .get_rip]
        mov [rsi], rdi              ; argv[0] = interpretador
        lea rax, [rbx + temp_path - .get_rip]
        mov [rsi + 8], rax          ; argv[1] = script path

        lea r8, [rsp + 16]          ; Origem: argv[1] original (pulando o binário)
        lea r9, [rsi + 16]          ; Destino: nosso argv[2]
        xor rcx, rcx
        
        jmp .copy_args_loop         ; Pulo para iniciar a cópia

    .copy_args_loop:
        mov rax, [r8]               ; Lê ponteiro da stack
        test rax, rax               ; É NULL?
        jz .finalize_exec

        mov [r9], rax               ; Copia ponteiro

        add r8, 8
        add r9, 8
        inc rcx
        cmp rcx, 100                ; Limite de segurança
        jl .copy_args_loop

    .finalize_exec:
        mov qword [r9], 0           ; NULL final

        mov rax, 59                 ; sys_execve
        lea rsi, [rbx + argv - .get_rip] ; rsi deve apontar para o início do array
        xor rdx, rdx
        syscall

    .error:
        mov rax, 60
        mov rdi, 1
        syscall

    temp_path:
        db "/tmp/.shXXXXXX", 0
    bash_path:
        db "/bin/bash", 0
    sh_path:
        db "/bin/sh", 0
    script_size_placeholder:
        dq 0
    argv:
        dq 0, 0, 0
    script_offset_placeholder:
        ; O script será inserido aqui
        
    runtime_size equ $ - runtime_code

    ; --- Mensagens do Gerador ---
    help_msg db "Usage: shellpack <script.sh>", 10, \
                "Generates a standalone binary from shell scripts.", 10
    help_len equ $ - help_msg

    error_msg db "Error: Could not open or read the script file.", 10
    error_len equ $ - error_msg

    compat_msg  db "Error: Incompatible script. Only #!/bin/sh or #!/bin/bash supported.", 10
    compat_len  equ $ - compat_msg

    success_msg db "Success: Binary created -> ", 0
    success_len equ $ - success_msg

    mmap_error_msg db "Error: Memory allocation failed.", 10
    mmap_error_len equ $ - mmap_error_msg

section .bss
    script_size resq 1    ; Armazena o tamanho do script
    script_fd resq 1      ; Armazena o file descriptor
    script_mem resq 1     ; Armazena o endereço do mmap
    output_name resb 256  ; Buffer para nome do arquivo de saída
    input_name resb 256   ; Buffer para nome do arquivo de entrada

section .text
    global _start

_start:
    ; 1. Verificação de Argumentos (Help System)
    pop rax             ; rax = argc
    cmp rax, 2          ; Se menor que 2 (falta o arquivo), mostra help
    jne show_help

    pop rax             ; argv[0]
    pop rdi             ; argv[1] (filename)
    
    ; Salvar ponteiro do filename
    mov rsi, rdi
    mov rdi, input_name
    call _copy_string   ; Copia input filename

    ; Agora SIM verificar se existe
    mov rax, 21         ; sys_access
    mov rdi, input_name
    xor rsi, rsi        ; F_OK
    syscall

    cmp rax, -2
    je show_error
    
    ; Gerar nome de saída (substitui extensão por .spk)
    mov rdi, input_name
    call _generate_output_name

    ; Restaurar rdi com input_name para abrir o arquivo
    mov rdi, input_name

    ; 2. Tentar abrir o script do usuário
    mov rax, 2          ; sys_open
    mov rsi, 0          ; O_RDONLY
    syscall
    test rax, rax
    js show_error
    mov [script_fd], rax    ; Salvar fd em variável estática

    ; 3. Pegar tamanho via lseek
    mov rdi, rax
    mov rax, 8          ; sys_lseek
    mov rsi, 0
    mov rdx, 2          ; SEEK_END
    syscall
    test rax, rax
    jle show_error
    mov [script_size], rax  ; Salvar tamanho

    ; 4. Resetar ponteiro do arquivo para o início
    mov rdi, [script_fd]
    mov rax, 8
    mov rsi, 0
    mov rdx, 0          ; SEEK_SET
    syscall

    ; 5. Alocar memória dinamicamente (mmap)
    mov rax, 9          ; sys_mmap
    xor rdi, rdi        ; addr = NULL
    mov rsi, [script_size]  ; length
    mov rdx, 3          ; PROT_READ | PROT_WRITE
    mov r10, 34         ; MAP_PRIVATE | MAP_ANONYMOUS (0x22)
    mov r8, -1          ; fd = -1
    xor r9, r9          ; offset = 0
    syscall
    
    ; Verificar se mmap falhou (retorna -1 ou valor próximo de -1)
    cmp rax, -4096      ; Se rax > -4096, é erro
    jae show_mmap_error
    mov [script_mem], rax   ; Salvar endereço

    ; 6. Ler o arquivo para a memória alocada
    mov rax, 0          ; sys_read
    mov rdi, [script_fd]
    mov rsi, [script_mem]
    mov rdx, [script_size]
    syscall
    
    ; Validar leitura
    test rax, rax
    jle show_error
    
    ; Atualizar tamanho com bytes realmente lidos
    mov [script_size], rax

    ; 7. Validar shebang
    call _validate_interpreter

    ; 8. CALCULAR TAMANHO TOTAL (Header + Program Header + Runtime + Script)
    mov r10, 64 + 56 + runtime_size
    add r10, [script_size]

    ; ATUALIZAR O PROGRAM HEADER NA MEMÓRIA
    mov [p_filesz_offset], r10
    mov [p_memsz_offset], r10
    
    ; ATUALIZAR script_size_placeholder no runtime_code
    mov rax, [script_size]
    mov [script_size_placeholder], rax

    ; 9. Criar o executável final
    mov rax, 2          ; sys_open
    mov rdi, output_name
    mov rsi, 65         ; O_CREAT | O_WRONLY | O_TRUNC (0x41 = 65)
    mov rdx, 0o755
    syscall
    test rax, rax
    js show_error
    mov rbx, rax        ; rbx = fd do output

    ; 10. Escrever a estrutura ELF e o Runtime
    mov rax, 1          ; sys_write - Header ELF
    mov rdi, rbx
    mov rsi, elf_header
    mov rdx, 64
    syscall

    mov rax, 1          ; sys_write - Program Header
    mov rdi, rbx
    mov rsi, program_header
    mov rdx, 56
    syscall

    mov rax, 1          ; sys_write - Runtime
    mov rdi, rbx
    mov rsi, runtime_code
    mov rdx, runtime_size
    syscall

    ; 11. Injetar o script lido
    mov rax, 1          ; sys_write - Script
    mov rdi, rbx
    mov rsi, [script_mem]
    mov rdx, [script_size]
    syscall

    ; 12. Fechar arquivos
    mov rax, 3          ; close output
    mov rdi, rbx
    syscall
    
    mov rax, 3          ; close input
    mov rdi, [script_fd]
    syscall

    ; 13. Liberar memória
    mov rax, 11         ; sys_munmap
    mov rdi, [script_mem]
    mov rsi, [script_size]
    syscall

    ; 14. Mensagem de sucesso
    mov rax, 1
    mov rdi, 1
    mov rsi, success_msg
    mov rdx, success_len
    syscall
    
    ; Imprimir nome do arquivo
    mov rsi, output_name     ; passar string para strlen
    call _strlen             ; rax = tamanho

    mov rdx, rax             ; bytes a escrever
    mov rax, 1               ; sys_write
    mov rdi, 1               ; stdout
    mov rsi, output_name
    syscall
    
    ; Imprimir newline
    mov rax, 1
    mov rdi, 1
    mov rsi, .newline
    mov rdx, 1
    syscall

    jmp exit_clean

.newline:
    db 10

; --- Função de Validação de Interpretador ---
; Layout do shebang:
;   #!/bin/sh    -> [0]# [1]! [2]/ [3]b [4]i [5]n [6]/ [7]s [8]h
;   #!/bin/bash  -> [0]# [1]! [2]/ [3]b [4]i [5]n [6]/ [7]b [8]a [9]s [10]h
_validate_interpreter:
    mov r11, [script_mem]
    mov r9, [script_size]
    
    ; Mínimo "#!/bin/sh" = 9 bytes
    cmp r9, 9
    jb _fail

    ; Verificar "#!" (0x2123 = "!#" em little-endian)
    mov ax, word [r11]
    cmp ax, 0x2123
    jne _fail

    ; Verificar "/bin" (0x6e69622f = "nib/" em little-endian)
    mov eax, dword [r11+2]
    cmp eax, 0x6e69622f
    jne _fail

    ; Verificar "/" na posição 6
    mov al, byte [r11+6]
    cmp al, '/'
    jne _fail
    
    ; Agora verificar posição 7: 's' = /sh, 'b' = /bash
    mov al, byte [r11+7]
    cmp al, 's'
    je _check_sh        ; Se for 's', pode ser /sh
    cmp al, 'b'
    je _check_bash      ; Se for 'b', pode ser /bash
    jmp _fail           ; Se não for nem 's' nem 'b', falha

_check_sh:
    ; Verificar se posição 8 é 'h'
    mov al, byte [r11+8]
    cmp al, 'h'
    je _success
    jmp _fail

_check_bash:
    ; Precisa ter pelo menos 11 bytes para #!/bin/bash
    cmp r9, 11
    jb _fail
    
    ; Verificar 'a' na posição 8
    mov al, byte [r11+8]
    cmp al, 'a'
    jne _fail
    
    ; Verificar 's' na posição 9
    mov al, byte [r11+9]
    cmp al, 's'
    jne _fail
    
    ; Verificar 'h' na posição 10
    mov al, byte [r11+10]
    cmp al, 'h'
    jne _fail

_success:
    ret

_fail:
    jmp show_compat_error

; --- Função: Copiar String ---
; rsi = source, rdi = dest
_copy_string:
    push rsi
    push rdi
.loop:
    lodsb               ; al = [rsi++]
    stosb               ; [rdi++] = al
    test al, al
    jnz .loop
    pop rdi
    pop rsi
    ret

; --- Função: Calcular tamanho da string ---
; rsi = string, retorna tamanho em rax
_strlen:
    push rsi
    xor rax, rax
.loop:
    cmp byte [rsi], 0
    je .done
    inc rsi
    inc rax
    jmp .loop
.done:
    pop rsi
    ret

; --- Função: Gerar nome de saída ---
; rdi = input filename
; Gera output_name substituindo extensão por .spk
_generate_output_name:
    push rsi
    push rdi
    push rcx
    
    ; Copiar input para output
    mov rsi, rdi
    mov rdi, output_name
    call _copy_string
    
    ; Encontrar último '.' ou fim da string
    mov rdi, output_name
    xor rcx, rcx        ; rcx = posição do último '.'
    xor rdx, rdx        ; rdx = contador
    
.find_slash:
    mov al, [rdi + rcx]
    test al, al
    jz .done_slash
    cmp al, '/'
    jne .next
    mov rsi, rcx

.next:
    inc rcx
    jmp .find_slash

.done_slash:
    test rsi, rsi
    jz .no_path
    lea rsi, [rdi + rsi + 1]
    jmp .have_base

.no_path:
    mov rsi, rdi

.have_base:
    ; rsi agora aponta para basename

    ; escrever "./"
    mov byte [output_name], '.'
    mov byte [output_name+1], '/'

    ; copiar basename para output_name+2
    lea rdi, [output_name+2]
    call _copy_string

    ; agora substituir extensão por .aspk
    mov rdi, output_name
    add rdi, 2

    xor rcx, rcx
    xor rdx, rdx

.find_dot:
    mov al, [rdi + rcx]
    test al, al
    jz .end_find
    cmp al, '.'
    jne .next_dot
    mov rdx, rcx

.next_dot:
    inc rcx
    jmp .find_dot

.end_find:
    test rdx, rdx
    jnz .replace
    mov rdx, rcx

.replace:
    lea rdi, [output_name + 2 + rdx]

    mov byte [rdi], '.'
    mov byte [rdi+1], 'a'
    mov byte [rdi+2], 's'
    mov byte [rdi+3], 'p'
    mov byte [rdi+4], 'k'
    mov byte [rdi+5], 0

    pop rcx
    pop rdi
    pop rsi
    ret

show_mmap_error:
    mov rax, 1
    mov rdi, 1
    mov rsi, mmap_error_msg
    mov rdx, mmap_error_len
    syscall
    jmp exit_error

show_compat_error:
    mov rax, 1
    mov rdi, 1
    mov rsi, compat_msg
    mov rdx, compat_len
    syscall
    jmp exit_error

show_help:
    mov rax, 1
    mov rdi, 1
    mov rsi, help_msg
    mov rdx, help_len
    syscall
    jmp exit_error

show_error:
    mov rax, 1
    mov rdi, 1
    mov rsi, error_msg
    mov rdx, error_len
    syscall

exit_error:
    mov rax, 60
    mov rdi, 1          ; exit code 1
    syscall

exit_clean:
    mov rax, 60
    xor rdi, rdi        ; exit code 0
    syscall
