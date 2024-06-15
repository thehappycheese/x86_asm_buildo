section .text
    global _start
    extern _ExitProcess@4
    extern _GetCommandLineA@0

_start:
    call _GetCommandLineA@0
    mov ebx, eax
    mov eax, [ebx]
    ; outputs the first 4 characters as an integer to the exit code.
    push eax
    call _ExitProcess@4