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

%define ITERATIONS 5000



section .data

    output_path db './out.txt', 0
    output_path_len equ $ - output_path

    two  dq 2.0
    four dq 4.0

section .bss
    computed_values resq ITERATIONS         ; Storage for computed values

section .text
    global _start
    extern _ExitProcess@4  ; https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-exitprocess
    ;extern _GetStdHandle@4 ; https://learn.microsoft.com/en-us/windows/console/getstdhandle
    extern _WriteFile@20 ;https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-writefile
    extern _GetCommandLineA@0
    
    extern _CreateFileA@28; ;https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilea
    
    ;STD_OUTPUT_HANDLE equ -11    ; Constant for standard output handle

_start:

    ; the world's most crap approximation of pi;
    ; its VERY slow and our float error cripples it to 4 sig figures :(
    ; but it works!
    ; pi = (1-1/3+1/5-1/7 ...) * 4

    fld1 ; st0 = 0 (result)
    fld1 ; st0 = 1 (accumulator)
    fld1 ; st0 = 1, st1= 1
    mov ebx, 0 ; add/sub alternator
    mov eax, computed_values  ; output address
    mov ecx, dword ITERATIONS ; loop counter
iterate:
    fstp qword [eax] ; save st0
    add eax, 8
    fld qword [two]  ; st0=2       , st1=acc , st2=res
    faddp            ; st0 = acc+2 , st1=res
    fld st0          ; st0 = acc   , st1=acc , st2=res
    fld1             ; st0 = 1     , st1=acc , st2=acc, st3=res
    fdivrp           ; st0 = 1/acc , st1=acc , st2=res
    cmp ebx, 0
    not ebx
    jnz skippy
    fchs
skippy:
    fadd st2, st0; st0 = 1/acc; st1=acc, st2=res+1/acc
    loop iterate 

    fstp st0; st0=acc, st1=res
    fstp st0; st0=res

    fld qword [four]; st0=4, st1=res
    fmulp; st0=pi (hopefully)
    
    fst qword [computed_values]

    ; Write the computed value to file
    push NULL                  ; hTemplateFile
    push FILE_ATTRIBUTE_NORMAL ; dwFlagsAndAttributes
    push CREATE_ALWAYS         ; dwCreationDisposition
    push NULL                  ; lpSecurityAttributes
    push FILE_SHARE_READ       ; dwShareMode
    push GENERIC_READWRITE     ; dwDesiredAccess
    push output_path           ; lpFileName
    call _CreateFileA@28 ; eax = file pointer
    

    ; Write the double-precision floating point value to the file
    push dword 0                 ; Overlapped (NULL)
    push NULL                    ; Pointer to number of bytes written
    push dword ITERATIONS*8        ; Number of bytes to write (size of double)
    push computed_values         ; Pointer to the double value
    push eax                     ; Handle to file
    call _WriteFile@20


    ; Exit the process
    push dword 0                 ; Exit code
    call _ExitProcess@4