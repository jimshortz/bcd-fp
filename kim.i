;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; KIM-1 ROM Entry points
; Source: KIM-1 Clone Manual (rev 5)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

inh     =   $f9     ; Last 2 digits
pointl  =   $fa     ; Middle 2 digits
pointh  =   $fb     ; First 2 digits

start   = 	$1c4f
ttykb   = 	$1c77 ;
step    = 	$1cd3 ;
rtrn    = 	$1dc2 ;
scan    = 	$1ddb ;
prtpnt  = 	$1e1e ;
crlf    = 	$1e2f ; Print a CR/LF on the TTY.
prtbyt  = 	$1e3b ; Print value in A as two hex digits to TTY.
getch   = 	$1e5a ; Get one character from TTY, return in A.
outsp   = 	$1e9e ; Print one space to TTY.
outch   = 	$1ea0 ; Print character in A to TTY.
scand   = 	$1f19 ;
incpt   = 	$1f63 ; Increment POINTL and POINTH
getkey  = 	$1f6a ; Read key from keypad
chk     = 	$1f91 ; Add A to the checksum.
getbyt  = 	$1f9d ; Get two hex digits.
pack    = 	$1fac ;
scands  = 	$1f1f ; Update display
