%define STD_OUTPUT_HANDLE -11
%define NULL 0
%define NEWLINE 0x0A

section .data
    hello db 'Hello, World!', NEWLINE, 0  ; String to print
    hello_len equ $ - hello      ; Length of the string

section .bss
    bytes_written resd 1         ; Storage for the number of bytes written

section .text
    global _start
    extern _ExitProcess@4  ; https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-exitprocess
    extern _GetStdHandle@4 ; https://learn.microsoft.com/en-us/windows/console/getstdhandle
    extern _WriteFile@20

    ;STD_OUTPUT_HANDLE equ -11    ; Constant for standard output handle

_start:

    ; Get the handle for standard output
    push STD_OUTPUT_HANDLE
    call _GetStdHandle@4
    mov ebx, eax                 ; Save the handle in ebx

    ; Write the string to standard output
    push dword 0                 ; Overlapped (NULL)
    push bytes_written           ; Pointer to number of bytes written
    push hello_len               ; Number of bytes to write
    push hello                   ; Pointer to the string
    push ebx                     ; Handle to standard output
    call _WriteFile@20

    ; Exit the process
    push dword 0                 ; Exit code
    call _ExitProcess@4