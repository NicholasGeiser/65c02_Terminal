UART_DATA = $8020
UART_STAT = $8021
UART_CMD  = $8022
UART_CTRL = $8023

CMD_LOC = $9000
MAX_CMD_SIZE = $A

.org $8040 ; ROM has an offset of 8040

init:
    lda #0
    sta UART_STAT ; Reset status register

    lda #%00011111 ;  Set Baud rate to 19200
    sta UART_CTRL

    lda #%00001011 ; Interupts active low, no parity, no echo
    sta UART_CMD



main:
    jsr get_cmd

sleep:
  pha ; preserve the accumulator
  lda #0 ; reset the lda
sleep_loop:
  adc #1
  cmp #100 ; Compare the accumulator with 100
  bne sleep_loop
  pla ; pop the accumulator back off
  rts ; return from subroutine

;Loops until a char is sent, returns in A reg
read_char:
    pha
read_char_loop:
    lda UART_STAT
    and #$08 ;check rx buffer flag
    beq read_char_loop ;if empty, try again
    lda UART_DATA
    pla
    rts

;send char in A reg
send_char:
    sta UART_DATA
    jsr sleep
    jmp main

;print the new line sequence
new_line:
    pha
    ldx #0
new_line_loop:
    lda new_cmd_line,x ;Load a with x in string
    cmp #0 ;If null (end of string)
    beq new_line_end ;If done with string exit 
    jsr send_char ;Send char over UART_CMD
    inx
    jmp new_line_loop
new_line_end:
    pla
    rts
    
;Gets a whole command
get_cmd:
  pha
  ldx #0
get_cmd_loop:
  jsr read_char ;Get a char
  cmp #13 ;13 = carriage return
  beq get_cmd_end
  sta CMD_loc,x ;store to the next location
  cpx MAX_CMD_SIZE ; Prevent an infinitely long cmd
  beq get_cmd_end
  inx
  beq get_cmd_loop

get_cmd_end:
  inx
  lda #0
  sta CMD_LOC,x ;store to the cmd location
  pla
  rts


new_cmd_line: .asciiz "User: "

dead_loop:
  jmp dead_loop


  .org $fffc ;65c02 fetches at 0xFFFC, store the address of init there to have the CPU set PC to the start of program
  .word init