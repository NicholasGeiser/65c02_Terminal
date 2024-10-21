UART_DATA = $8020
UART_STAT = $8021
UART_CMD  = $8022
UART_CTRL = $8023

;65c22 mapping registers
OIRB = $8000 ;Output data register B
OIRA = $8001
DDRB = $8002
DDRA = $8003

CMD_LOC = $0

.org $8040 ; ROM has an offset of 8040

init:
    lda #0
    sta UART_STAT ; Reset status register

    lda #%00011111 ;  Set Baud rate to 19200
    sta UART_CTRL

    lda #%00001011 ; Interupts active low, no parity, no echo
    sta UART_CMD

    jmp new_line

main:
    ;receive
    ldx #0
read_char:
    lda UART_STAT
    and #$08 ;check rx buffer flag
    beq read_char ;if empty, try again
    lda UART_DATA
    sta CMD_LOC,x ;Store to the CMD_LOC
    cmp #127 ;Backspace
    beq BS_Handle
    cmp #13 ;carriage return
    bne send_char
;Run only if '\r' entered
    sta UART_DATA
    jsr sleep
    lda #$a ;newline
    sta UART_DATA
    jsr sleep
    jmp handle_cmd

send_char:
    ;send
    cpx #10 ;Limit cmd size to 10
    beq read_char
    inx
    sta UART_DATA
    jsr sleep
    jmp read_char

BS_Handle: ;decrement x and send backspace
  cpx #0 ;Make sure we don't subtract beyond zero or send a backspace when already at 0
  beq read_char
  dex
  lda #127 ;Backspace
  sta UART_DATA
  jsr sleep
  jmp read_char

;print the new line sequence
new_line:
    pha
    ldx #0
new_line_loop:
    lda new_cmd_line,x ;Load a with x in string
    cmp #0 ;If null (end of string)
    beq new_line_end ;If done with string exit 
    sta UART_DATA
    jsr sleep ;Send char over UART_CMD
    inx
    jmp new_line_loop
new_line_end:
    pla
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


handle_cmd:
  ldx #0
run_cmd:
  lda CMD_LOC,x
  cmp #114 ;r
  bne inv_cmd
  inx
  lda CMD_LOC,x
  cmp #117 ;u
  bne inv_cmd
  inx
  lda CMD_LOC,x
  cmp #110 ;n
  bne inv_cmd
  jmp exec_run_cmd
  ;Run cmd was entered


;example program
;mimics Input pins to output pins
exec_run_cmd:
  ;Set data direction registers on 65c22
  lda #%11111111 ; Set all of port B to output
  sta DDRB
  lda #%00000000 ; Set port A to inputs
  sta DDRA
  ;Ensure the outputs begin as off
  sta OIRB
run_main:
  lda OIRA ; read the inputs into the accumulator
  ;Turn the IO on
  sta OIRB ;present them on the output
  ;Sleep
  jsr sleep

  ;Repeat
  jmp run_main
  ;Note: will never return to terminal

  
;print no cmd error
inv_cmd:
    pha
    ldx #0
inv_cmd_loop:
    lda invalid_cmd,x ;Load a with x in string
    cmp #0 ;If null (end of string)
    beq inv_cmd_end ;If done with string exit 
    sta UART_DATA
    jsr sleep ;Send char over UART_CMD
    inx
    jmp inv_cmd_loop
inv_cmd_end:
    lda #$a ;newline
    sta UART_DATA
    jsr sleep
    lda #13 ;carriage return
    sta UART_DATA
    jsr sleep
    pla
    jmp new_line


dead_loop:
  jmp dead_loop


new_cmd_line: .asciiz "User: "
invalid_cmd:  .asciiz "Invalid CMD"

  .org $fffc ;65c02 fetches at 0xFFFC, store the address of init there to have the CPU set PC to the start of program
  .word init