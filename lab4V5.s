; cos²x  = 1 + Σ_{n=1}^∞ (-1)^n · 2^{2n-1}/(2n)! · x^{2n}
; вариант 35, ряд из методички  :contentReference[oaicite:0]{index=0}:contentReference[oaicite:1]{index=1}

default rel
global  main

extern  printf, scanf, fopen, fprintf, fclose, fabs

; -------------------- константы --------------------
section .data
    fmt_scan   db  "%f",0
    fmt_sum    db  "cos^2(x) ≈ %f",10,0
    fmt_file   db  "n = %d  term = %f",10,0
    fmt_err    db  "Usage: %s <terms_file>",10,0
    mode_w     db  "w",0

    one        dq  1.0
    four       dq  4.0
    minus_one  dq -1.0

; --------------------- данные ----------------------
section .bss
    x          resd 1          ; входное x  (float)
    eps        resd 1          ; требуемая точность (float)
    sum_res    resq 1          ; накопленная сумма (double)
    term_cur   resq 1          ; текущее слагаемое (double)
    x2_val     resq 1          ; x² (double)
    fp         resq 1          ; FILE *

; -------------------- код --------------------------
section .text
main:
    ; пролог, выравниваем стек
    push rbp
    mov  rbp, rsp
    sub  rsp, 8                ; 16-байтовое выравнивание

    ; rdi = argc, rsi = argv
    cmp  rdi, 2
    jge  have_file
    lea  rdi, [rel fmt_err]
    mov  rsi, [rsi]            ; argv[0]
    xor  eax, eax
    call printf
    mov  eax, 1
    jmp  cleanup

have_file:                     ; rsi = argv
    mov  r12, [rsi+8]          ; argv[1] – имя файла

    ; ----------- читаем x -------------
    lea  rdi, [rel fmt_scan]
    lea  rsi, [rel x]
    xor  eax, eax
    call scanf

    ; ----------- читаем eps ----------
    lea  rdi, [rel fmt_scan]
    lea  rsi, [rel eps]
    xor  eax, eax
    call scanf

    ; ---------- открываем файл -------
    mov  rdi, r12
    lea  rsi, [rel mode_w]
    call fopen
    mov  [rel fp], rax
    test rax, rax
    je   err_fopen

    ; x (float) → double
    movss   xmm0, [rel x]
    cvtss2sd xmm0, xmm0

    ; x²
    movapd  xmm1, xmm0
    mulsd   xmm1, xmm1
    movsd   [rel x2_val], xmm1

    ; sum_res = 1
    movsd   xmm0, [rel one]
    movsd   [rel sum_res], xmm0

    ; term_cur = -x²  (n = 1)
    movsd   xmm0, [rel x2_val]
    mulsd   xmm0, [rel minus_one]
    movsd   [rel term_cur], xmm0
    mov     r13d, 1            ; n = 1

iterate:
    ; ---------- проверка |term| >= eps? ----------
    movapd  xmm0, [rel term_cur]   ; term → xmm0
    call    fabs                   ; |term|
    movss   xmm1, [rel eps]
    cvtss2sd xmm1, xmm1            ; eps → double
    comisd  xmm0, xmm1
    jb      finish                 ; |term| < eps → конец ряда

    ; ---------- sum += term ----------
    movsd   xmm0, [rel sum_res]
    addsd   xmm0, [rel term_cur]
    movsd   [rel sum_res], xmm0

    ; ---------- записываем в файл ----------
    mov     rdi, [rel fp]
    lea     rsi, [rel fmt_file]
    mov     edx, r13d
    movapd  xmm0, [rel term_cur]   ; 3-й аргумент – double
    xor     eax, eax
    call    fprintf

    ; ---------- следующий член ----------
    ; factor = 4*x² / (2n*(2n-1))
    movsd   xmm0, [rel x2_val]
    mulsd   xmm0, [rel four]       ; 4*x²

    mov     eax, r13d
    lea     edx, [rax+rax]         ; 2n
    mov     ecx, edx
    dec     ecx                    ; 2n-1
    imul    edx, ecx               ; 2n*(2n-1)
    cvtsi2sd xmm1, rdx
    divsd   xmm0, xmm1             ; factor

    ; term *= -factor
    movapd  xmm1, [rel term_cur]
    mulsd   xmm1, xmm0
    mulsd   xmm1, [rel minus_one]
    movsd   [rel term_cur], xmm1

    inc     r13d
    jmp     iterate

finish:
    ; ---------- закрываем файл ----------
    mov     rdi, [rel fp]
    call    fclose

    ; ---------- выводим итог ----------
    lea     rdi, [rel fmt_sum]
    movapd  xmm0, [rel sum_res]
    xor     eax, eax
    call    printf
    xor     eax, eax              ; код возврата 0

cleanup:
    add rsp, 8
    pop rbp
    ret

err_fopen:
    lea  rdi, [rel fmt_err]
    mov  rsi, [rsi]               ; argv[0]
    xor  eax, eax
    call printf
    mov  eax, 1
    jmp cleanup
