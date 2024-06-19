%define STD_OUTPUT_HANDLE -11
%define NULL dword 0
%define NEWLINE 0x0A


; consttants used for _CreateFileA
%define FILE_ATTRIBUTE_NORMAL dword 0x80
%define CREATE_ALWAYS dword 2
%define FILE_SHARE_READ dword 0x00000001
%define GENERIC_READ dword 0x80000000
%define GENERIC_WRITE dword 0x40000000
%define GENERIC_READWRITE dword 0xc0000000
;%define INVALID_HANDLE_VALUE dword -1




section .data
    hello db NEWLINE,'Hello, World!', NEWLINE  ; String to print
    hello_len equ $ - hello      ; Length of the string

    output_path db './out.txt', 0
    output_path_len equ $ - output_path

    float_value dq 3.141         ; Double precision floating point value

section .bss
    bytes_written resd 1         ; Storage for the number of bytes written

section .text
    global _start
    extern _ExitProcess@4  ; https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-exitprocess
    ;extern _GetStdHandle@4 ; https://learn.microsoft.com/en-us/windows/console/getstdhandle
    extern _WriteFile@20 ;https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-writefile
    extern _GetCommandLineA@0
    
    extern _CreateFileA@28; ;https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilea
    
    ;STD_OUTPUT_HANDLE equ -11    ; Constant for standard output handle

_start:

    ; ; Get the handle for standard output
    ; push STD_OUTPUT_HANDLE
    ; call _GetStdHandle@4
    ; mov ebx, eax                 ; Save the handle in ebx

    call _GetCommandLineA@0 ; eax = pointer args

    mov ebx, eax ; ebx = pointer args
    ; move ebx forward, load the value at the desitnation into ecx until ecx reads null
measure_arg:
    movzx ecx, byte [ebx]
    add ebx, 1
    cmp ecx, 0
    jnz measure_arg

    ; eax  pointer to string
    sub ebx, eax ; ebx = len args
    sub ebx, 1
    mov ecx, eax ; ecx = pointer to string

    push ebx
    push ecx
    
    ; Write hellow world string to file
    push NULL                  ; hTemplateFile
    push FILE_ATTRIBUTE_NORMAL ; dwFlagsAndAttributes
    push CREATE_ALWAYS         ; dwCreationDisposition
    push NULL                  ; lpSecurityAttributes
    push FILE_SHARE_READ       ; dwShareMode
    push GENERIC_READWRITE     ; dwDesiredAccess
    push output_path           ; lpFileName
    call _CreateFileA@28 ; eax = file pointer
    
    pop ecx
    pop ebx

    push eax

    ; Write the command line args to the file
    push dword 0                 ; Overlapped (NULL)
    push bytes_written           ; Pointer to number of bytes written
    push dword ebx               ; Number of bytes to write
    push dword ecx               ; Pointer to the string
    push dword eax               ; Handle to file
    call _WriteFile@20
    
    pop eax
    push eax

    ; Write the string to the file
    push dword 0                 ; Overlapped (NULL)
    push bytes_written           ; Pointer to number of bytes written
    push hello_len               ; Number of bytes to write
    push hello                   ; Pointer to the string
    push eax                     ; Handle to standard output
    call _WriteFile@20

    pop eax

    ; Write the double-precision floating point value to the file
    push dword 0                 ; Overlapped (NULL)
    push bytes_written           ; Pointer to number of bytes written
    push dword 8                 ; Number of bytes to write (size of double)
    push float_value             ; Pointer to the double value
    push eax                     ; Handle to file
    call _WriteFile@20

    ; Exit the process
    push dword 0                 ; Exit code
    call _ExitProcess@4