

%define STD_OUTPUT_HANDLE -11
%define NULL 0
%define NUM_TIMES 9

%macro EXIT_PROCESS 1
    push %1
    call _ExitProcess@4
%endmacro

%macro WRITE_STRING 2
    pushad
    push NULL
    push NULL
    push %2
    push %1
    push ebx
    call _WriteFile@20
    popad
%endmacro

section .data
    hello db 'Hello, World!', 0x0A, 0  ; String to print with a newline
    hello_len equ $ - hello            ; Length of the string

section .text
    global _start
    extern _ExitProcess@4
    extern _GetStdHandle@4
    extern _WriteFile@20

_start:

    push STD_OUTPUT_HANDLE
    call _GetStdHandle@4
    mov ebx, eax 

    ; Initialize loop counter
    mov ecx, NUM_TIMES

print_loop:
    WRITE_STRING hello, hello_len
    loop print_loop

    mov ecx, 20
mark:
    nop
    mov ecx, 20
    loop mark
    ; Exit the process
    EXIT_PROCESS 0