;=====================================================================
;  Лабораторная работа № 4 — Вариант 35 (NASM x86-64, Linux)
;=====================================================================
bits 64

section .data
str_usage:       db "Использование: ./lab4 <имя_файла>",10,0
str_fopen_err:   db "Не удалось открыть файл.",10,0

fmt_scanf:       db "%f %f",0
fmt_term:        db "%d\t%f\n",0
fmt_result:      db "cos^2(x) (libm): %f",10
                 db "cos^2(x) (ряд)  : %f",10
                 db "Членов учтено : %d",10,0

file_mode:       db "w",0

one_float:       dd 1.0
minus_four:      dd -4.0
abs_mask:        dd 0x7FFFFFFF      ; маска для |float|

section .bss
input_x:         resd 1              ; float x
input_eps:       resd 1              ; float ε
series_sum:      resd 1              ; float сумма ряда
current_term:    resd 1              ; float текущий член
terms_used:      resd 1              ; int счётчик n
file_ptr:        resq 1              ; FILE*
libm_result:     resd 1              ; float результат cos^2(x)

section .text
    extern printf, scanf, fopen, fprintf, fclose, cosf, exit
    global main

main:
    ;— про- and эпилог Stack-Frame для System V ABI
    push    rbp
    mov     rbp, rsp

    ;— 1) Проверяем, что argc == 2
    cmp     edi, 2
    je      .open_file
    lea     rdi, [rel str_usage]
    xor     eax, eax        ; 0 SSE-регистров
    call    printf
    mov     edi, 1
    call    exit

.open_file:
    ;— 2) fopen(argv[1], "w")
    mov     rdi, [rsi + 8]  ; argv[1]
    lea     rsi, [rel file_mode]
    call    fopen
    test    rax, rax
    jnz     .file_ok
    lea     rdi, [rel str_fopen_err]
    xor     eax, eax
    call    printf
    mov     edi, 1
    call    exit

.file_ok:
    mov     [rel file_ptr], rax

    ;— 3) scanf("%f %f", &x, &ε)
    lea     rdi, [rel fmt_scanf]
    lea     rsi, [rel input_x]
    lea     rdx, [rel input_eps]
    xor     eax, eax
    call    scanf

    ;— 4) term₁ = -x²
    movss   xmm0, [rel input_x]
    mulss   xmm0, xmm0      ; xmm0 = x²
    xorps   xmm1, xmm1
    subss   xmm1, xmm0      ; xmm1 = -x²
    movss   [rel current_term], xmm1

    ;— sum = 1 + term₁
    movss   xmm0, [rel one_float]
    addss   xmm0, xmm1
    movss   [rel series_sum], xmm0

    mov     dword [rel terms_used], 1

.loop:
    ;— |term| < ε ? → выход
    movss   xmm0, [rel current_term]
    andss   xmm0, [rel abs_mask]    ; абсолютное значение
    movss   xmm1, [rel input_eps]
    comiss  xmm1, xmm0
    jae     .done

    ;— записываем текущий член в файл
    mov     rdi, [rel file_ptr]
    lea     rsi, [rel fmt_term]
    mov     eax, [rel terms_used]
    mov     edx, eax
    cvtss2sd xmm0, [rel current_term]
    xor     r8, r8
    xor     r9, r9
    mov     eax, 1                  ; 1 SSE-регистра vararg
    call    fprintf

    ;— term_{n+1} = term_n * (-4·x²) / ((2n+2)(2n+1))
    movss   xmm0, [rel input_x]
    mulss   xmm0, xmm0
    mulss   xmm0, [rel minus_four]  ; xmm0 = -4·x²

    mov     eax, [rel terms_used]
    shl     eax, 1
    add     eax, 2
    mov     ebx, eax
    dec     ebx
    imul    eax, ebx               ; eax = (2n+2)(2n+1)
    cvtsi2ss xmm1, eax

    movss   xmm2, [rel current_term]
    mulss   xmm2, xmm0
    divss   xmm2, xmm1
    movss   [rel current_term], xmm2

    ; sum += term_{n+1}
    movss   xmm3, [rel series_sum]
    addss   xmm3, xmm2
    movss   [rel series_sum], xmm3

    inc     dword [rel terms_used]
    jmp     .loop

.done:
    ;— cos²(x) через cosf
    movss   xmm0, [rel input_x]
    call    cosf
    mulss   xmm0, xmm0
    movss   [rel libm_result], xmm0

    ;— вывод результатов
    lea     rdi, [rel fmt_result]
    cvtss2sd xmm0, [rel libm_result]
    cvtss2sd xmm1, [rel series_sum]
    mov     edx, [rel terms_used]
    mov     eax, 2                  ; 2 SSE-регистра vararg
    call    printf

    ;— закрываем файл
    mov     rdi, [rel file_ptr]
    call    fclose

    ;— эпилог
    mov     eax, 0
    leave
    ret
