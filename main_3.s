
    .arch armv8-a

    .data
    .align 2

    .set CAESAR, 1

filename:
    .ascii "Enter filename: "
    .set filename_len, .-filename

file_error:
    .ascii "Error opening file\n"
    .set file_error_len, .-file_error

    .data
    .set buffer_cap, 1024*4

    .bss
buffer:
    .skip buffer_cap

    .text
    .align 2

    .global _start
    .type _start, %function
_start:
    mov x0, 1 // stdout
    adr x1, filename
    mov x2, filename_len
    mov x8, #64
    svc #0 // вывести "Enter filename: " в stdout

    mov x0, 0 // stdin
    adr x1, buffer
    mov x2, buffer_cap
    mov x8, #63 // read
    svc #0  // ввести в buffer из stdin
    cbz x0, exit

    adr x1, buffer
1: // поиск конца первой строки
    cmp x0, 0 // длина входной строки
    beq 2f

    ldrb w7, [x1], 1 // w7 = *x1; x1 += 1
    cmp w7, '\n'
    beq 2f // если w7 это конец строки то выйти

    sub x0, x0, 1
    b 1b
2:
    sub x1, x1, 1
    strb wzr, [x1], 1 // поставить 0 вместо \n
    sub x0, x0, 1

    mov x20, x0
    mov x21, x1

    mov x0, -100
    adr x1, buffer
    mov x2, 1 | 0x40 | 0x200
    mov x3, 0b110110110
    mov x8, #56
    svc #0 // создать или открыть файл с именем как в buffer

    mov x28, x0 // сохраняем дескриптор в x28

    cmp x0, xzr
    bge 1f
    // проверка ошибки открытия
    adr x1, file_error
    mov x2, file_error_len
    mov x0, #1
    mov x8, #64
    svc #0
    b exit
1:
    
    adr x0, buffer
2: // перемещение всего что было после первой строки в начало буффера
    cmp x20, 0
    beq 1f

    ldrb w7, [x21], 1
    strb w7, [x0], 1

    sub x20, x20, 1
    b 2b
1:
    adr x1, buffer
    sub x0, x0, x1

    mov x21, 0 // 0 если предыдущий символ - пробел, иначе 1

input_loop:
    cmp x0, 0
    bne 1f // в первый раз пропускаем ввод если до этого ввели больше одной строки
    mov x0, 0 // stdin
    adr x1, buffer
    mov x2, buffer_cap
    mov x8, #63 // read
    svc #0 // ввод в buffer из stdin
1:

    cbz x0, eof // если введено 0 символов значит конец ввода
    // x0 = оставшаяся длина введенных данных
    adr x1, buffer // указатель чтения
    adr x2, buffer // указатель записи
    // читаем и пишем в один и тот же массив,
    // но записывается всегда меньше символов чем было введено

process_input:
    ldrb w7, [x1], 1 // читаем по указателю чтения и увеличиваем
    // проверяем пробельные символы
    cmp w7, ' '
    beq space
    cmp w7, '\t'
    beq space
    cmp w7, '\n'
    beq newline
    cmp w7, '\r'
    beq newline
    // проверки не сработали - значит буква

    mov w6, 32
    eor w7, w7, w6 // w7 = w7 xor 32 -- смена регистра буквы
    mov x21, 1 // предыдущий символ = буква
    b output

space:
    cbz x21, skip_char // пропускаем если предыдущий символ - пробел
newline:
    mov x21, 0 // предыдущий символ = пробел

output:
    strb w7, [x2], 1 // записываем по указателю записи и увеличиваем
    mov w8, w7

skip_char:
    sub x0, x0, 1
    cmp x0, xzr
    bgt process_input // если остались входные данные, то обрабатываем их

    adr x1, buffer
    sub x2, x2, x1 // указатель записи - buffer = длина выводимых данных
    mov x0, x28
    mov x8, #64
    svc #0 // вывод в файл

    mov x0, 0
    b input_loop // продолжаем вводить данные пока они не закончатся
eof:

    mov x0, x28
    mov x8, #57
    svc #0 // закрываем файл
exit:
    mov x0, #0 // выход
    mov x8, #93
    svc #0

    .size   _start, (. - _start)
