; this example fails because for the life of me I cannot get
; printf to be imported.


section .data
    format db "Floating point value: %f", 10, 0  ; format string with newline

section .bss
    float_val resq 1  ; reserve space for a floating-point value

section .text
    global _start
    extern _ExitProcess@4  ; https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-exitprocess
    ;extern _GetStdHandle@4 ; https://learn.microsoft.com/en-us/windows/console/getstdhandle
    ;extern _WriteFile@20 ;https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-writefile
    extern __imp__printf ;https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/printf-printf-l-wprintf-wprintf-l?view=msvc-170

_start:
    ; Initialize the floating-point value (example: 3.14159)
    fld qword [pi]  ; load the floating-point value into ST(0)
    fstp qword [float_val]  ; store the value into float_val

    ; Call printf
    push dword [float_val + 4]  ; push high dword of float_val
    push dword [float_val]  ; push low dword of float_val
    push format  ; push address of format string
    call __imp__printf  ; call printf

    push 0
    call _ExitProcess@4

section .data
    pi dq 3.14159  ; the floating-point value to be printed