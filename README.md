Ever wonder what a single line of code actually turns into?  For this
exercise we will write a "simple" program to compute monthly mortage
payments.  This program runs on the KIM-1 microcomputer, is written in
pure assembly language, and requires no external dependencies.  It's as
"bare metal" as it gets!

# The Problem
Given the inputs:

    p = Principal (loan amount)
    mr = Monthly interest rate
    t = Term (months)

the payment is calculated using the formula:

    pmt := p * mr * (1 + mr)^t / ((1 + mr)^t - 1)

As you can see, this formula will require all four basic operations
(add, subtract, multiply, divide), along with a power function.  Ranges
vary - `mr` will be a fraction < 1, while the principal could be up to one
million dollars.  Since we compute payments to the nearest cent, we need
at least 8 significant digits.  While fixed point is certainly a
possiblity, using floating point math will be more straightforward and
likely less code.

# Number format

The 6502 does not include floating point support.  It only supports
integers as bytes and only implements add and subtract for those.  It
does, however offer a decimal mode that allows 8-bit integers to be
treated as binary coded decimal (BCD).  In this mode, a single byte can
represent any number between 0 and 99, or put another way - two decimal
digits.

There are provisions for chaining add and subtract operations together
to perform integer math on multi-byte integers.  We will leverage this
capability.  Taking into consideration the requirements above, we will
represent the mantissa as 4 bytes, or 8 decimal digits.  Furthermore, we
will store mantissas in a normalized format where the leftmost digit is
always non-zero (unless the entire number is zero).  This allows
mantissae in a range of 1.0000000 to 9.9999999.

Exponents will be stored in a single 8-bit byte.  Unlike the mantissa,
the exponent will be stored as a binary number.  This allows for
convienent use of the 6502 INC and DEC instructions which will be used
extensively to bump exponents around.  Since signed arithmetic is
"interesting" on the 6502, we will use an excess-128 format where 0 is
represented by 128 (hex $80).  Here are some sample exponents and their
corresponding binary representation:

    $80 = 10^0
    $7F = 10^-1
    $81 = 10^+1
    $00 = 10^-128
    $FF = 10^+127

One requirement we do NOT have is for signed arithmetic.  Therefore, all
floating point numbers will be assumed to be positive.

# Implementation of the floating point system

The floating point operations will be implemented as subroutines that
are decoupled from the underlying financial application.  Data is
exchanged through two known memory locations which we will refer to as
"registers", though they are not actual processor registers.  These
registers are numbered 1 and 2 and live in zero page memory.  The labels
`m1` and `m2` designate the mantissae of the two registers.  The
corresponding e1 and e2 labels designate their exponents.

`m1` and `m2` have an extra mantissa byte that is only used during
calculations to maintain desired precision.  This extra byte is not
preserved from calculation to calculation and is rounded off and not
displayed.

Data is loaded into the registers using the `load` or `loadc` macros.  `load`
is used to copy data from another zero page location.  `loadc` copies a
constant value from program code.  There is also a corresponding `save` macro
which copies a register value to another zero page location.  

Examples:

    loadc   one, m1     ; Loads the constant `one` into register 1
    load    mrate, m2   ; Loads the value pointed to by `mrate` into `m2`
    save    m1, result  ; Saves the value of `m1` into `result`
    save    m1, m2      ; Copies data from register 1 to 2

I/O routines are also provided.  The `read` routine reads a number from
the keyboard and stores it in m1.  The number may contain a decimal
point and a fractional portion.  The `print` routine writes the value of
m1 out to the screen.  Since this is a financial application, `print`
always writes out to two decimal places (i.e. dollars and cents).

Last are the mathematical operations - `fadd`, `fsub`, `fmul`, `fdiv`, and
`pow`.  The first four are obvious.  The `pow` function impements a rudimentary
power function capable of raising m1 to any integer power between 1 and
99.  The power is specified in the 6502 A register rather than `m2` due to
programmer laziness.

# Helper routines

Writing a floating point package is a large task.  To eliminate repeated code,
quite a few helper functions have been written.  First of all, there are a
series of shift functions - `m1shl`, `m1shr`, and `m2shr`.  These shift the
mantissae of `m1` and `m2` left or right one place respectively.  `m2shl` was
not needed and is unimplimented.  These routines also adjust the corresponding
exponent.  This allows the magnitude of the underlying number to be preserved
even as the mantissa digits are shifted around.

Next come the `pack` and `unpack` routines.  The `unpack` routine copies the
digits of mantissa `m1` into the digit buffer (`dbuf`).  `dbuf` is 8 bytes long and
each place represents a single decimal digit.  Therefore, each entry in dbuf is
between 0 and 9.  `pack` does the reverse, it reassembles a BCD mantissa `m1`
from the 8 digits specified in `dbuf`.  These routines are used in multiple
places and greatly simplify digit-by-digit operations.

Next comes some single-number helpers.  `norm` is used to normalize
mantissa `m1`.  If the mantissa is all zeros, it converts it to the form `0
x 10^-127`.  Otherwise it repeatedly calls `m1shl` until the leftmost digit
is non zero.  Normalization helps preserve accuracy and makes multiply
and divide more predictable with regards to over/underflow.

`fix` is used to convert `m1` to a whole number.  It repeatedly shifts the
number right until only the whole number portion exists and is "right
aligned" in `m1`.  At this point `m1` can be treated as a multibyte BCD
integer without regards to the exponent or normalization.

# Input/Output

The I/O routines are pretty straightforward.  `read` reads a number from
the keyboard.  Digits are read into `dbuf` and the `pack` routine is
used to copy the result to `m1`.  The `e1` value is determined by keeping
track of when the decimal point was encountered.  Any other non-numeric
digits are "eaten" and the routine exits when a carriage return is
encountered.

`print` multiplies `m1` by 100 (using `inc e1`) and then calls `fix` to
convert it to an integer (number of pennies).  Then `unpack` is called.
`dbuf` is iterated and each place printed to the console.  Leading zeros
are ignored up to position 5.  At position 6, a decimal point is
emitted, and the final two digits sent.

# Addition and subtraction
Floating point addition and subtraction are performed by:

1. Adjusting the two numbers to have the same exponent 
2. Adding or subtracting the mantissae, and 
3. Normalizing the result.

To this end, the `fadd` and `fsub` routines are quite straightforward.  Both
routines use a helper method called algn which does the alignment.
There are also `madd` and `msub` helper routines that add and subtract
the mantissae.  Obivously, `fadd` uses `madd` and `fsub` uses `msub`.  Lastly,
the round helper is called to round off the extra digit `(m1+4)` and
norm is called to re-normalize the result.

It is possible for additions to overflow and exceed the mantissa digits
available.  This is precisely the reason `m1` and `m2` have an extra byte.
Prior to calling `madd`, `fadd` shifts `m1` and `m2` right by one decimal place
each.  This gives `madd` an extra digit of "headroom" which it can overflow
into if necessary.  The `norm` at the end will shift the result back to the
correct position.

# Multiplication

Floating point multiplication is performed by first summing the two
exponents and then multiplying the two mantissae.  Exponent summing is
trivially accomplished using the `adc` instruction.  However, the mantissa
product is more involved.

The basic algorithm is quite similar to the "grade school" way we all do
this by hand.  In the "grade school" algorithm, a N-digit X N-digit
multiplication is broken into a series of N operations, each of which
consists of multiplying an N digit number by a 1 digit one.  These
partial products are then shifted left by the number of digits
corresponding to their place and summed to form the final product.

Our algorithm is similar, except:
1. The multiplier digits are iterated rather than the multiplicand's
1. The Nx1 digit multiplications are computed by repeated addition of
the multiplier based on the value of the corresponding digit place in
the multiplicand.
1. Rather than shifting each partial product left, we shift the resulting
running total right once per iteration.

The process is best explained with the following pseudocode.  Note,
the order of some instructions differs from the real code, this is done
for clarity:

    dbuf := unpack(m1)
    e1 := e1 + e2 - 8
    m1 := 0
    m2 := m2 >> 1
    for i := 8 to 1
        m1 := m1 >> 1
        for j := 1 to dbuf[i]
            m1 := m1 + m2
    m1 := norm(round(m1))

The multiplicand is passed by the caller in `m1`.  It is unpacked into
`dbuf` and immediately cleared and reused as the running total for the
product.  The exponent sum has 8 subtracted from it because each `m1`
shift inside the loop will further increment `e1`.  

The `m1+m2` operation is performed by calling `madd`.  We shift `m2` right once
to allow for madd to overflow.  Rhe value of `m2` is otherwise preserved.  We
will take advantage of this property when we implement the power function.

# Division

Division is basically the reverse of multiplication.  The exponents are
subtracted from each other.  `m1` is used to maintain a running remainder.
On each trip through the outer loop, `m2` is subtracted from `m1` until the
result is < 0.  `m2` is then added back to restore a positive value.  The
number of subtractions (minus one) is stored in dbuf and becomes a digit
of the quotient.  The remainder is shifted left and the process repeats
until 8 digits have been generated.

As with multiplication, `m1` and `m2` are shifted right by an extra digit.
This stops leading nonzero digits of `m1` from being rolled off in the very common
case that `m2` is larger than `m1`.  As long as `m1`'s leftmost digit is
nonzero, it is guaranteed that `m1` > `m2` on the next iteration and `m1` will
be reduced.

Division pseudocode:

    e1 := e1 - e2 + 7
    m1 := m1 >> 1
    m2 := m2 >> 1
    for i := 1 to 8
        dbuf[i] := -1
        while (m1 >= 0)
            m1 := m1 - m2
            dbuf[i] := dbuf[i] + 1
        m1 := m1 + m2
        m1 := m1 << 1
    m1 := norm(pack(dbuf))

# Power function

The power function is simply a loop that performs repeated
multiplication.  As a slight optimization, `m2` is shifted right at the
beginning and the multiplication routine is called via the `fmul0` entry
point which skips the shift on each iteration.

Since the exponent is passed via the 6502 `A` register this function can
only raise to the 99th power.  To work around this limitation (and make
the process a whole lot faster), the `main` routine calls `pow` twice,
first to raise to the 12th power and a second time to raise that result
to the power of the number of years of the loan.

So, for a 30 year term we only do `12+30 = 42` repeated multiplications
instead of `360`.  For 99 years, it would be `12+99 = 111` multiplications
versus `1,118`.

# Putting it altogether

With the floating point library in place, it's pretty straightforward to
evaluate the formula.  First, the user is prompted for the following
inputs:

* Principal ($)
* Annual rate (%)
* Term (years)

The annual rate is converted to a percentage by dividing by 100
(actually two `dec e1` instructions).  It is then divided by 12 using
`fdiv` and stored in the `mrate` variable.

Since the `(1 + mr)^term` value is repeated twice in the formula, we
compute it once and save it in the `fv` variable.  Additionally, we
apply the double power optimization described above.  So, the simplified
formula becomes:

    fv := (1 + mrate) ^ 12 ^ term
    pmt := p * mr* fv / (fv - 1)

This is a straightfoward conversion done right-to-left.  See `main` for
details.

# Building it

This code is written for a KIM-1.  I tested it on a KIM-1 replica from Corsham
technologies.  It likely runs on a real KIM as well.

It uses Frank Kingswood's as65 assembler which unfortunately appers to be
unavailable as of late.  It should easily port to another assembler, the only
thing as65-specific are the macros.  Last known location of this assembler was
[http://www.kingswood-consulting.co.uk].

An extremely simple build script `b.cmd` is included.  It's a Windows script
but should work fine with the Linux version of as65.

# Show me the money

Enough already, let's see it run:
```
J 0200

Principal ($)>380000
Annual Rate (%)>3.75
Term (years)>30

Monthly payment: $1759.84

Principal ($)>380000
Annual Rate (%)>3.75
Term (years)>15

Monthly payment: $2763.44

Principal ($)>380000
Annual Rate (%)>4.25
Term (years)>30

Monthly payment: $1869.37

Principal ($)>1000000
Annual Rate (%)>5
Term (years)>30

Monthly payment: $5368.22

Principal ($)>1000
Annual Rate (%)>14
Term (years)>1

Monthly payment: $89.79

Principal ($)>
```
