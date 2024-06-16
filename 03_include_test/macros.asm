%define STD_OUTPUT_HANDLE -11
%define NULL 0
%define NEWLINE 0x0A

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
