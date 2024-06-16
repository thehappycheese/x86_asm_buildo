section .text
    global _start
    extern _ExitProcess@4

_start:
    ; Set the exit code to 42
    mov eax, 30
    mov ebx, 12
    add eax, ebx
    ; Call ExitProcess
    push eax
    call _ExitProcess@4