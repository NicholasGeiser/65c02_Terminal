UART_DATA = $8020
UART_STAT = $8021
UART_CMD  = $8022
UART_CTRL = $8023

.org $8040 ; ROM has an offset of 8024

init:
    lda #0
    sta UART_STAT ; Reset status register

    lda #%00011111 ;  Set Baud rate to 19200
    sta UART_CTRL

    lda #%00001011 ; Interupts active low, no parity, no echo
    sta UART_CMD



main:
    ;receive
read_char:
    lda UART_STAT
    and #$08 ;check rx buffer flag
    beq read_char ;if empty, try again
    lda UART_DATA

    ;send
    ;lda #66 ; load B
    sta UART_DATA
    jsr sleep
    jmp main



sleep:
  pha ; preserve the accumulator
  lda #0 ; reset the lda
sleep_loop:
  adc #1
  cmp #100 ; Compare the accumulator with 100
  bne sleep_loop
  pla ; pop the accumulator back off
  rts ; return from subroutine


dead_loop:
  jmp dead_loop


  .org $fffc ;65c02 fetches at 0xFFFC, store the address of init there to have the CPU set PC to the start of program
  .word init