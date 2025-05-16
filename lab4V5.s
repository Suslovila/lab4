global main
extern printf, scanf, fopen, fprintf, fclose
extern fabs, cos

section .data
  fmt_scan:   db      "%f",0
  fmt_sum:    db      "series sum = %f", 10,0
  fmt_file:   db      "n = %d term = %f", 10,0
  fmt_errarg: db      "Usage: %s <terms_file>", 10,0
  fmt_lib_result: db      "Result from lib: = %f", 10,0


  mode_w:     db      "w",0
    one:           dq 1.0             ; константа 1.0
    four:          dq 4.0             ; для коэффициента 4
    minus_one:     dq -1.0            ; для смены знака

section .bss
  x:          resd    1
  eps:        resd    1
  sum_res:    resq    1    ;итоговая сумма
  current_member:   resq    1    ;текущий член ряда
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



movss   xmm0, [rel x] 

mov rdi, fmt_lib_result
cvtss2sd xmm0, xmm0
xor eax, eax
mov eax, 1


call cos

mov rdi, fmt_lib_result
xor eax, eax
mov eax, 1
call printf

; возводим в квадрат
movsd  xmm1, xmm0      
mulsd   xmm0, xmm1 

mov rdi, fmt_lib_result
xor eax, eax
call printf


  ;открываем файл для записи членов ряда
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
    movsd   [rel current_member], xmm0    ; current_member := a = -x^2

    movsd   xmm1, xmm0              ; xmm1 = a
    movsd   xmm0, [rel one]     ; xmm0 = 1.0
    addsd   xmm0, xmm1              ; xmm0 = 1 + a
    movsd   [rel sum_res], xmm0     ; sum_res = 1 + a


  ; запишем первый член ряда в файл
    mov     rdi, [rel fp]
    mov     rsi, fmt_file
    mov     edx, r14d
    cvtsd2ss xmm0, [rel current_member]
    cvtss2sd xmm0, xmm0
    mov     eax, 1             
    call    fprintf

;цикл разложения
.loop_series:
  ; следующий индекс n члена ряда
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

    cvtsi2sd xmm1, rdx

    ; factor /= denom
    divsd   xmm0, xmm1         ; xmm0 = factor

    ; current_member *= factor и меняем знак
    
    ; сохраним предыдущий член
    movsd   xmm3, [rel current_member]

    ; далее операции 
    movsd   xmm1, [rel current_member]
    mulsd   xmm1, xmm0
    mulsd   xmm1, [rel minus_one]
    movsd   [rel current_member], xmm1

    
  ;sum += term
    movsd   xmm0, [rel sum_res]
    addsd   xmm0, xmm1
    movsd   [rel sum_res], xmm0


    ;если term < eps конец
    movsd   xmm0, xmm1
    subsd xmm0, xmm3

    call    fabs
    cvtsd2ss xmm1, xmm0       
    movss   xmm2, [rel eps]
    ucomiss xmm1, xmm2
    jb      .done_series

  ; запись члена ряда в файл
    mov     rdi, [rel fp]
    mov     rsi, fmt_file
    mov     edx, r14d
    cvtsd2ss xmm0, [rel current_member]
    cvtss2sd xmm0, xmm0
    mov     eax, 1             
    call    fprintf
    jmp     .loop_series


;конец цикла и печать результата
.done_series:
  mov     rdi, [rel fp]
    call    fclose

    ;вывод общего результата на экран
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

;ошибка открытия файла
.err_fopen:
  mov     rdi, fmt_errarg
  mov     rsi, [rsp+16]
  xor     eax, eax
    call    printf
  mov     eax, 1
  jmp     .exit