global main
extern printf, scanf, fopen, fprintf, fclose, fabs

section .data
    fmt_scan:      db "%f",0
    fmt_sum:       db "cos^2(x) ≈ %f",10,0
    fmt_file:      db "n = %d term = %f",10,0
    fmt_errarg:    db "Usage: %s <terms_file>",10,0
    mode_w:        db "w",0

    one:           dq 1.0             ; константа 1.0
    four:          dq 4.0             ; для коэффициента 4
    minus_one:     dq -1.0            ; для смены знака

section .bss
    x:             resd 1             ; входное x (float)
    eps:           resd 1             ; входная точность (float)
    sum_res:       resq 1             ; накопленная сумма (double)
    term_cur:      resq 1             ; текущий член ряда (double)
    x2_val:        resq 1             ; x^2 (double)
    fp:            resq 1             ; FILE*

section .text
main:
    push    rbp
    mov     rbp, rsp

    ; проверяем argc
    cmp     rdi, 2
    jge     .have_file
    mov     rdi, fmt_errarg
    mov     rsi, [rsp+16]
    xor     eax, eax
    call    printf
    mov     eax, 1
    jmp     .exit

.have_file:
    ; argv[1] → имя файла
    mov     rbx, rsi
    mov     r12, [rbx+8]

    ; ввод x (float)
    mov     rdi, fmt_scan
    lea     rsi, [rel x]
    xor     eax, eax
    call    scanf

    ; ввод eps (float)
    mov     rdi, fmt_scan
    lea     rsi, [rel eps]
    xor     eax, eax
    call    scanf

    ; откроем файл для записи
    mov     rdi, r12
    mov     rsi, mode_w
    call    fopen
    mov     [rel fp], rax
    test    rax, rax
    je      .err_fopen

    ; преобразуем x в double и сохраним x^2
    movss   xmm0, [rel x]
    cvtps2pd xmm0, xmm0
    movapd  xmm1, xmm0
    mulsd   xmm1, xmm1
    movsd   [rel x2_val], xmm1

    ; инициализация суммы: sum_res = 1.0
    movsd   xmm0, [rel one]
    movsd   [rel sum_res], xmm0

    xor     r14d, r14d      ; n = 0

    ; --- первый член ряда (n=1): term = - x^2 ---
    mov     r14d, 1
    movsd   xmm0, [rel x2_val]
    mulsd   xmm0, [rel minus_one]
    movsd   [rel term_cur], xmm0

    ; проверка |term| < eps?
    movsd   xmm1, xmm0
    call    fabs
    cvtsd2ss xmm2, xmm0    ; xmm2 = |term| в float
    movss   xmm3, [rel eps]
    ucomiss xmm2, xmm3
    jb      .done_series

    ; прибавляем к сумме и пишем в файл
    movsd   xmm0, [rel sum_res]
    addsd   xmm0, xmm1
    movsd   [rel sum_res], xmm0

    mov     edi, [rel fp]
    mov     esi, fmt_file
    mov     edx, r14d
    cvtsd2ss xmm0, [rel term_cur]
    cvtss2sd xmm0, xmm0
    mov     eax, 1
    call    fprintf

    ; --- последующие члены n=2,3,… ---
.loop_series:
    inc     r14d            ; n++

    ; factor = (4 * x^2) / (2n*(2n-1))
    movsd   xmm0, [rel x2_val]
    mulsd   xmm0, [rel four]   ; xmm0 = 4*x^2

    ; вычислим denom = 2n*(2n-1) в rdx
    mov     eax, r14d
    lea     edx, [rax+rax]     ; edx = 2n
    mov     ecx, edx
    dec     ecx                ; ecx = 2n-1
    imul    edx, ecx           ; edx = 2n*(2n-1)

    ; переведём denom в double
    cvtsi2sd xmm1, rdx

    ; factor /= denom
    divsd   xmm0, xmm1         ; xmm0 = factor

    ; term_cur *= factor и меняем знак
    movsd   xmm1, [rel term_cur]
    mulsd   xmm1, xmm0
    mulsd   xmm1, [rel minus_one]
    movsd   [rel term_cur], xmm1

    ; проверка |term| < eps?
    movsd   xmm2, xmm1
    call    fabs
    cvtsd2ss xmm3, xmm2
    movss   xmm4, [rel eps]
    ucomiss xmm3, xmm4
    jb      .done_series

    ; sum += term
    movsd   xmm0, [rel sum_res]
    addsd   xmm0, xmm1
    movsd   [rel sum_res], xmm0

    ; запись в файл
    mov     edi, [rel fp]
    mov     esi, fmt_file
    mov     edx, r14d
    cvtsd2ss xmm0, xmm1
    cvtss2sd xmm0, xmm0
    mov     eax, 1
    call    fprintf

    jmp     .loop_series

.done_series:
    ; закрываем файл
    mov     rdi, [rel fp]
    call    fclose

    ; выводим итоговую сумму
    mov     rdi, fmt_sum
    cvtsd2ss xmm0, [rel sum_res]
    cvtss2sd xmm0, xmm0
    xor     eax, eax
    call    printf

    xor     eax, eax

.exit:
    mov     rsp, rbp
    pop     rbp
    ret

.err_fopen:
    mov     rdi, fmt_errarg
    mov     rsi, [rsp+16]
    xor     eax, eax
    call    printf
    mov     eax, 1
    jmp     .exit
