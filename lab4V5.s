global main
extern printf, scanf, fopen, fprintf, fclose
extern pow, log, fabs

section .data
  fmt_scan:   db      "%f",0
;   fmt_pow:    db      "pow(a, x) = %f", 10,0
  fmt_sum:    db      "series sum = %f", 10,0
  fmt_file:   db      "n = %d term = %f", 10,0
  fmt_errarg: db      "Usage: %s <terms_file>", 10,0
  fmt_erra:   db      "Error: a must be > 0", 10,0


    breakPoint_id:   db      "breakpoint", 10,0



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
    mov     r12, [rbx + 8]    ;в r12 имя исходного файла
    ;ввод a


    ; mov     rdi, fmt_scan
    ; lea     rsi, [rel a]
    ; xor     eax, eax
    ; call    scanf


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









  mov     rdi, breakPoint_id
  mov     rsi, [rsp+16]
  xor     eax, eax
    call    printf










;   ;проверка на a > 0
;   movss   xmm0, [rel a]
;     pxor    xmm1, xmm1
;     ucomiss xmm0, xmm1
;     jbe     .err_a_le0

  ;pow_res = точное вычисление
;   movss    xmm0, [rel a]
;     cvtps2pd xmm0, xmm0       
;     movss    xmm1, [rel x]
;     cvtps2pd xmm1, xmm1        
;     call    pow               
;     movsd   [rel pow_res], xmm0
  ;считаем ln(a)
;   movss    xmm0, [rel a]
;     cvtps2pd xmm0, xmm0
;     call     log
;     movsd    xmm1, xmm0    
;     ;считаем x * ln(a)      
;     movss    xmm0, [rel x]
;     cvtps2pd xmm0, xmm0         
;     mulsd    xmm0, xmm1     
;     movsd    [rel t_val], xmm0
  ;начальные значения term = sum = 1.0
    movsd   xmm0, [rel one]
  movsd   [rel term_cur], xmm0
    movsd   [rel sum_res], xmm0
  ;открываем файл для записи членов ряда
  mov     rdi, r12          
    mov     rsi, mode_w
    call    fopen
    mov     [rel fp], rax
    test    rax, rax
    je      .err_fopen
    
    xor     r14d, r14d  
;цикл разложения
.loop_series:


  mov     rdi, breakPoint_id
  mov     rsi, [rsp+16]
  xor     eax, eax
    call    printf



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

    ; проверка |term| < eps?

    ; movsd   xmm2, xmm1
    ; call    fabs
    ; cvtsd2ss xmm3, xmm2
    ; movss   xmm4, [rel eps]
    ; ucomiss xmm3, xmm4
    ; jb      .done_series

    ; sum += term
    ; movsd   xmm0, [rel sum_res]
    ; addsd   xmm0, xmm1
    ; movsd   [rel sum_res], xmm0


    
  ;sum += term staroye
    movsd   xmm0, [rel sum_res]
    addsd   xmm0, xmm1
    movsd   [rel sum_res], xmm0



    ;если term < eps конец
    movsd   xmm0, xmm1
    call    fabs
    cvtsd2ss xmm1, xmm0       
    movss   xmm2, [rel eps]
    ucomiss xmm1, xmm2
    jb      .done_series   
  ;fprintf(...)
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
  ;printf(pow...)

    ; mov     rdi, fmt_pow
    ; cvtsd2ss xmm0, [rel pow_res]
    ; cvtss2sd xmm0, xmm0
    ; mov     eax, 1
    ; call    printf


    ;printf(series sum...)
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