global main
extern printf, scanf, fopen, fprintf, fclose, fabs

section .data
    fmt_scan:   db "%f",0
    fmt_sum:    db "cos^2(x) ≈ %f",10,0
    fmt_file:   db "n = %d term = %f",10,0
    fmt_errarg: db "Usage: %s <terms_file>",10,0
    mode_w:     db "w",0

    one:        dq 1.0
    four:       dq 4.0
    neg_one:    dq -1.0

section .bss
    x:          resd 1
    eps:        resd 1
    sum_res:    resq 1
    term_cur:   resq 1
    x2_val:     resq 1
    fp:         resq 1

section .text
main:
    push    rbp
    mov     rbp, rsp

    ; argv check
    cmp     rdi, 2
    jge     have_file
    mov     rdi, fmt_errarg
    mov     rsi, [rsp+16]
    xor     eax, eax
    call    printf
    mov     eax, 1
    jmp     exit

have_file:
    ; filename = argv[1]
    mov     rbx, rsi
    mov     r12, [rbx+8]

    ; read x
    mov     rdi, fmt_scan
    lea     rsi, [rel x]
    xor     eax, eax
    call    scanf

    ; read eps
    mov     rdi, fmt_scan
    lea     rsi, [rel eps]
    xor     eax, eax
    call    scanf

    ; open file
    mov     rdi, r12
    mov     rsi, mode_w
    call    fopen
    mov     [rel fp], rax
    test    rax, rax
    je      err_fopen

    ; x → double, x2 = x*x
    movss   xmm0, [rel x]
    cvtps2pd xmm0, xmm0
    movapd  xmm1, xmm0
    mulsd   xmm1, xmm1
    movsd   [rel x2_val], xmm1

    ; sum_res = 1.0
    movsd   xmm0, [rel one]
    movsd   [rel sum_res], xmm0

    xor     r14d, r14d

    ; n=1, term = –x^2
    mov     r14d, 1
    movsd   xmm0, [rel x2_val]
    mulsd   xmm0, [rel neg_one]
    movsd   [rel term_cur], xmm0

    ; if |term| < eps → done
    movsd   xmm0, [rel term_cur]
    call    fabs
    cvtsd2ss xmm2, xmm0
    movss   xmm3, [rel eps]
    ucomiss xmm2, xmm3
    jb      done_series

    ; sum += term
    movsd   xmm1, [rel term_cur]
    movsd   xmm0, [rel sum_res]
    addsd   xmm0, xmm1
    movsd   [rel sum_res], xmm0

    ; fprintf first term
    mov     rdi, [rel fp]
    mov     rsi, fmt_file
    mov     rdx, r14d
    cvtsd2ss xmm0, [rel term_cur]
    cvtss2sd xmm0, xmm0
    mov     eax, 1
    call    fprintf

.loop_series:
    inc     r14d

    ; factor = 4*x^2
    movsd   xmm0, [rel x2_val]
    mulsd   xmm0, [rel four]

    ; denom = 2n*(2n-1)
    lea     edx, [r14 + r14]    ; edx = 2*n
    mov     ecx, edx
    dec     ecx                 ; ecx = 2n-1
    imul    edx, ecx            ; edx = 2n*(2n-1)

    ; factor /= denom
    cvtsi2sd xmm1, edx
    divsd   xmm0, xmm1

    ; term *= factor, change sign
    movsd   xmm2, [rel term_cur]
    mulsd   xmm2, xmm0
    mulsd   xmm2, [rel neg_one]
    movsd   [rel term_cur], xmm2

    ; if |term| < eps → done
    movsd   xmm0, xmm2
    call    fabs
    cvtsd2ss xmm3, xmm0
    movss   xmm4, [rel eps]
    ucomiss xmm3, xmm4
    jb      done_series

    ; sum += term
    movsd   xmm1, xmm2
    movsd   xmm0, [rel sum_res]
    addsd   xmm0, xmm1
    movsd   [rel sum_res], xmm0

    ; fprintf term
    mov     rdi, [rel fp]
    mov     rsi, fmt_file
    mov     rdx, r14d
    cvtsd2ss xmm0, xmm2
    cvtss2sd xmm0, xmm0
    mov     eax, 1
    call    fprintf

    jmp     .loop_series

done_series:
    ; close file
    mov     rdi, [rel fp]
    call    fclose

    ; print result
    mov     rdi, fmt_sum
    movsd   xmm0, [rel sum_res]
    cvtsd2ss xmm0, xmm0
    cvtss2sd xmm0, xmm0
    xor     eax, eax
    call    printf

exit:
    mov     rsp, rbp
    pop     rbp
    ret

err_fopen:
    mov     rdi, fmt_errarg
    mov     rsi, [rsp+16]
    xor     eax, eax
    call    printf
    mov     eax, 1
    jmp     exit
