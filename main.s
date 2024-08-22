;65c51 Mapping registers
UART_DATA = $8020
UART_STAT = $8021
UART_CMD  = $8022
UART_CTRL = $8023

;65c22 mapping registers
OIRB = $8000 ;Output data register B
OIRA = $8001
DDRB = $8002
DDRA = $8003

CMD_LOC = $1000
WRITE_CMD_LOC = $1010

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
    jsr handle_cmd
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

;Loops until a char is sent, returns in A reg
read_char:
    pha
read_char_loop:
    lda UART_STAT
    and #$08 ;check rx buffer flag
    beq read_char_loop ;if empty, try again
    lda UART_DATA
    jsr send_char ;Echo back char
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
  lda #0 ;end of string
  sta CMD_LOC,x ;store to the cmd location
  lda #$a ;Send newline char
  jsr send_char
  pla
  rts

handle_cmd:
  ldx #0
run_cmd:
  lda CMD_LOC,x
  cmp 'r'
  bne write_cmd
  inx
  lda CMD_LOC,x
  cmp 'u'
  bne write_cmd
  inx
  lda CMD_LOC,x
  cmp 'n'
  bne write_cmd
  jsr exec_run_cmd
  ;Run cmd was entered

write_cmd:
  ldx #0
  lda CMD_LOC,x
  cmp 'w'
  bne read_cmd
  inx
  lda CMD_LOC,x
  cmp 'r'
  bne read_cmd
  inx
  lda CMD_LOC,x
  cmp 'i'
  bne read_cmd
  inx
  lda CMD_LOC,x
  cmp 't'
  bne read_cmd
  inx
  lda CMD_LOC,x
  cmp 'e'
  bne read_cmd
  ;write cmd was entered
  jsr exec_write_cmd

read_cmd:
  ldx #0
  lda CMD_LOC,x
  cmp 'r'
  bne exit_cmd
  inx
  lda CMD_LOC,x
  cmp 'e'
  bne exit_cmd
  inx
  lda CMD_LOC,x
  cmp 'a'
  bne exit_cmd
  inx
  lda CMD_LOC,x
  cmp 'd'
  bne exit_cmd
  ;read cmd was entered
  jsr exec_read_cmd
exit_cmd:
  rts

;example program
;mimics Input pins to output pins
exec_run_cmd:
  lda "x"
  jsr send_char
  jsr init_6522 ;setup pin modes
  ;Set data direction registers on 65c22
  lda #%11111111 ; Set all of port B to output
  sta DDRB
  lda #%00000000 ; Set port A to inputs
  sta DDRA
  ;Ensure the outputs begin as off
  sta OIRB
  lda #0
  rts
run_main:
  lda OIRA ; read the inputs into the accumulator
  ;Turn the IO on
  sta OIRB ;present them on the output
  ;Sleep
  jsr sleep

  ;Repeat
  jmp run_main

exec_write_cmd:
  ldy #0
  inx 
  inx ;skip the space
  lda CMD_LOC,x
  cmp #0 ;check if something was written here
  beq exit_write_cmd
  sbc #30 ;subtract offset to remove ascii conversion
  iny ;Keep track of how many places were fetched
  pha
  inx
  lda CMD_LOC,x
  cmp #0 
  beq convert_write_cmd
  sbc #30 ;subtract offset to remove ascii conversion
  iny
  pha
  lda CMD_LOC,x
  cmp #0
  beq convert_write_cmd
  sbc #30 ;subtract offset to remove ascii conversion
  ;Convert to a single value
convert_write_cmd:
  sta WRITE_CMD_LOC
  ldx WRITE_CMD_LOC ;store first digit in x reg
  
init_6522:
  pha
;Set data direction registers on 65c22
  lda #%11111111 ; Set all of port B to output
  sta DDRB
  lda #%00000000 ; Set port A to inputs
  sta DDRA
  ;Ensure the outputs begin as off
  sta OIRB
  lda #0
  pla
  rts


exit_write_cmd:
  rts

exec_read_cmd:
  rts

new_cmd_line: .asciiz "User: "

dead_loop:
  jmp dead_loop


  .org $fffc ;65c02 fetches at 0xFFFC, store the address of init there to have the CPU set PC to the start of program
  .word init