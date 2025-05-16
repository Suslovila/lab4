global main
extern printf, scanf, fopen, fprintf, fclose
extern fabs

section .data
  fmt_scan:   db      "%f",0
  fmt_sum:    db      "series sum = %f", 10,0
  fmt_file:   db      "n = %d term = %f", 10,0
  fmt_errarg: db      "Usage: %s <terms_file>", 10,0


  mode_w:     db      "w",0
    one:           dq 1.0             ; константа 1.0
    four:          dq 4.0             ; для коэффициента 4
    minus_one:     dq -1.0            ; для смены знака

section .bss
  a:          resd    1
  x:          resd    1
  eps:        resd    1
  sum_res:    resq    1    ;для накопления суммы
  term_cur:   resq    1    ;текущий член ряда
  x2_val:        resq 1             ; x^2 (double)

  fp:         resq    1    

section .text
main:
  push    rbp
    mov     rbp,rsp
    
    cmp     rdi, 2      ;проверка количества аргументов
    jge     .have_file
     ;если меньше 2 ошибка и возвращаем 1
    mov     rdi, fmt_errarg
    mov     rsi, [rsp + 16]
    xor     eax, eax
    call    printf
    mov     eax, 1
    jmp     .exit

.have_file:

  mov     rbx, rsi        
    mov     r12, [rbx + 8]

    ;ввод x
    mov     rdi, fmt_scan
    lea     rsi, [rel x]
    xor     eax, eax
    call    scanf
    ;ввод eps
    mov     rdi, fmt_scan
    lea     rsi, [rel eps]
    xor     eax, eax
    call    scanf

  mov     rdi, r12          
    mov     rsi, mode_w
    call    fopen
    mov     [rel fp], rax
    test    rax, rax
    je      .err_fopen


    mov   r14d, 1 

movss   xmm0, [rel x]
    cvtss2sd xmm0, xmm0
    movapd  xmm1, xmm0
    mulsd   xmm1, xmm1
    movsd   [rel x2_val], xmm1


    movsd   xmm0, [rel x2_val]      ; xmm0 = x^2
    mulsd   xmm0, [rel minus_one]   ; xmm0 = -x^2
    movsd   [rel term_cur], xmm0    ; term_cur := a = -x^2

    movsd   xmm1, xmm0              ; xmm1 = a
    movsd   xmm0, [rel one]     ; xmm0 = 1.0  (предыдущая sum_res)
    addsd   xmm0, xmm1              ; xmm0 = 1 + a
    movsd   [rel sum_res], xmm0     ; sum_res := 1 + a

    mov     rdi, [rel fp]
    mov     rsi, fmt_file
    mov     edx, r14d
    cvtsd2ss xmm0, [rel term_cur]
    cvtss2sd xmm0, xmm0
    mov     eax, 1             
    call    fprintf


.loop_series:

  inc     r14d

    ; factor = (4 * x^2) / (2n*(2n-1))
    movsd   xmm0, [rel x2_val]
    mulsd   xmm0, [rel four]   ; xmm0 = 4*x^2

    ; вычислим denom = 2n*(2n-1) в rdx
    ;mov     eax, r14d
    lea     edx, [r14d+r14d]     ; edx = 2n
    mov     ecx, edx
    dec     ecx                ; ecx = 2n-1
    imul    edx, ecx           ; edx = 2n*(2n-1)

    ; переведём denom в double

    ; хрень
    cvtsi2sd xmm1, rdx

    ; factor /= denom
    divsd   xmm0, xmm1         ; xmm0 = factor

    ; term_cur *= factor и меняем знак
    movsd   xmm1, [rel term_cur]
    mulsd   xmm1, xmm0
    mulsd   xmm1, [rel minus_one]
    movsd   [rel term_cur], xmm1

    
  ;sum += term
    movsd   xmm0, [rel sum_res]
    addsd   xmm0, xmm1
    movsd   [rel sum_res], xmm0

    ;если term < eps - выходим
    movsd   xmm0, xmm1
    call    fabs
    cvtsd2ss xmm1, xmm0       
    movss   xmm2, [rel eps]
    ucomiss xmm1, xmm2
    jb      .done_series   

  ;запись в файл
    mov     rdi, [rel fp]
    mov     rsi, fmt_file
    mov     edx, r14d
    cvtsd2ss xmm0, [rel term_cur]
    cvtss2sd xmm0, xmm0
    mov     eax, 1             
    call    fprintf
    jmp     .loop_series

;конец цикла и печать результата
.done_series:
  mov     rdi, [rel fp]
    call    fclose

    ;вывод в консоль
    mov     rdi, fmt_sum
    cvtsd2ss xmm0, [rel sum_res]
    cvtss2sd xmm0, xmm0
    mov     eax, 1
    call    printf

    xor     eax, eax
    
.exit:
  mov rsp, rbp
  pop rbp
  ret
;a < 0
.err_a_le0:
  mov     rdi, fmt_erra
    xor     eax, eax
    call    printf
    mov     eax, 1
    jmp     .exit
;файл не открылся
.err_fopen:
  mov     rdi, fmt_errarg
  mov     rsi, [rsp+16]
  xor     eax, eax
    call    printf
  mov     eax, 1
  jmp     .exit