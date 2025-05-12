; lab4.asm — вычисление cos(2x) через cosf и через ряд
; Вариант №35: cos2 x = 1 + Σ_{n=1..∞} (−1)^n 2^{2n−1}/(2n)! · x^{2n}
; Используем рекуррентную формулу:
;   T_{n+1} = T_n * (−4·x²) / ((2n+2)(2n+1))
; Числа с плавающей точкой одинарной точности.

section .data
    fmt_in      db "%f %f", 0                    ; scanf: читаем x и ε
    fmt_term    db "Term %d: %f", 10, 0          ; fprintf: номер и значение члена
    fmt_out     db "Series sum: %f",10,"cos(2*x): %f",10,0
    usage_msg   db "Usage: %s <terms_file>",10,0 ; если argc≠2
    err_scan    db "Error reading input",10,0
    err_open    db "Error opening file %s",10,0
    str_w       db "w",0                         ; режим fopen
    one         dd 1.0                           ; константа 1.0f
    neg4        dd -4.0                          ; константа -4.0f
    twod        dd 2.0                           ; константа 2.0f
    abs_mask    dd 0x7FFFFFFF                    ; маска для |x| (сброс знака)

section .text
    global main
    extern scanf, printf, fopen, fprintf, fclose, cosf, exit

main:
    ; ——— Пролог: выровнять стек на 16 байт
    push    rbp
    mov     rbp, rsp
    sub     rsp, 80
    mov     [rbp-56], rsi       ; сохранить argv для сообщения usage

    ; ——— Проверка числа параметров
    cmp     rdi, 2
    jne     .usage
    ; argv[1] — имя файла для записи членов ряда
    mov     rax, [rsi+8]
    mov     [rbp-16], rax       ; local fp_name

    ; ——— Ввод x и ε
    lea     rdi, [rel fmt_in]
    lea     rsi, [rbp-4]        ; &x
    lea     rdx, [rbp-8]        ; &eps
    xor     eax, eax            ; AL = 0 — число xmm-регов, занятых float-параметрами
    call    scanf
    cmp     eax, 2
    jne     .scan_fail

    ; ——— Предвычисления
    ; x2 = x*x
    movss   xmm0, [rbp-4]
    mulss   xmm0, xmm0
    movss   [rbp-24], xmm0      ; x2

    ; term₁ = −x2  (так как −2·x²/2 = −x²)
    xorps   xmm1, xmm1
    subss   xmm1, xmm0
    movss   [rbp-28], xmm1      ; term

    ; sum = 1 + term
    movss   xmm0, xmm1
    movss   xmm1, [one]
    addss   xmm1, xmm0
    movss   [rbp-32], xmm1      ; sum

    mov     dword [rbp-40], 1   ; n = 1

    ; ——— Открыть файл для записи
    mov     rdi, [rbp-16]       ; filename
    lea     rsi, [rel str_w]
    call    fopen
    test    rax, rax
    je      .fopen_fail
    mov     [rbp-16], rax       ; FILE* fp

    ; ——— Записать первый член
    mov     rdi, [rbp-16]       ; FILE*
    lea     rsi, [rel fmt_term]
    mov     edx, [rbp-40]       ; n
    movss   xmm0, [rbp-28]      ; term (float)
    cvtss2sd xmm0, xmm0         ; → double для fprintf
    mov     al, 1               ; 1 xmm-рег задействован
    call    fprintf

.loop:
    ; Вычислить next term: term *= (−4·x2)/((2n+2)(2n+1))
    mov     eax, [rbp-40]       ; n
    mov     ecx, eax
    add     ecx, ecx
    add     ecx, 2              ; ecx = 2n+2
    mov     edx, eax
    add     edx, edx
    add     edx, 1              ; edx = 2n+1
    imul    edx, ecx            ; edx = (2n+2)(2n+1)
    cvtsi2ss xmm1, edx          ; denom as float
    movss   xmm2, [neg4]
    movss   xmm3, [rbp-24]      ; x2
    mulss   xmm2, xmm3          ; −4·x2
    divss   xmm2, xmm1          ; ratio
    movss   xmm3, [rbp-28]
    mulss   xmm3, xmm2
    movss   [rbp-28], xmm3      ; termₙ₊₁

    ; n++
    add     dword [rbp-40], 1

    ; sum += term
    movss   xmm4, [rbp-32]
    movss   xmm5, [rbp-28]
    addss   xmm4, xmm5
    movss   [rbp-32], xmm4

    ; fprintf следующего члена
    mov     rdi, [rbp-16]
    lea     rsi, [rel fmt_term]
    mov     edx, [rbp-40]
    movss   xmm0, [rbp-28]
    cvtss2sd xmm0, xmm0
    mov     al, 1
    call    fprintf

    ; пока |term| >= eps — повторять
    movss   xmm6, [rbp-28]
    movss   xmm7, xmm6
    andps   xmm7, [abs_mask]
    ucomiss xmm7, [rbp-8]
    jnb     .loop

    ; ——— Закрыть файл
    mov     rdi, [rbp-16]
    call    fclose

    ; ——— Вычислить cosf(2*x)
    movss   xmm0, [rbp-4]
    mulss   xmm0, [twod]
    call    cosf
    movss   [rbp-48], xmm0      ; сохраняем cos2x

    ; ——— Вывести на экран оба результата
    lea     rdi, [rel fmt_out]
    movss   xmm0, [rbp-32]      ; sum
    cvtss2sd xmm0, xmm0
    movss   xmm1, [rbp-48]      ; cos2x
    cvtss2sd xmm1, xmm1
    mov     al, 2               ; 2 xmm-рега
    call    printf

    ; ——— Эпилог и выход
    mov     edi, 0
    call    exit

; ——— Обработчики ошибок и usage

.usage:
    lea     rdi, [rel usage_msg]
    mov     rax, [rbp-56]
    mov     rsi, [rax]          ; argv[0]
    xor     eax, eax
    call    printf
    mov     edi, 1
    call    exit

.scan_fail:
    lea     rdi, [rel err_scan]
    xor     eax, eax
    call    printf
    mov     edi, 1
    call    exit

.fopen_fail:
    lea     rdi, [rel err_open]
    mov     rsi, [rbp-16]
    xor     eax, eax
    call    printf
    mov     edi, 1
    call    exit
