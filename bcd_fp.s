
    include "kim.i"

; Floating point format:
; Bytes 0-4 Mantissa (BCD MSB=0)
; Byte 5 -  Exponent (binary, excess $80)
;
; The LSB of the mantissa is not considered significant and is
; rounded off as part of normal operations.
;
; Exponents are stored as binary, not BCD.  However,
; they are stored excess $80, so:
;  $80 = 10^0
;  $7F = 10^-1
;  $81 = 10^+1
;
; Constants are stored without the 5th mantissa digit:
;  Bytes 0-3 mantissa (BCD MSB=0)
;  Byte 4 -  Exponent (binary, excess $80)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
minexp  equ     0       ; Mininal exponent (10^-127)

cr      equ     13      ; Carriage return
lf      equ     10      ; Line feed

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Zero page locations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
m1      equ     $0      ; Mantissa 1
e1      equ     $5      ; Exponent 1
pwr     equ     $6      ; Power to raise to
sawdot  equ     $6      ; 1 if decimal point seen (overlaps pwr)
dbuf    equ     $8      ; Digit buffer (8 digits)
m2      equ     $10     ; Mantissa 2
e2      equ     $15     ; Exponent 2

arate   equ     $18     ; Annual rate
princ   equ     $20     ; Principal
term    equ     $38     ; Term 
mrate   equ     $30     ; Monthly rate
fv      equ     $38     ; Future value

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Load a constant
;  \1 - Address of constant (must be within 256 bytes of cons)
;  \2 - Target address (m1 or m2)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
loadc   macro
        ldx     #\1-cons
        ldy     #\2
        jsr     _loadc
        endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Load a variable value
;  \1 - Source address (zero page)
;  \2 - Target address (m1 or m2)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
load    macro
        ldx     #\1
        ldy     #\2
        jsr     _cpyz
        endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Save a variable value
;  \1 - Source address (m1 or m2)
;  \2 - Target address (zero page)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
store   macro
        ldx     #\1
        ldy     #\2
        jsr     _cpyz
        endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Print a message
;  \1 - Message address (must be within 256 bytes of msg)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
prstr   macro
        ldx     #\1-msg
        jsr     _prstr
        endm

        org     $200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Entry point
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
main   
        prstr   prinmsg             ; Read principal
        jsr     read
        store   m1, princ

        prstr   ratemsg             ; Read interest rate
        jsr     read
        store   m1, arate

        prstr   termmsg             ; Read loan term
        jsr     read
        jsr     fix
        store   m1, term
    
        load    arate, m1           ; mrate := arate / 100 / 12
        dec     e1
        dec     e1
        loadc   twelve, m2
        jsr     fdiv
        store   m1, mrate

        loadc   one, m2             ; fv := mrate + 1
        jsr     fadd

        lda     #$12                ; ^ 12
        jsr     pow

        lda     term+3              ; ^ term
        jsr     pow
        store   m1, fv

        loadc   one, m2             ; result := fv / fv-1
        jsr     fsub
        store   m1, m2
        load    fv, m1           
        jsr     fdiv

        load    mrate, m2           ; * mrate
        jsr     fmul

        load    princ, m2           ; * principal
        jsr     fmul

        prstr   mpay                ; Print result
        jsr     print
        jsr     crlf

        jmp     main

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Function for loading a constant.  Use with loadc macro.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_loadc  lda     cons+0,x
        sta     0,y
        lda     cons+1,x
        sta     1,y
        lda     cons+2,x
        sta     2,y
        lda     cons+3,x
        sta     3,y
        lda     #0
        sta     4,y
        lda     cons+4,x
        sta     5,y
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Zero page copy function.  Use with load/store macros.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_cpyz   lda     0,x
        sta     0,y
        lda     1,x
        sta     1,y
        lda     2,x
        sta     2,y
        lda     3,x
        sta     3,y
        lda     4,x
        sta     4,y
        lda     5,x
        sta     5,y
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Clear mantissa 1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
clrm1   lda     #0
        sta     m1
        sta     m1+1
        sta     m1+2
        sta     m1+3
        sta     m1+4
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Shift m1 left 1 digit, decrement exponent
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
m1shl   ldx     #4
m1shl1  asl     m1+4
        rol     m1+3
        rol     m1+2
        rol     m1+1
        rol     m1+0
        dex
        bne     m1shl1
        dec     e1
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Shift m1 right 1 digit, increment exponent
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
m1shr   ldx     #4
m1shr1  lsr     m1+0
        ror     m1+1
        ror     m1+2
        ror     m1+3
        ror     m1+4
        dex
        bne     m1shr1
        inc     e1
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Shift m2 right 1 digit, increment exponent
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
m2shr   ldx     #4
m2shr1  lsr     m2+0
        ror     m2+1
        ror     m2+2
        ror     m2+3
        ror     m2+4
        dex
        bne     m2shr1
        inc     e2
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        
; Pack digit buffer into m1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        
pack    ldx     #0
        ldy     #0
        sty     m1+4                ; Clear overflow digit
pack1   lda     dbuf,x
        asl     a
        asl     a
        asl     a
        asl     a
        inx
        ora     dbuf,x
        sta     m1,y
        inx
        iny
        cpy     #4
        bne     pack1
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        
; Unpack m1 into digit buffer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        
unpack  ldx     #0
        ldy     #0
unpack1 lda     m1,x
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     dbuf,y
        iny
        lda     m1,x
        and     #$0f
        sta     dbuf,y
        iny
        inx
        cpx     #4
        bne     unpack1
        rts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Normalize m1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
norm    lda     m1          ; Is mantissa zero?
        ora     m1+1
        ora     m1+2
        ora     m1+3
        ora     m1+4
        bne     norm2
        lda     #minexp     ; Use known minimal exponent
        sta     e1
        rts
norm1   jsr     m1shl       ; Shift left while top digit == 0
norm2   lda     m1
        and     #$f0
        beq     norm1
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Convert to a whole number (BCD big endian)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fix     lda     e1          ; Shift right until e = 10^8
        cmp     #$88
        beq     fix1
        jsr     m1shr
        jmp     fix
fix1    jsr     round       ; Round off to nearest whole number
        jsr     m1shl       ; And shift back to e = 10^7
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Shift mantissas until exponents are equal
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
algn    lda     e1
        cmp     e2
        beq     algn2
        bcc     algn1
        jsr     m2shr       ; e1 > e2
        jmp     algn
    
algn1   jsr     m1shr       ; e1 < e2
        jmp     algn

algn2   rts                 ; e1 = e2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Add mantissas m1 := m1 + m2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
madd    sed
        clc
        lda     m1+4
        adc     m2+4
        sta     m1+4
        lda     m1+3
        adc     m2+3
        sta     m1+3
        lda     m1+2
        adc     m2+2
        sta     m1+2
        lda     m1+1
        adc     m2+1
        sta     m1+1
        lda     m1+0
        adc     m2+0
        sta     m1+0
        cld
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Subtract mantissas m1 := m1 - m2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
msub    sed
        sec
        lda     m1+4
        sbc     m2+4
        sta     m1+4
        lda     m1+3
        sbc     m2+3
        sta     m1+3
        lda     m1+2
        sbc     m2+2
        sta     m1+2
        lda     m1+1
        sbc     m2+1
        sta     m1+1
        lda     m1+0
        sbc     m2+0
        sta     m1+0
        cld
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Round off the 10th digit of the mantissa.
; "norm" or "m1shl" should be called after this to move 8 significant
; digits back into m1 thru m1+3
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
round   sed
        lda     #$05
        clc
        adc     m1+4
        and     #$f0
        sta     m1+4
        lda     #0
        adc     m1+3
        sta     m1+3
        lda     #0
        adc     m1+2
        sta     m1+2
        lda     #0
        adc     m1+1
        sta     m1+1
        lda     #0
        adc     m1+0
        sta     m1+0
        cld
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; m1 := m1 + m2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fadd    jsr     algn
        jsr     m1shr
        jsr     m2shr
        jsr     madd
        jmp     norm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; m1 := m1 - m2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fsub    jsr     algn
        jsr     msub
        jmp     norm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; m1 := m1 * m2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fmul    jsr     m2shr       ; Create space for an overflow digit
fmul0   clc                 ; Sum exponents
        lda     e1          ; 
        adc     e2
        sec
        sbc     #$88        ; Compensate for m1 shifts and excess $80
        sta     e1
        jsr     unpack      ; Copy multiplicand to dbuf
        jsr     clrm1       ; Clear product mantissa
        ldy     #7          ; Start at rightmost digit of multiplicand
fmul1   jsr     m1shr       ; Shift product right one digit
        ldx     dbuf,y      ; Load next digit of multiplicand
        beq     fmul3       ; If 0, sail on
fmul2   jsr     madd        ; Add in m2 that number of times
        dex
        bne     fmul2
fmul3   dey                 ; Move to next digit
        bpl     fmul1
        jsr     round
        jmp     norm        ; Normalize and exit

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; m1 := m1 / m2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fdiv    sec                 ; Compute new exponent (e1-e2)
        lda     e1
        sbc     e2
        clc
        adc     #$87        ; Deal with excess $80 and add 7 to compensate
        sta     e1          ; For m1 shifts in each pass
        jsr     m1shr       ; Shift dividend and divisor right one place
        jsr     m2shr       ; so that digits are not lost if m1 < m2
        ldy     #0          ; Start building leftmost digit of quotient
fdiv1   ldx     #-1         ; Perform repeated subraction until negative
fdiv2   inx
        jsr     msub
        bcs     fdiv2
        jsr     madd        ; Restore it
        stx     dbuf,y      ; Save count as digit
        jsr     m1shl       ; Shift remainder left one digit
        iny                 ; Move to next digit
        cpy     #8
        bne     fdiv1
        jsr     pack        ; Copy quotient to m1
        jmp     norm        ; Normalize and exit

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        
; m1 := m1 ^ A
;
; Uses repeated multiplication - really lame.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        
pow     sta     pwr
        store   m1, m2
        jsr     m2shr               ; Shift m2 as done in fmul
        loadc   one, m1
pow1    jsr     fmul0               ; Entry point that preserves m2
        sed                         ; Decrement pwr as BCD
        sec
        lda     pwr
        sbc     #1
        sta     pwr
        cld
        bne     pow1
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Read m1 from the console
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
read    jsr     clrm1
        ldy     #0          ; 1 = has seen decimal point
        sty     sawdot
        lda     #$7f
        sta     e1
        jsr     unpack
        ldx     #0
read1   jsr     getch
        cmp     #cr         ; End of line?
        beq     read5
        cmp     #'.'        ; Decimal point?
        bne     read2
        sta     sawdot      ; Remember we've seen it
        beq     read1       ; Get next char
read2   sec
        sbc     #'0'
        cmp     #9
        bcs     read4       ; Non-numeric character - bail
        sta     dbuf,x      ; Store it
        ldy     sawdot
        bne     read3
        inc     e1
read3   inx                 ; Move to next position
        cpx     #8
        bne     read1
read4   jsr     getch       ; Eat garbage to EOL
        cmp     #cr
        bne     read4
read5   jsr     pack
        jmp     norm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Print m1 to console as dollars and cents (dddddd.cc)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
print   inc     e1          ; Convert to pennies
        inc     e1
        jsr     fix
        jsr     unpack      ; Unpack digits
        ldx     #0          ; Start at leftmost position
print2  lda     dbuf,x      ; Skip up to 5 leading 0s
        bne     print3
        inx
        cpx     #5
        bne     print2
print3  cpx     #6          ; Print a . if we are at position 6
        bne     print4
        lda     #'.'
        jsr     outch
print4  lda     dbuf,x      ; Print digit
        ora     #'0'
        jsr     outch
        inx
        cpx     #8
        bne     print3
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Print a string to the console.  Use with prstr macro
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_prstr  lda     msg,x
        beq     _prstr9
        jsr     outch
        inx
        jmp     _prstr
_prstr9 rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
cons                                ; Base address for all constants
one     db  $10,$00,$00,$00,$80
twelve  db  $12,$00,$00,$00,$81

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Messages
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
msg
ratemsg db  cr, lf, "Annual Rate (%)>",0
prinmsg db  cr, lf, "Principal ($)>",0
termmsg db  cr, lf, "Term (years)>",0
mpay    db  cr, lf, cr, lf, "Monthly payment: $",0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Globals
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        end
