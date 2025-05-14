; cos²x через степенной ряд
; вариант 35   ﻿            Пользователь

global  main
extern  printf, scanf, fopen, fprintf, fclose, fabs     ; libc / libm

section .data
    fmt_scan    db  "%f",0
    fmt_sum     db  "cos^2(x) ≈ %f",10,0
    fmt_file    db  "n = %d   term = %f",10,0
    fmt_errarg  db  "Usage: %s <terms_file>",10,0
    mode_w      db  "w",0

    one         dq  1.0
    four        dq  4.0
    minus_one   dq -1.0

section .bss
    x           resd 1          ; float
    eps         resd 1          ; float
    sum_res     resq 1          ; double
    term_cur    resq 1          ; double
    x2_val      resq 1          ; double
    fp          resq 1          ; FILE *

section .text
; ------------------------------------------------------------
main:
    push rbp
    mov  rbp, rsp                       ; пролог

; ---------- проверка аргументов командной строки -------------
    cmp rdi, 2
    jge have_file                       ; есть имя файла
    mov rdi, fmt_errarg
    mov rsi, [rsi]                      ; argv[0]
    xor eax, eax
    call printf
    mov eax, 1
    jmp exit_program

have_file:
    mov rbx, rsi                        ; rbx = argv
    mov r12, [rbx+8]                    ; r12 = argv[1] (имя файла)

; -------------------- ввод x -------------------------------
    mov rdi, fmt_scan
    lea rsi, [rel x]
    xor eax, eax
    call scanf

; -------------------- ввод eps -----------------------------
    mov rdi, fmt_scan
    lea rsi, [rel eps]
    xor eax, eax
    call scanf

; ------------------ открытие файла -------------------------
    mov rdi, r12                        ; имя
    mov rsi, mode_w
    call fopen
    mov [rel fp], rax
    test rax, rax
    je err_fopen

; ------------- подготовка констант -------------------------
    movss   xmm0, [rel x]               ; float -> xmm0
    cvtss2sd xmm0, xmm0                 ; double
    movapd  xmm1, xmm0
    mulsd   xmm1, xmm1                  ; x²
    movsd   [rel x2_val], xmm1

    movsd   xmm0, [rel one]             ; sum = 1.0
    movsd   [rel sum_res], xmm0

    xor r14d, r14d                      ; n = 0

; ----------------- первый член (n=1) -----------------------
    mov r14d, 1
    movsd   xmm0, [rel x2_val]
    mulsd   xmm0, [rel minus_one]       ; -x²
    movsd   [rel term_cur], xmm0

; |term| < eps ?
    movapd  xmm0, xmm0
    call    fabs
    cvtsd2ss xmm2, xmm0
    movss   xmm3, [rel eps]
    ucomiss xmm2, xmm3
    jb  done_series_first               ; сразу мелко — выход

; sum += term
    movsd   xmm1, [rel sum_res]
    addsd   xmm1, [rel term_cur]
    movsd   [rel sum_res], xmm1

; запись первого члена
    mov     rdi, [rel fp]
    mov     rsi, fmt_file
    mov     edx, r14d
    movsd   xmm0, [rel term_cur]
    mov     al, 1                       ; один float-/double-аргумент
    call    fprintf

; ============= основной цикл (n = 2,3,…) ===================
loop_series:
    inc r14d                            ; n++

; factor = -4*x² / (2n*(2n-1))
    movsd   xmm0, [rel x2_val]
    mulsd   xmm0, [rel four]            ; 4*x²

    mov     eax, r14d
    lea     r8d, [eax+eax]              ; 2n
    mov     r9d, r8d
    dec     r9d                         ; 2n-1
    imul    r8d, r9d                    ; 2n*(2n-1)
    mov     rdx, r8d
    cvtsi2sd xmm1, rdx
    divsd   xmm0, xmm1
    mulsd   xmm0, [rel minus_one]       ; меняем знак

; term *= factor
    movsd   xmm1, [rel term_cur]
    mulsd   xmm1, xmm0
    movsd   [rel term_cur], xmm1

; |term| < eps ?
    movapd  xmm0, xmm1
    call    fabs
    cvtsd2ss xmm2, xmm0
    movss   xmm3, [rel eps]
    ucomiss xmm2, xmm3
    jb  done_series                     ; пора заканчивать

; sum += term
    movsd   xmm0, [rel sum_res]
    addsd   xmm0, xmm1
    movsd   [rel sum_res], xmm0

; запись текущего члена
    mov     rdi, [rel fp]
    mov     rsi, fmt_file
    mov     edx, r14d
    movsd   xmm0, xmm1
    mov     al, 1
    call    fprintf
    jmp loop_series

; ------------------------------------------------------------
done_series_first:                        ; если первый же член < eps
done_series:
    mov rdi, [rel fp]
    call fclose

; --------- вывод итоговой суммы -----------------------------
    mov rdi, fmt_sum
    movsd xmm0, [rel sum_res]
    mov al, 1
    xor eax, eax
    call printf
    xor eax, eax
    jmp exit_program

; --------- ошибка открытия файла ----------------------------
err_fopen:
    mov rdi, fmt_errarg
    mov rsi, [rsi]                      ; argv[0]
    xor eax, eax
    call printf
    mov eax, 1

; ------------------- завершение -----------------------------
exit_program:
    mov rsp, rbp
    pop rbp
    ret
