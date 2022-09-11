
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
    mov x0, 1
    adr x1, filename
    mov x2, filename_len
    mov x8, #64
    svc #0 // output

    mov x0, 0 // stdin
    adr x1, buffer
    mov x2, buffer_cap
    mov x8, #63 // read
    svc #0
    cbz x0, exit

    adr x1, buffer
1: // find end of first line
    cmp x0, 0
    beq 2f

    ldrb w7, [x1], 1
    cmp w7, '\n'
    beq 2f

    sub x0, x0, 1
    b 1b
2:
    sub x1, x1, 1
    strb wzr, [x1], 1
    sub x0, x0, 1

    mov x20, x0
    mov x21, x1

    mov x0, -100
    adr x1, buffer
    mov x2, 1 | 0x40 | 0x200
    mov x3, 0b110110110
    mov x8, #56
    svc #0

    mov x28, x0

    cmp x0, xzr
    bge 1f
    // error
    adr x1, file_error
    mov x2, file_error_len
    mov x0, #1
    mov x8, #64
    svc #0
    b exit
1:
    
    adr x0, buffer
2: // move remaining input to the start of the buffer
    cmp x20, 0
    beq 1f

    ldrb w7, [x21], 1
    strb w7, [x0], 1

    sub x20, x20, 1
    b 2b
1:
    adr x1, buffer
    sub x0, x0, x1

    mov x21, 1 // 0 if previous character was space

input_loop:
    cmp x0, 0
    bne 1f // skip only the first time
    mov x0, 0 // stdin
    adr x1, buffer
    mov x2, buffer_cap
    mov x8, #63 // read
    svc #0
1:

    cbz x0, eof
    // x0 = remaining length
    adr x1, buffer // read pointer
    adr x2, buffer // write pointer

process_input:
    ldrb w7, [x1], 1
    cmp w7, ' '
    beq space
    cmp w7, '\t'
    beq space
    cmp w7, '\n'
    beq newline
    cmp w7, '\r'
    beq newline

    mov w6, 32
    eor w7, w7, w6
    mov x21, 1
    b output

space:
    cbz x21, skip_char // if previous character was space
newline:
    mov x21, 0

output:
    strb w7, [x2], 1
    mov w8, w7

skip_char:
    sub x0, x0, 1
    cmp x0, xzr
    bgt process_input // if not all input was processed

    adr x1, buffer
    sub x2, x2, x1 // output length
    mov x0, x28
    mov x8, #64
    svc #0 // output

    mov x0, 0
    b input_loop
eof:

    mov x0, x28 // close file
    mov x8, #57
    svc #0
exit:
    mov x0, #0 // exit
    mov x8, #93
    svc #0

    .size   _start, (. - _start)
