

%define STD_OUTPUT_HANDLE -11
%define NULL 0
%define NUM_TIMES 10

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
    hello db 'Hello, World!', 0x0A, 0
    hello_len equ $ - hello

section .text
    global _start
    extern _ExitProcess@4 ; https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-exitprocess
    extern _GetStdHandle@4; https://learn.microsoft.com/en-us/windows/console/getstdhandle
    extern _WriteFile@20 ;https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-writefile

_start:

    push STD_OUTPUT_HANDLE
    call _GetStdHandle@4
    mov ebx, eax 

    ; Initialize loop counter
    mov ecx, NUM_TIMES
print_loop:
    WRITE_STRING hello, hello_len
    loop print_loop
    EXIT_PROCESS 0