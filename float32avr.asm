;
; Float32AVR - a subroutine library for working with numbers in single-precision binary floating-point format.
; In addition to arithmetic, it includes auxiliary subroutines for conversion from and to ASCII.
;
; Copyright (c) 2024 Igor Voytenko <igor.240340@gmail.com>
;
; Partial compliance with IEEE 754:
; - Special values (inf, nan) are not implemented.
; - Denormalized numbers are not implemented.
; - Only one rounding mode is implemented: to nearest/even.
; - Only positive zero is implemented.
;
; Nevertheless, the exponent boundary values of -127 and 128 (0 and 255 for biased exponent)
; remain reserved for special values and denormalized numbers
; to allow for full compatibility in the future
; and for ease of testing and comparison with the reference IEEE 754 implementation right now.
;
; Exception handling.
; In case of an exceptional situation (division by zero, overflow),
; a jump is made to an address that must be preloaded into the Z-register before calling a subroutine.
            ;
            ; Bytes of the dividend's original mantissa,
            ; extended with a GUARD byte for safe left shifting.
            .DEF MANTA0=R8
            .DEF MANTA1=R9
            .DEF MANTA2=R10
            .DEF MANTAG=R2

            ;
            ; Bytes of the divisor's original mantissa,
            ; extended with a GUARD byte for forming the two's complement of a negative mantissa.
            .DEF MANTB0=R12
            .DEF MANTB1=R13
            .DEF MANTB2=R14
            .DEF MANTBG=R3

            ;
            ; Bytes of the two's complement of the divisor's negative mantissa.
            .DEF MANTB0NEG=R4
            .DEF MANTB1NEG=R5
            .DEF MANTB2NEG=R6
            .DEF MANTBGNEG=R7

            ;
            ; Extended exponents.
            .DEF EXPA0=R11                  ; First operand.
            .DEF EXPA1=R20                  ;
            .DEF EXPR0=R11                  ; Result.
            .DEF EXPR1=R20                  ;
            .DEF EXPB0=R15                  ; Second operand.
            .DEF EXPB1=R21                  ;

            ;
            ; Bytes of the quotient's mantissa.
            .DEF Q0=R22
            .DEF Q1=R23
            .DEF Q2=R24
            .DEF Q3=R25

            .EQU QDIGITS=24+2               ; Number of digits of the quotient to calculate: 24 + R + G + S (S is determined outside the loop).

            .DEF STEPS=R17                  ; Loop counter.

            .EQU RGSMASK=0b00000111         ; Mask for extracting RGS bits during rounding.
            .DEF RGSBITS=R18                ; Additional bits of the quotient's mantissa + STICKY bit for correct rounding.

            .DEF RSIGN=R0                   ; Sign of the result (quotient/product/algebraic sum).

            ;
            ; Mantissa of the product.
            .DEF MANTP0=R17
            .DEF MANTP1=R18
            .DEF MANTP2=R19
            .DEF MANTP3=R23
            .DEF MANTP4=R24
            .DEF MANTP5=R25
            .DEF GUARD=R7                  ; GUARD register for temporarily storing the R bit of the product's mantissa.

            .DEF STATUS0=R5                ; STATUS register after operation on the least significant byte.
            .DEF STATUS1=R6                ; STATUS register after operation on the most significant byte.
            .DEF SREGACC=R17               ; Status register after multiple operations. For example, bitwise AND of the STATUS register.

;
; Divides two numbers using a non-restoring division algorithm with a fixed divisor.
;
; The dividend is expected in registers: R11, R10, R9, R8.
; The divisor is expected in registers: R15, R14, R13, R12. 
; The quotient is placed in the dividend's location: R11, R10, R9, R8.
FDIV32:     ;
            ; Operand filtering.
            CLR R16                     ;
            OR R16,R12                  ;
            OR R16,R13                  ;
            OR R16,R14                  ;
            OR R16,R15                  ;
            IN R16,SREG                 ; 
            SBRC R16,SREG_Z             ; Is the divisor zero?
            IJMP                        ; Yes, throw an error. The dividend can be either zero or non-zero - both cases are invalid.

            CLR R16                     ; No, check the dividend.
            OR R16,R8                   ;
            OR R16,R9                   ;
            OR R16,R10                  ;
            OR R16,R11                  ;
            IN R16,SREG                 ;
            SBRC R16,SREG_Z             ; Is the dividend zero?
            RJMP SETZERO                ; Yes, return zero.
                                        ; No, both operands are non-zero; calculate the quotient.
            
            ;
            ; Determining the sign of the quotient.
            MOV RSIGN,R11               ; Copy the most significant byte of the dividend.
            MOV R1,R15                  ; Copy the most significant byte of the divisor.
            LDI R16,0b10000000          ; Load the sign mask.
            AND RSIGN,R16               ; Extract the sign of the dividend.
            AND R1,R16                  ; Extract the sign of the divisor.
            EOR RSIGN,R1                ; Determine the sign of the quotient.

            ;
            ; Unpacking the dividend.
            ROL R10                     ; The MSB of the dividend's mantissa contains the LSB of the exponent. Shift it to the carry bit.
            ROL R11                     ; Remove the sign of the dividend and restore the least significant bit of the exponent.
            ROR R10                     ; Return the most significant byte of the dividend's mantissa to its place.
            OR R10,R16                  ; Restore the hidden bit of the mantissa.

            ;
            ; Unpacking the divisor.
            ROL R14                     ; The same applies to the divisor.
            ROL R15                     ; 
            ROR R14                     ; 
            OR R14,R16                  ;

            ;
            ; Calculating the exponent of the quotient.
            CLR EXPA1
            CLR EXPB1
            
            COM EXPB0                   ; Generate the two's complement of the divisor's exponent.
            COM EXPB1                   ;
            LDI R16,1                   ; 
            ADD EXPB0,R16               ; 
            LDI R16,0                   ;
            ADC EXPB1,R16               ;

            ADD EXPA0,EXPB0             ; EXPA=EXPA-EXPB.
            ADC EXPA1,EXPB1             ;
            LDI R16,127                 ; Make the exponent of the quotient biased.
            ADD EXPA0,R16               ; 
            LDI R16,0                   ;
            ADC EXPA1,R16               ;
            
            ;
            ; Generating the two's complement of the divisor's mantissa.
            CLR MANTAG                  ;
            CLR MANTBG                  ;

            MOV MANTB0NEG,MANTB0        ; Copy the positive mantissa of the divisor.
            MOV MANTB1NEG,MANTB1        ;
            MOV MANTB2NEG,MANTB2        ;
            MOV MANTBGNEG,MANTBG        ;

            COM MANTB0NEG               ; Since 2^N-|B|=(2^N-1-|B|)+1=COM(|B|)+1,
            COM MANTB1NEG               ; invert the bits of the positive mantissa
            COM MANTB2NEG               ;
            COM MANTBGNEG               ;

            LDI R16,1                   ; and add one,
            ADD MANTB0NEG,R16           ; not forgetting the potential carry bit.
            LDI R16,0                   ;
            ADC MANTB1NEG,R16           ; 
            ADC MANTB2NEG,R16           ; 
            ADC MANTBGNEG,R16           ;

            ;
            ; Calculating the mantissa of the quotient.
            LDI STEPS,QDIGITS           ; The number of steps equals the number of computed digits of the quotient.
            CLR Q0                      ; Zero the mantissa of the quotient.
            CLR Q1                      ;
            CLR Q2                      ;
            CLR Q3                      ;

SUBMANTB:   ADD MANTA0,MANTB0NEG        ; Subtract from the mantissa of the dividend or remainder
            ADC MANTA1,MANTB1NEG        ; the mantissa of the divisor,
            ADC MANTA2,MANTB2NEG        ; multiplied by the weight
            ADC MANTAG,MANTBGNEG        ; of the corresponding digit of the quotient.

CALCDIGIT:  IN R16,SREG                 ;
            SBRS R16,SREG_N             ; Is the remainder negative?
            SBR Q0,1                    ; No, set the current digit of the quotient to 1.

            DEC STEPS                   ; Are all digits of the quotient calculated?
            BREQ RESTPOSREM             ; Yes, restore the last positive remainder.

            CLC                         ; Clear and zero the LSB for the next digit of the quotient.
            ROL Q0                      ;
            ROL Q1                      ; 
            ROL Q2                      ;
            ROL Q3                      ;

            CLC                         ; Shift the remainder left along with the virtual
            ROL MANTA0                  ; digit grid attached to it.
            ROL MANTA1                  ; The fixed mantissa of the divisor in this grid
            ROL MANTA2                  ; will become equivalent to being multiplied by the weight of the next
            ROL MANTAG                  ; lower digit of the quotient, which we are going to determine.

            IN R16,SREG                 ;
            SBRS R16,SREG_N             ; Is the remainder positive?
            RJMP SUBMANTB               ; Yes, subtract the mantissa of the divisor.
            ADD MANTA0,MANTB0           ; No, add the mantissa of the divisor.
            ADC MANTA1,MANTB1           ;
            ADC MANTA2,MANTB2           ;
            ADC MANTAG,MANTBG           ;
            RJMP CALCDIGIT              ; Determine the next digit of the quotient.

RESTPOSREM: IN R16,SREG                 ;
            SBRS R16,SREG_N             ; Is the last remainder already positive?
            RJMP CALCSTICKY             ; Yes, proceed to calculate the STICKY bit.
            ADD MANTA0,MANTB0           ; No, restore to the last positive remainder.
            ADC MANTA1,MANTB1           ;
            ADC MANTA2,MANTB2           ;
            ADC MANTAG,MANTBG           ;

            ;
            ; Calculation of the STICKY bit for correct rounding to the nearest.
            ;
            ; If the remainder is non-zero, it means there are non-zero bits to the right of the quotient.
            ; S=1, R>0
            ; S=0, R=0
CALCSTICKY: COM MANTA0                  ; Calculation of the remainder's two's complement.
            COM MANTA1                  ; Invert the remainder: 2^N-1-A < 2^N (for all values of A).
            COM MANTA2                  ; Add one: 2^N-1-A+1=2^N-A < 2^N (only for non-zero A).
            COM MANTAG                  ; Consequently, only with a zero remainder
            LDI R16,1                   ; will there be a carry from the most significant byte.
            ADD MANTA0,R16              ; This means that S=NOT(C), where C is the carry bit.
            LDI R16,0                   ;
            ADC MANTA1,R16              ;
            ADC MANTA2,R16              ;
            ADC MANTAG,R16              ;

            IN R16,SREG                 ; Convert the carry bit to the S-bit.
            LDI R17,1                   ; 
            EOR R16,R17                 ;
            OUT SREG,R16                ;

            ROL Q0                      ; Add the value of the S-bit to the right of the quotient's mantissa.
            ROL Q1                      ; 
            ROL Q2                      ;
            ROL Q3                      ;

            ;
            ; Normalization of the quotient's mantissa.
            ;
            ; The quotient's mantissa lies within the range (0.5, 2),
            ; therefore, denormalization is only possible by 1 bit to the right.
            SBRC Q3,2                   ; Is there an integer one in the quotient?
            RJMP CHECKEXP               ; Yes, the quotient is normalized; we check the exponent.
            CLC                         ; No, normalize to the left by 1 bit.
            ROL Q0                      ;
            ROL Q1                      ;
            ROL Q2                      ;
            ROL Q3                      ;
                                        
            LDI R16,0xFF                ; Decrease the quotient's exponent by 1.
            LDI R17,0XFF                ;
            ADD EXPR0,R16               ;
            ADC EXPR1,R17               ;

            ;
            ; Checking the exponent for overflow/underflow.
            ;
            ; Overflow: EXP > 127+127=254. According to the standard - set to inf. Current implementation - raise an exception.
            ; Underflow: EXP < -126+127=1. According to the standard - transition to a denormalized number. Current implementation - set the quotient to zero.
CHECKEXP:   MOV R18,EXPR0               ; Copy the extended exponent of the quotient.
            MOV R19,EXPR1               ;

            LDI R16,255                 ; Form -1 in two's complement.
            LDI R17,255                 ; 
            ADD R16,R18                 ; If the true exponent is less than the minimum representable value (-126),
            ADC R17,R19                 ; then in the biased code, subtracting one will yield a negative number.
            IN R16,SREG                 ; 
            SBRC R16,SREG_N             ; Is the unbiased exponent less than -126?
            RJMP SETZERO                ; Yes, underflow, return zero.
                                        ; 
            LDI R16,1                   ; No, check the exponent for overflow.
            LDI R17,0                   ; If the unbiased exponent exceeds the maximum representable value (127),
            ADD R16,R18                 ; then, after adding one to the biased exponent, there will be a carry
            ADC R17,R19                 ; to the high-order byte.
            COM R17                     ; If the high-order byte contains zero,
            LDI R16,1                   ; then calculating the two's complement will result in zero.
            ADD R16,R17                 ; Is the unbiased exponent less than 128?
            BREQ ROUND                  ; Yes, there is no overflow, proceed to rounding.
            IJMP                        ; No, overflow detected, jump to the error handler specified in Z.

            ;
            ; Rounding to the nearest.
            ;
            ; NOTE: Rounding occurs only after normalization (if denormalization took place).
            ;
            ; Possible combinations of RS bits. For brevity, the GUARD bit is not considered here; the rounding concept is illustrated.
            ; RS
            ; --
            ; 00: Exact value. |ERR| = 0.
            ; 01: Discard. |ERR| < 2^-24=2^-23/2=ULP/2. The error is less than half the weight of the least significant bit of the single-precision mantissa.
            ; 10: If such a situation occurs, it means the dividend has non-zero bits beyond the original single-precision grid, which is impossible in our case (justification is in the doc).
            ; 11: Discard and add 2^-23. |ERR| < 2^-24=ULP/2.
            ;
            ; Comments on the last case:
            ; Q - true mantissa of the quotient (infinite precision).
            ; Q' - rounded value.
            ; Q' = Q-(2^-24+A)+2^-23, where A represents the bits beyond the grid to the right of R, indicated by the S bit, thus A < 2^-24.
            ; 2^-23 = 2^-24+2^-24 = 2^-24+(A+B), where (A+B) = 2^-24, but A > 0, hence B < 2^-24.
            ; Then we can write Q' = Q-2^-24-A+2^-24+A+B = Q+B, where B < 2^-24.
            ; Therefore, in the last case |ERR| < 2^-24=ULP/2.
ROUND:      MOV RGSBITS,Q0              ; Extract RGS bits from the least significant byte of the quotient's mantissa.
            LDI R16,RGSMASK             ;
            AND RGSBITS,R16             ;

            LDI STEPS,3                 ; Отбрасываем RGS-биты в мантиссе частного.
RSHIFT3:    CLC                         ; We calculated 26 digits of the quotient + S bit,
            ROR Q3                      ; so after the shift, all digits of the quotient's mantissa
            ROR Q2                      ; will fit into the three least significant bytes.
            ROR Q1                      ;
            ROR Q0                      ;
            DEC STEPS                   ;
            BRNE RSHIFT3                ;

            LDI R16,0xFC                ; If the R bit is set in RGS and there are non-zero bits to the right of it,
            ADD RGSBITS,R16             ; then the value in RGS is greater than 4, which means that by discarding RGS,
            IN R16,SREG                 ; we introduce an error greater than ULP/2.
            SBRC R16, SREG_N            ; Discarded more than ULP/2?
            RJMP PACK                   ; No, pack the quotient.

            LDI R16,1                   ; Yes, add 2^-23.
            ADD Q0,R16                  ; There will be no overflow because
            LDI R16,0                   ; a normalized mantissa that causes overflow is greater than the maximum possible normalized mantissa;
            ADC Q1,R16                  ; a denormalized mantissa that would cause overflow after normalization
            ADC Q2,R16                  ; can only be obtained if the dividend has non-zero bits beyond single precision, which is impossible in our case.

            ;
            ; Packing the sign, mantissa, and exponent of the quotient and writing it to the dividend's location.
            ; NOTE: The normalized and rounded mantissa of the quotient now occupies the 3 least significant bytes.
PACK:       ROL Q0                      ; Shift the mantissa left, removing the integer one.
            ROL Q1                      ;
            ROL Q2                      ;

            CLC                         ; Shift the LSB of the exponent to the carry bit to the right,
            ROR EXPR0                   ; while freeing the MSB for the sign.

            ROR Q2                      ; Restore the mantissa
            ROR Q1                      ; with the LSB of the exponent in place of the integer one.
            ROR Q0                      ;

            OR EXPR0,RSIGN              ; Set the sign bit.

            ;
            ; Write the quotient's mantissa to the dividend's location.
            MOV MANTA0,Q0
            MOV MANTA1,Q1
            MOV MANTA2,Q2

            RJMP EXIT

;
; Multiplies two numbers using a fixed multiplier scheme.
; NOTE: We are considering the multiplication of the multiplier by the multiplicand, i.e., B*A.
;
; The multiplicand is expected in registers: R11, R10, R9, R8.
; The multiplier is expected in registers: R15, R14, R13, R12. 
; The product is placed in the multiplicand's location: R11, R10, R9, R8.
FMUL32:     ;
            ; Operand filtering.
            CLR R16                     ;
            OR R16,R8                   ;
            OR R16,R9                   ;
            OR R16,R10                  ;
            OR R16,R11                  ;
            IN R16,SREG                 ;
            SBRC R16,SREG_Z             ; Is the multiplicand zero?
            RJMP SETZERO                ; Yes, return zero.

            CLR R16                     ; No, check the multiplier.
            OR R16,R12                  ;
            OR R16,R13                  ;
            OR R16,R14                  ;
            OR R16,R15                  ;
            IN R16,SREG                 ; 
            SBRC R16,SREG_Z             ; Is the multiplier zero?
            RJMP SETZERO                ; Yes, return zero.

            ;
            ; Determining the sign of the product.
            MOV RSIGN,R11               ; Copy the most significant byte of the multiplicand.
            MOV R1,R15                  ; Copy the most significant byte of the multiplier.
            LDI R16,0b10000000          ; Load the sign mask.
            AND RSIGN,R16               ; Extract the sign of the multiplicand.
            AND R1,R16                  ; Extract the sign of the multiplier.
            EOR RSIGN,R1                ; Determine the sign of the product.

            ;
            ; Unpack the multiplicand.
            ROL R10                     ; The MSB of the mantissa contains the LSB of the exponent. Shift it into the carry bit.
            ROL R11                     ; Remove the sign and restore the least significant bit of the exponent.
            SEC                         ; Restore the hidden bit of the mantissa.
            ROR R10                     ; Return the most significant byte of the mantissa to its place.

            ;
            ; Unpack the multiplier.
            ROL R14                     ; Same as for the multiplicand.
            ROL R15                     ; 
            SEC                         ;
            ROR R14                     ; 

            ;
            ; Calculate the exponent of the product.
            ;
            ; Since the exponents are biased,
            ; their values are always positive numbers in the range [1,254].
            CLR EXPA1
            CLR EXPB1
            
            ADD EXPA0,EXPB0             ; EXPA=EXPA+EXPB.
            ADC EXPA1,EXPB1             ; The sum of the exponents contains an excess value of 127.
            LDI R16,-127                ; It is necessary to subtract this value.
            LDI R17,255                 ; Form the two's complement for -127 in the double binary grid.
            ADD EXPA0,R16               ; Make the sum of the exponents biased.
            ADC EXPA1,R17               ;

            ;
            ; Calculate the mantissa of the product.
            LDI R22,24                  ; The number of loop steps is equal to the number of digits in the multiplicand.

            CLR MANTP0                  ; Zero out the product.
            CLR MANTP1                  ;
            CLR MANTP2                  ;
            CLR MANTP3                  ;
            CLR MANTP4                  ;
            CLR MANTP5                  ;

NEXTDIGIT:  ROR MANTA2                  ; Extract the next digit of the multiplicand.
            ROR MANTA1                  ;
            ROR MANTA0                  ;
                                        
            IN R16,SREG                 ;
            SBRS R16,SREG_C             ; Is the digit equal to 1?
            RJMP LOOPCOND0              ; No, it's 0, do not add the multiplier.
            ADD MANTP3,MANTB0           ; Yes, add the multiplier to the accumulator.
            ADC MANTP4,MANTB1           ; The lower 3 bytes of the multiplier in the double binary grid are zero,
            ADC MANTP5,MANTB2           ; so it's enough to add only the higher bytes.

LOOPCOND0:  DEC R22                     ; Was that the last digit of the multiplicand?
            BREQ CHECKOVF0              ; Yes, the mantissa of the product has been calculated, checking it for overflow.

            ROR MANTP5                  ; No, divide the accumulator by 2.
            ROR MANTP4                  ;
            ROR MANTP3                  ;
            ROR MANTP2                  ;
            ROR MANTP1                  ;
            ROR MANTP0                  ;            

            RJMP NEXTDIGIT              ; Move on to the next digit of the multiplicand.

CHECKOVF0:  IN R16,SREG                 ; 
            SBRS R16,SREG_C             ; Did the mantissa of the product overflow?
            RJMP ROUNDPROD              ; No, proceed to rounding it.
            ROR MANTP5                  ; Yes, normalize the mantissa of the product to the right by 1 bit.
            ROR MANTP4                  ;
            ROR MANTP3                  ;
            ROR MANTP2                  ;
            ROR MANTP1                  ;
            ROR MANTP0                  ;

            LDI R16,1                   ; Adjust the exponent.
            ADD EXPA0,R16               ;
            LDI R16,0                   ;
            ADC EXPA1,R16               ;

            ;
            ; Rounding the product's mantissa.
            ;
            ; After setting the S-bit and extracting the RS pair,
            ; MANTP2 can hold the following values:
            ; - 0b11000000
            ; - 0b10000000
            ; - 0b01000000
            ; - 0b00000000
ROUNDPROD:  CLR GUARD
            CLC
            
            ROL MANTP0                  ; Shift the R-bit into the GUARD register.
            ROL MANTP1                  ; Now the lower part contains only the bits after R.
            ROL MANTP2                  ;
            ROL GUARD                   ;

            COM MANTP0                  ; If all the bits after the R-bit are zero,
            COM MANTP1                  ; then calculating the two's complement of the lower part
            COM MANTP2                  ; will produce a carry bit.
            LDI R16,1                   ; Therefore, the absence of a carry bit
            ADD MANTP0,R16              ; is used as an indicator
            LDI R16,0                   ; that there is at least one non-zero bit after the R-bit.
            ADC MANTP1,R16              ; UPD: Of course, we could detect all zeroes
            ADC MANTP2,R16              ; in a much simpler way using OR.

            IN R16,SREG                 ;
            SBRS R16,SREG_C             ; Are there non-zero bits after the R-bit?
            SBR MANTP2,0b10000000       ; Yes, set the S-bit.

            ROR GUARD                   ; No, the entire lower part is zero (including the S-bit, so there is no need to explicitly clear the S-bit).
            ROR MANTP2                  ; Restoring the R-bit.
            ROR MANTP1                  ;
            ROR MANTP0                  ;

            LDI R16,0b11000000          ; Extracting the RS bits.
            AND MANTP2,R16              ;

            CLR GUARD                   ; Interpret the register with RS bits as a number and form its two's complement.
            COM MANTP2                  ; The two's complement is formed in double range, as the single range is insufficient
            COM GUARD                   ; to represent the values 0b11000000 and 0b10000000 as negative in two's complement.
            LDI R16,1                   ; UPD: In fact the single range is insufficent only to distinguish negative values
            ADD MANTP2,R16              ; from positive ones. But when performing subtraction we can use carry bit as an
            LDI R16,0                   ; indication of the sign of the result, so we don't actually need to form two's
            ADC GUARD,R16               ; complement in the double range.

            CLR STATUS0                 ; The difference between the reference value 0b10000000 and the numerical interpretation of RS
            CLR STATUS1                 ; is directly related to the rounding direction (see the documentation).
            LDI R16,0b10000000          ; We take the zero result and the sign of the obtained difference as the indicator for the rounding direction.
            ADD MANTP2,R16              ; 
            IN STATUS0,SREG             ; Save flags after the operation with the least significant byte.
            LDI R16,0                   ; 
            ADC GUARD,R16               ;
            IN STATUS1,SREG             ; Save flags after the operation with the most significant byte.

            SBRS STATUS1,SREG_N         ; RS=0b11000000? [NOTE: A negative difference is only possible in the situation 0b10000000-0b11000000.]
            RJMP HALFWAY                ; No, checking the next case.
            LDI R16,1                   ; Yes, the lower part is greater than ULP/2. Rounding up.
            ADD MANTP3,R16              ; Discarding the lower part and adding ULP.
            LDI R16,0                   ; This is equivalent to adding a value smaller than ULP/2 to the lower part,
            ADC MANTP4,R16              ; leading to zeroing out the lower part and generating a carry bit in MANTP3.
            ADC MANTP5,R16              ;
            RJMP CHECKOVF1              ;

HALFWAY:    AND STATUS1,STATUS0         ; The difference is zero if the Z-flag was set for each byte.
            SBRS STATUS1,SREG_Z         ; RS=0b10000000?
            RJMP CHECKEXP1              ; No, RS=0b01000000 or RS=0b00000000. The lower part is less than ULP/2, so we simply discard it. Overflow during rounding is impossible - skip the check.
            LDI R16,0b00000001          ; Yes, halfway situation. The lower part equals ULP/2, round to the nearest even value.
            AND R16,MANTP3              ; Extract ULP into R16.
            ADD MANTP3,R16              ; If ULP=1, then the higher part is odd
            LDI R16,0                   ; and adding R16 (which also contains 1) will result in rounding to the nearest even number.
            ADC MANTP4,R16              ; If ULP=0, then the value is already even,
            ADC MANTP5,R16              ; and adding R16 (which also contains 0) will have no effect, keeping the value even.

            ;
            ; Checking the product's mantissa for overflow after rounding.
CHECKOVF1:  IN R16,SREG                 ; 
            SBRS R16,SREG_C             ; Did rounding cause an overflow?
            RJMP CHECKEXP1              ; No, let's proceed to the exponent check.
            ROR MANTP5                  ; Normalize the mantissa of the product to the right by 1 bit.
            ROR MANTP4                  ;
            ROR MANTP3                  ;

            LDI R16,1                   ; Correct the exponent.
            ADD EXPA0,R16               ;
            LDI R16,0                   ;
            ADC EXPA1,R16               ;

            ;
            ; Check the final product for exponent overflow/underflow.
            ;
            ; If the exponent is less than -126 (-126+127=1 in biased representation), then the product is too small to be represented as a single float and we flush to zero.
            ; If the exponent is greater than 127 (127+127=254 in biased representation), then the product is too large, and we throw an exception.
CHECKEXP1:  MOV R18,EXPR0               ; Copy the extended exponent of the product.
            MOV R19,EXPR1               ;

            LDI R16,255                 ; Form -1 in two's complement.
            LDI R17,255                 ; 
            ADD R16,R18                 ; If the unbiased exponent is less than the minimum representable value (-126),
            ADC R17,R19                 ; then in the biased representation, subtracting one will yield a negative number.
            IN R16,SREG                 ; 
            SBRC R16,SREG_N             ; Is the unbiased exponent less than -126?
            RJMP SETZERO                ; Yes, underflow; return zero.
                                        ; 
            LDI R16,1                   ; No, check the exponent for overflow.
            LDI R17,0                   ; If the true exponent is greater than the maximum representable value (127),
            ADD R16,R18                 ; then after adding one to the biased exponent, its higher byte will be non-zero.
            ADC R17,R19                 ; Is the unbiased exponent less than 128?
            BREQ PACKPROD               ; Yes, no overflow; proceed to packing.
            IJMP                        ; No, overflow; jump to the error handler pointed to by Z.
            
            ;
            ; Pack the mantissa and exponent of the product.
PACKPROD:   ROL MANTP3                  ; Shift the mantissa left, removing the integer one.
            ROL MANTP4                  ; NOTE: It's enough to shift only the highest byte of the mantissa.
            ROL MANTP5                  ;

            CLC                         ; Shift the LSB of the exponent to the carry bit,
            ROR EXPR0                   ; while simultaneously freeing the MSB for the sign.

            ROR MANTP5                  ; Restore the mantissa to its position
            ROR MANTP4                  ; replacing the integer one with the LSB of the exponent.
            ROR MANTP3                  ;

            OR EXPR0,RSIGN              ; Set the sign bit.

            MOV MANTA0,MANTP3           ; Write the mantissa of the product to the position of the multiplicand's mantissa.
            MOV MANTA1,MANTP4
            MOV MANTA2,MANTP5

            RJMP EXIT

            ; Exit from FMUL32.
EXIT:       RET

            ;
            ; Set the result to zero.
            ;
            ; Happens in the following cases:
            ; - Underflow.
            ; - Dividend is zero.
            ; - At least one multiplicand is zero.
            ; - Both addends are zero.
SETZERO:    CLR MANTA0
            CLR MANTA1
            CLR MANTA2
            CLR EXPA0
            RJMP EXIT

;
; Computes the difference between two numbers.
;
; The minuend is expected in registers: R11, R10, R9, R8.
; The subtrahend is expected in registers: R15, R14, R13, R12. 
; The difference is stored in the place of the minuend: R11, R10, R9, R8.
FSUB32:     LDI R16,0b10000000          ; B=-B.
            EOR B3,R16                  ;
            RJMP FADD32                 ;

;
; Adds two numbers.
;
; The first addend is expected in registers: R11, R10, R9, R8.
; The second addend is expected in registers: R15, R14, R13, R12. 
; The sum is stored in the place of the first addend: R11, R10, R9, R8.
FADD32:     ;
            ; Swap.
            ; Set the largest (by absolute value) operand as the first.
            MOV R0,R8                   ; Copy A.
            MOV R1,R9                   ;
            MOV R2,R10                  ;
            MOV R3,R11                  ;

            MOV R4,R12                  ; Copy B.
            MOV R5,R13                  ;
            MOV R6,R14                  ;
            MOV R7,R15                  ;

            LDI R16,0b01111111          ;
            AND R3,R16                  ; Compute |A|.
            AND R7,R16                  ; Compute |B|.

            COM R4                      ; Compute the two's complement of |B|.
            COM R5                      ;
            COM R6                      ;
            COM R7                      ;
            LDI R16,1                   ;
            ADD R4,R16                  ;
            LDI R16,0                   ;
            ADC R5,R16                  ;
            ADC R6,R16                  ;
            ADC R7,R16                  ;

            ADD R4,R0                   ; |A|-|B|.
            ADC R5,R1                   ; Overwrite -|B| to preserve the untouched |A|.
            ADC R6,R2                   ;
            ADC R7,R3                   ;
                                        ; |A|-|B|>=0?
            BRGE HANDLEZERO             ; Yes, no swap is needed. Proceed to handling zero operands.
                                        ; No, perform the swap.
            MOV R3,R11                  ; Backup A. Since registers R0..R3 already store |A|, to backup A we just restore the sign for |A|.
            
            MOV R8,R12                  ; Store B in the place of A.
            MOV R9,R13                  ;
            MOV R10,R14                 ;
            MOV R11,R15                 ;

            MOV R12,R0                  ; Restore A to the position of B.
            MOV R13,R1                  ;
            MOV R14,R2                  ;
            MOV R15,R3                  ;

            ;
            ; Handle zero operands.
            ;
            ; Possible scenarios before the swap (where 1 is any non-zero operand value):
            ; 0,0
            ; 0,1
            ; 1,0
            ; 1,1
            ;
            ; After the swap, only the following scenarios remain:
            ; 0,0
            ; 1,0
            ; 1,1
            ;
            ; Therefore, if the first operand is zero after the swap, both operands are zero, and the result is zero.
            ; If the second operand is zero, the first operand is non-zero, and the result is the first operand.
HANDLEZERO: CLR R16                     ;
            OR R16,MANTA0               ;
            OR R16,MANTA1               ;
            OR R16,MANTA2               ;
            OR R16,EXPA0                ; A=0?
            BREQ SETZERO                ; Yes, both A and B are zero; return zero.

            CLR R16                     ; No, check B.
            OR R16,MANTB0               ;
            OR R16,MANTB1               ;
            OR R16,MANTB2               ;
            OR R16,EXPB0                ; B=0?
            BREQ EXIT                   ; Yes, return A (A is already in the result register).
                                        ; No, neither A nor B is zero; continue the calculations.

            ;
            ; Determine the sign of the sum.
            ;
            ; Take the sign of operand A, which, after the swap, satisfies the expression |A|>=|B|.
            ; If |A|>|B| and the signs are different, then the sign of the difference is equal to the sign of the largest (by absolute value) operand, i.e., A.
            ; If the signs are the same, then the sign of the sum is equal to the sign of either operand, including A.
            ; If |A|=|B| and the signs are the same, then the sign of the sum is also equal to the sign of either operand, including A.
            ; If the signs are different, then due to the equality of the absolute values, the difference will be zero and a positive sign will be set, regardless of the signs of A and B.
CALCSIGN:   MOV RSIGN,R11               ; Copy the high byte of A.
            LDI R16,0b10000000          ; Create a mask to extract the sign stored in the MSB.
            AND RSIGN,R16               ; Extract the sign of A.

            ;
            ; Backup the sign of B.
            ; 
            ; It will be needed to determine the operation: addition or subtraction.
            MOV R1,R15                  ; Copy the high byte of B.
            AND R1,R16                  ; Extract the sign of B. The sign mask is already stored in R16.

            ;
            ; Unpack the operands.
            ROL R8                      ; Unpack A.
            ROL R9                      ;
            ROL R10                     ; Shift the LSB of the exponent into the carry bit.
            ROL R11                     ; Restore the exponent in the high byte.
            SEC                         ; Restore the implicit one in the mantissa of A.
            ROR R10                     ;
            ROR R9                      ;
            ROR R8                      ;

            ROL R12                     ; Unpack B
            ROL R13                     ;
            ROL R14                     ;
            ROL R15                     ;
            SEC                         ;
            ROR R14                     ;
            ROR R13                     ;
            ROR R12                     ;

            ;
            ; Extend the exponent of A by one byte to the left.
            CLR EXPA1                   ;

            ;
            ; Extend the mantissas to RGS.
            ;
            ; These registers are appended to the right of the mantissas of A and B.
            CLR R6                      ; RGS of the mantissa of A.
            CLR R7                      ; RGS of the mantissa of B.

            ;
            ; Align the exponents.
            ;
            ; The exponents of both operands are biased and take values in the range [1,254].
            ; After the swap, the exponent of A will be either greater than or equal to the exponent of B. This means that the difference of the exponents lies in the range [0,253].
            ; From this, it follows that there is no need to calculate the correct two's complement in the double grid (see justification in the documentation).
            ;
            ; Rounding to the S-bit may be required when denormalizing the mantissa of B.
            MOV R17,EXPA0               ; Copy the exponent of A.
            MOV R16,EXPB0               ; Copy the exponent of B.
            COM R16                     ; Calculate the lower byte of the two's complement of the exponent of B.
            INC R16                     ;
            ADD R17,R16                 ; EXP(A)-EXP(B)=0? [NOTE: R17 now contains the difference of the exponents in the range [0,253].]
            BREQ CHOOSEOP               ; Yes, the exponents are equal; alignment is not required.
            LDI R16,31                  ; No, determine which range the difference falls into: [1,30] or [31,253]. [NOTE: We've extended RGS on the whole byte.]
            COM R16                     ; Form the two's complement of -31 within a byte. [NOTE: There is no need for a double grid.]
            INC R16                     ;
            ADD R16,R17                 ; (EXP(A)-EXP(B))-31<0? [NOTE: If the true difference in the double grid is negative, there will be no carry bit from the lower byte.]
            BRCC SHIFTMANTB             ; Yes, the difference is in the range [1,30]; shift the mantissa of B and form the S-bit.
            CLR MANTB0                  ; No, the difference is in the range [31,253];
            CLR MANTB1                  ; set the value of the mantissa of B to 2^-31 (rounding to the S-bit).
            CLR MANTB2                  ;
            LDI R16,0b00000001          ;
            MOV R7,R16                  ;
            RJMP CHOOSEOP               ;

            ;
            ; Пошаговый сдвиг мантиссы B на разность экспонент вправо.
            ;
            ; Разность экспонент здесь принимает значения в отрезке [1,30].
            ; Если за пределами RGS-зоны оказался хотя бы один единичный бит, то происходит установка S-бита.
SHIFTMANTB: CLR R16                     ; R16 будет хранить в LSB значение бита переноса после каждого сдвига.
            CLC                         ;
            ROR MANTB2                  ; Сдвигаем мантиссу b вправо на 1 разряд вместе с RGS-битами.
            ROR MANTB1                  ;
            ROR MANTB0                  ;
            ROR R7                      ;
            ROL R16                     ; Извлекаем бит переноса в R16.
            OR R7,R16                   ; Если C!=0, значит за пределами RGS оказался единичный бит, значит устанавливаем S-бит.

            DEC R17                     ; Мантисса B сдвинута на разность порядков?
            BREQ CHOOSEOP               ; Да, переходим к выбору арифметической операции.
            RJMP SHIFTMANTB             ; Нет, сдвигаем дальше.

            ;
            ; Выбор арифметической операции.
CHOOSEOP:   EOR R1,R0                   ; SIGN(A)=SIGN(B)?
            BRNE DIFF                   ; Нет, знаки разные, переходим к вычитанию.
                                        ; Да, вычисляем сумму.

            ;
            ; Вычисление суммы модулей мантисс.
            ;
            ; Здесь возможно только переполнение результата.
            ; Мантисса суммы записывается на место мантиссы A.
SUM:        ADD R6,R7                   ; Складываем мантиссы A и B.
            ADD R8,R12                  ; У мантиссы A RGS-зона всегда нулевая, поэтому бит переноса не возможен.
            ADC R9,R13                  ;
            ADC R10,R14                 ;
                                        ; Переполнение есть?
            BRCC ROUNDSUM               ; Нет, переходим к округлению.
            ROR R10                     ; Да, нормализуем мантиссу вправо.
            ROR R9                      ;
            ROR R8                      ;
            ROR R6                      ;
            CLR R16                     ; Устанавливаем S-бит, если при нормализации был потерян единичный бит.
            ROL R16                     ; 
            OR R6,R16                   ;
            INC EXPA0                   ; Корректируем экспоненту. В худшем случае экспонента равна 254 поэтому бита переноса в старший байт не будет.
            RJMP ROUNDSUM               ;
            
            ;
            ; Вычисление разности модулей мантисс.
            ;
            ; Здесь в худшем случае возможна денормализация результата вправо в отрезке [0,24]
            ; При A=1 И B=((2^24)-1)*2^-23*2^-1.
DIFF:       COM R7                      ; Вычисляем псевдо доп. код мантиссы B. Это дополнение до 2 вместо 4.
            COM MANTB0                  ; Результат всегда положительный, поэтому нет необходимости в истинном доп. коде.
            COM MANTB1                  ; В доп. бите слева всегда будет единица, а из младшей части всегда будет бит переноса,
            COM MANTB2                  ; зануляющий разряд истинного доп. кода.
            LDI R16,1                   ;
            ADD R7,R16                  ;
            CLR R16                     ;
            ADC MANTB0,R16              ;
            ADC MANTB1,R16              ;
            ADC MANTB2,R16              ;

            LDI SREGACC,0b00000010      ; Маска для Z-флага.
            ADD R6,R7                   ; Складываем RGS-регистры.
            IN R16,SREG                 ; Извлекаем из регистра статуса только Z-флаг.
            AND SREGACC,R16             ;
            ADD MANTA0,MANTB0           ; Складываем следующую пару байт мантисс. (У мантиссы A RGS-зона всегда нулевая, поэтому бит переноса из предыдущей операции не возможен.)
            IN R16,SREG                 ;
            AND SREGACC,R16             ;
            ADC MANTA1,MANTB1           ; Складываем следующую пару байт.
            IN R16,SREG                 ;
            AND SREGACC,R16             ;
            ADC MANTA2,MANTB2           ; Складываем последнюю пару байт.
            IN R16,SREG                 ;
            AND SREGACC,R16             ; Результат нулевой? (SREGACC=STATUS0^STATUS1^STATUS2^STATUS3^0b00000010, где STATUS<N>-регистр статуса после сложения очередной пары байт мантисс.)
            BRNE SETZERO1               ; Да, устанавливаем положительный ноль. (Если флаг Z был установлен для каждой пары байт, то SREGACC окажется ненулевым).

            SBRC MANTA2,7               ; Мантисса разности денормализована?
            RJMP ROUNDSUM               ; Нет, мантисса нормализована, переходим к округлению.
                                        ; Да, выполняем нормализацию и коррекцию экспоненты.
            CLR R16                     ; Счетчик степени денормализации.
            LDI R17,255                 ; Шаг счетчика R17=-1. Формируем счетчик сразу в доп. коде.
NORM:       CLC                         ;
            ROL R6                      ; Нормализуем влево.
            ROL MANTA0                  ;
            ROL MANTA1                  ;
            ROL MANTA2                  ;
            ADD R16,R17                 ; DEC R16.
            SBRS MANTA2,7               ; Мантисса разности нормализовалась?
            RJMP NORM                   ; Нет, продолжаем сдвиг.
            ADD EXPA0,R16               ; Да, корректируем экспоненту: EXPA-K, где K - степень денормализации.
            ADC EXPA1,R17               ; R17,R16 - расширили доп. код R16 до двух байт (воспользовались тем, что R17 уже содержит 255).

            ;
            ; Округление.
            ;
            ; После сдвига R-бита происходит проверка C- И Z-битов в регистре статуса.
            ; Если Z=0 после сдвига, то это ситуация симметричного округления, иначе - округление в большую сторону.
ROUNDSUM:   MOV R16,R6                  ; Копируем RGS.
            CLC                         ;
            ROL R16                     ; R-бит равен нулю?
            BRCC CHECKEXP2              ; Да, RGS=000|001|010|011. Отбрасываем RGS, ошибка ERR<ULP/2.
            BREQ HALFWAY1               ; Нет, RGS=ULP/2=100, симметричное округление.
            LDI R16,1                   ; Нет, RGS=101|110|111.
            RJMP ADDULP                 ; Отбрасываем RGS и прибавляем ULP. Ошибка ERR<ULP/2.

HALFWAY1:   LDI R16,1                   ; Извлекаем значение разряда ULP.
            AND R16,R8                  ;
ADDULP:     ADD R8,R16                  ; Прибавляем ULP.
            CLR R16                     ; Если значение нечетное, то ULP=1, и результат станет четным.
            ADC R9,R16                  ; Если значение уже четное, то ULP=0, и прибавление нуля не изменит результат.
            ADC R10,R16                 ; Есть переполнение?
            BRCC CHECKEXP2              ; Нет, переходим к проверке экспоненты.
            ROR MANTA2                  ; Да, нормализуем мантиссу A. Поскольку переполнение при округлении, два младших байта мантиссы уже нулевые.
            INC EXPA0                   ; Корректируем экспоненту. 

            ;
            ; Проверка экспоненты на переполнение/антипереполнение.
            ;
            ; Экспонента в коде со смещением принимает значения в отрезке [-22,255].
            ; Если есть переполнение, то экспонента равна 255 и вычитание её из 255 даст ноль.
            ; Если нет переполнения, то вычитание экспоненты из 255 даст положительное значение.
            ; Если есть антипереполнение, то экспонента принимает значения в отрезке [-22,0] и вычитание единицы из экспоненты всегда даст отрицательное значение.
            ; Если нет антипереполнения, то, поскольку переполнение уже исключено, экспонента лежит в [1,254] и вычитание единицы всегда даст положительное значение.
CHECKEXP2:  LDI R17,255                 ; Записываем 255 в два байта.
            LDI R18,0                   ;

            MOV R21,EXPA0               ; Копируем расширенную экспоненту A.
            MOV R22,EXPA1               ;

            COM R21                     ; Вычисляем доп. код экспоненты в двух байтах.
            COM R22                     ;
            LDI R16,1                   ;
            ADD R21,R16                 ;
            CLR R16                     ;
            ADC R22,R16                 ;

            ADD R17,R21                 ; 255-EXP(A).
            IN STATUS0,SREG             ; Сохраняем флаги после сложения младших байт.
            ADC R18,R22                 ;
            IN STATUS1,SREG             ; Сохраняем флаги после сложения старших байт.

            AND STATUS0,STATUS1         ; Результат нулевой, если флаг Z был установлен для каждого байта.
            SBRC STATUS0,SREG_Z         ; 255-EXP(A)=0?
            IJMP                        ; Да, переполнение, прыжок на обработчик ошибок, указанный в регистре Z.
            LDI R16,255                 ; Нет, проверяем на антипереполнение.
            LDI R17,255                 ;
            ADD R16,EXPA0               ; EXP(A)-1.
            ADC R17,EXPA1               ; Результат отрицательный?
            BRMI SETZERO1               ; Да, антипереполнение, экспонента лежит в [0,-22] и не представима. Возвращаем ноль.
                                        ; Нет, экспонента лежит в [1,254] и представима в одинарном float.

            ;
            ; Упаковка суммы.
            ROL MANTA0                  ; Выдвигаем целочисленную единицу мантиссы суммы в бит переноса.
            ROL MANTA1                  ;
            ROL MANTA2                  ;
            ROL RSIGN                   ; Выдвигаем знак В бит переноса.
            ROR EXPA0                   ; Вдвигаем знак в MSB экспоненты и выдвигаем LSB экспоненты в бит переноса.
            ROR MANTA2                  ; Восстанавливаем исходные биты мантиссы,
            ROR MANTA1                  ; вдвигая в MSB старшего байта мантиссы LSB экспоненты вместо целочисленной единицы.
            ROR MANTA0                  ;

            RJMP EXIT1
            
            ; Выход.
EXIT1:      RET

            ;
            ; Установка результата в ноль.
            ;
            ; Выполняется в следующих случаях:
            ; - Антипереполнение результата для любой операции.
            ; - Делимое равно нулю.
            ; - Хотя бы один сомножитель равен нулю.
            ; - Оба слагаемых равны нулю.
SETZERO1:   CLR MANTA0
            CLR MANTA1
            CLR MANTA2
            CLR EXPA0
            RJMP EXIT1

;
; Преобразует число в формате плавающей точки в целое.
;
; Работает только с положительными нормализованными десятичными числами в отрезке [1,10).
; Таким образом, возвращает целочисленное значение в отрезке [1,9] в пределах байта.
; 
; Аргументы:
;   - NUM - число, ожидается в регистрах: R11, R10, R9, R8.
;
; Результат: целая часть NUM. Помещается в R8.
            .DEF A0=R8                  ;
            .DEF A1=R9                  ;
            .DEF A2=R10                 ;
            .DEF A3=R11                 ;

            .DEF STATUS=R21             ; Регистр статуса.

FTOI:       ROL A2                      ; Распаковываем num.
            ROL A3                      ; A3=EXP(NUM). Поскольку num лежит в [1,10), то все биты целой части в нормализованной мантиссе
            SEC                         ; полностью лежат в старшем байте мантиссы и нет необходимости сдвигать младшие.
            ROR A2                      ;
           
            CLR A0                      ; A0 не содержит битов целой части и нам не интересен. Он будет содержать целую часть десятичного значения NUM.
            LDI R16,-127                ; A3=EXP(NUM)-127. Экспонента лежит в [127,127+3], значит разность всегда > 0, достаточно доп. кода в пределах байта.
            ADD A3,R16                  ; Экспонента нулевая? (Если нулевая, то целая часть мантиссы уже представляет истинную целую часть десятичного значения, которая равна единице.)
            BREQ SHFTMSB                ; Да, делаем финальный сдвиг.
            MOV R16,A3                  ; Нет, устанавливаем счетчик цикла и раскрываем экспоненту, денормализуя мантиссу влево.
DENORM:     ROL A2                      ; A<<1
            ROL A0                      ;
            DEC R16                     ; Мантисса денормализована влево на величину экспоненты?
            BREQ SHFTMSB                ; Да, делаем финальный сдвиг.
            RJMP DENORM                 ; Нет, продолжаем сдвиг.

SHFTMSB:    ROL A2                      ; A0=INT(NUM). (MSB мантиссы содержит LSB истинной целой части - выдвигаем его в A0.)
            ROL A0                      ;

            RET

;
; Преобразует однобайтовое целое число в число в формате плавающей точки.
;
; Аргументы:
;   - NUM - целое число, ожидается в регистре R8.
;
; Результат: число в формате плавающей точки, помещается в R11, R10, R9, R8.
            .DEF A0=R8                  ;
            .DEF A1=R9                  ;
            .DEF A2=R10                 ;
            .DEF A3=R11                 ;

            .DEF STATUS=R21             ; Регистр статуса.

SETZERO3:   CLR A0                      ; A=0.0F.
            CLR A1                      ;
            CLR A2                      ;
            CLR A3                      ;
            RET                         ;

ITOF:       AND A0,A0                   ; NUM=0?
            BREQ SETZERO3               ; Да, возвращаем 0.0F.

            CLR A1                      ; Младшие байты мантиссы.
            CLR A2                      ;
            LDI R16,-1                  ; Байт экспоненты. Инициализируем в -1 для холостого инкремента при первом сдвиге.
            MOV A3,R16                  ;

            CLC                         ; A2 нулевой, поэтому последний сдвиг A2 всегда зануляет бит переноса - очищать на каждой итерации не нужно.
NORM0:      INC A3                      ; Совмещаем LSB целого числа с MSB мантиссы,
            ROR A0                      ; получая, по сути, денормализованную влево мантиссу.
            IN STATUS,SREG              ; Запоминаем флаг Z для A0.
            ROR A2                      ; 
            SBRS STATUS,SREG_Z          ; Мантисса нормализована? (если изначально A0=1, то он занулится, а мантисса сразу окажется нормализованной.)
            RJMP NORM0                  ; Нет, продолжаем нормализацию.
                                        ; Да, пакуем float.
            LDI R16,127                 ; Сохраняем экспоненту в коде со смещением.
            ADD A3,R16                  ;

                                        ; Убираем у мантиссы целочисленную единицу.
            ROL A2                      ; Входное число размером в байт, поэтому все ненулевые биты уже вмещаются в A2, а A0 И A1 РАВНЫ НУЛЮ.

            CLC                         ; Результат будет положительным - разряд знака нулевой.
            ROR A3                      ; Придвигаем экспоненту к мантиссе без единицы.

            ROR A2                      ; Размещаем LSB экспоненты в MSB мантиссы.

            RET

;
; Конвертирует нормализованное десятичное число в формате float в ASCII-строку.
;
; В основе лежит алгоритм, реализованный в z88dk, но с упрощениями для поддержки только нормализованных десятичных чисел.
; [https://github.com/z88dk/z88dk/blob/aa60b9c9e4bab3318b9b10e919919058a4d3aaee/libsrc/math/cimpl/ftoa.c]
;
; Основная идея алгоритма - мы игнорируем тот факт, что десятичное представление
; исходной двоичной дроби искажается при её масштабировании.
; следствие этого допущения - не все десятичные цифры в строке оказываются истинными.
; при округлении десятичного строкового представления разряды просто отбрасываются.
;
; аргументы:
;   - NUM - число, ожидается в регистрах: R11, R10, R9, R8.
;   - PRECISION - количество цифр после точки, ожидается в регистре R12.
;   - STR - указатель на область SRAM, куда будет записана ASCII-строка, ожидается в XH:XL.
            .EQU TEN0=0x00              ; 10.0F.
            .EQU TEN1=0x00              ;
            .EQU TEN2=0x20              ;
            .EQU TEN3=0x41              ;

            .DEF A0=R8                  ; Первый операнд любой арифметической операции: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF A1=R9                  ;
            .DEF A2=R10                 ;
            .DEF A3=R11                 ;

            .DEF B0=R12                 ; Второй операнд любой арифметической операции: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF B1=R13                 ;
            .DEF B2=R14                 ;
            .DEF B3=R15                 ;

            ;
            ; Формирование строки "0" в случае, когда NUM=0.0F.
SETZERO2:   LDI R16,0x30                ;
            ST X+,R16                   ; *STR++='0'.
            RJMP EXITFTOAN              ;

FTOAN:      CLR R16                     ;
            OR R16,A0                   ;
            OR R16,A1                   ;
            OR R16,A2                   ;
            OR R16,A3                   ; NUM=0?
            BREQ SETZERO2               ; Да, формируем фиксированную строку "0.0".

            PUSH R12                    ; Бэкапим PRECISION, т.к. он находится в одном из входных регистров арифметических операций.

            LDI R16,0b10000000          ; Извлекаем знак NUM.
            AND R16,A3                  ; NUM>0?
            BREQ GETINT                 ; Да, NUM уже положительный, продолжаем.
            EOR A3,R16                  ; Нет, вычисляем модуль NUM=|NUM| И
            LDI R16,0x2D                ; Начинаем строку со знака '-'.
            ST X+,R16                   ; *STR++='-'.

            ;
            ; Извлечение цифры целой части.
GETINT:     PUSH A3                     ; Бэкапим исходный NUM.
            PUSH A2                     ;
            PUSH A1                     ;
            PUSH A0                     ;
            CALL FTOI                   ; A0=DIGIT=INT(NUM).
            
            LDI R16,0x30                ; *STR++=ASCII(DIGIT).
            ADD R16,A0                  ;
            ST X+,R16                   ;

            CALL ITOF                   ; A=FDIGIT=FLOAT(DIGIT). Извлеченную цифру имеем теперь не как целое, а как число в float32.

            MOV B0,A0                   ; B=A=FDIGIT.
            MOV B1,A1                   ;
            MOV B2,A2                   ;
            MOV B3,A3                   ;

            POP A0                      ; A=NUM.
            POP A1                      ;
            POP A2                      ;
            POP A3                      ;

            CALL FSUB32                 ; A=NUM=FSUB32(NUM,FDIGIT). Теперь из NUM удален целочисленный десятичный разряд, цифру которого мы извлекли.

            ;
            ; Добавление десятичной точки.
            LDI R16,0x2E                ; *STR++='.'.
            ST X+,R16                   ;

            ;
            ; Извлечение дробных десятичных разрядов.
            ;
            ; Входное значение NUM<1.
            ; Двоичная экспонента после умножения на 10 лежит в [-123,3]
            ; или [4,130] в коде со смещением.
GETFRAC:    LDI R16,TEN0                ; B=10.0F.
            LDI R17,TEN1                ;
            LDI R18,TEN2                ;
            LDI R19,TEN3                ;
            MOV B0,R16                  ;
            MOV B1,R17                  ;
            MOV B2,R18                  ;
            MOV B3,R19                  ;

            CALL FMUL32                 ; A=NUM'=FMUL32(NUM,10.0F). После GETINT - A=NUM, NUM<1.

            PUSH A3                     ; Бэкапим NUM',
            PUSH A2                     ; Поскольку далее будем распаковывать его экспоненту.
            PUSH A1                     ;
            PUSH A0                     ;

            ROL A2                      ; Если экспонента лежит в [127,130],
            ROL A3                      ; то разность положительная и всегда даст бит переноса
            LDI R16,-127                ; в старший байт, где занулятся биты истинного доп. кода -127.
            ADD R16,A3                  ; NUM' лежит в [0,1)? (Если NUM' равен нулю, то экспонента равна нулю (в коде со смещением), что также даст отрицательную разность, поэтому и это условие оказывается уже покрытым.)
            BRCS ASCIIDIG1              ; Нет, в целой части десятичный дробный разряд, определяем его цифру.
            LDI R16,0x30                ; Да, очередной дробный разряд нулевой, устанавливаем цифру ноль.
            ST X+,R16                   ; *STR++='0'.

            POP A0                      ; A=NUM'.
            POP A1                      ; Восстанавливаем состояние, ожидаемое в COND1.
            POP A2                      ; В стеке - PRECISION.
            POP A3                      ;

            RJMP COND1                  ;

ASCIIDIG1:  POP A0                      ; A=NUM', сейчас NUM' - десятичная нормализованная дробь.
            POP A1                      ; Восстанавливаем исходное значение,
            POP A2                      ; Не поврежденное распаковкой экспоненты.
            POP A3                      ;

            PUSH A3                     ; Снова бэкапим NUM',
            PUSH A2                     ; Поскольку далее нам нужно будет
            PUSH A1                     ; удалить из него целую часть.
            PUSH A0                     ;

            CALL FTOI                   ; A0=DIGIT=INT(NUM').

            LDI R16,0x30                ; *STR++=ASCII(DIGIT).
            ADD R16,A0                  ;
            ST X+,R16                   ;

            CALL ITOF                   ; A=FDIGIT=FLOAT(DIGIT).

            MOV B0,A0                   ; B=A=FDIGIT.
            MOV B1,A1                   ;
            MOV B2,A2                   ;
            MOV B3,A3                   ;

            POP A0                      ; A=NUM'.
            POP A1                      ;
            POP A2                      ;
            POP A3                      ;

                                        ; Убираем извлеченный дробный разряд из целой части NUM'.
            CALL FSUB32                 ; A=NUM=FSUB32(NUM',FDIGIT). Теперь снова NUM<1.

COND1:      POP R16                     ; R16=PRECISION.
            DEC R16                     ; PRECISION--. Извлекли заданное число дробных разрядов?
            BREQ EXITFTOAN              ; Да, STR содержит десятичные цифры числа NUM, стек - адрес возврата.
            PUSH R16                    ; Нет, снова бэкапим PRECISION и
            RJMP GETFRAC                ; Извлекаем следующий десятичный дробный разряд.

EXITFTOAN:  LDI R16,0                   ;
            ST X,R16                    ; Добавляем конец строки '\0'.
            RET

;
; Формирует ASCII-строку с десятичным представлением переменной типа float в экспоненциальной форме.
;
; Если число уже нормализовано десятично, то просто выполняется конвертация в строку через FTOAN
; с учётом ограничения на максимальную длину строки MAXLEN.
;
; Иначе выполняется десятичная нормализация числа, затем происходит конвертация нормализованного числа
; в строку через FTOAN, но с ограниченным количеством знаков после точки, таким, чтобы длина результирующей
; строки (вместе со знаком минуса, десятичной точкой и экспонентой) не превысила MAXLEN.
;
; Аргументы:
;   - NUM - число, ожидается в регистрах: R11, R10, R9, R8.
;   - MAXLEN - максимальная длина выходной строки, ожидается в регистре R12. Сейчас ожидается значение 16 - кол-во символов в LCD1602.
;   - STR - указатель на область SRAM, куда будет записана ASCII-строка. ожидается в XH:XL.
            .DEF EXP=R0                 ; Показатель степени в экспоненциальной записи.

            .DEF A0=R8                  ; Первый операнд любой арифметической операции: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF A1=R9                  ; Также - входной операнд NUM.
            .DEF A2=R10                 ;
            .DEF A3=R11                 ;

            .DEF MAXLEN=R12             ; Максимальная длина выходной строки с десятичным представлением NUM.

            .DEF B0=R12                 ; Второй операнд любой арифметической операции: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF B1=R13                 ;
            .DEF B2=R14                 ;
            .DEF B3=R15                 ;

            .DEF TMP0=R22               ; Может быть использован для временного хранения float32.
            .DEF TMP1=R23               ;
            .DEF TMP2=R24               ;
            .DEF TMP3=R25               ;
            
FTOAE:      PUSH MAXLEN                 ; Бэкапим MAXLEN.

            CLR EXP                     ; EXP=0.

            PUSH A3                     ; Бэкапим старшие два байта NUM.
            PUSH A2                     ;
            ROL A2                      ; Распаковываем экспоненту NUM.
            ROL A3                      ;
            LDI R16,-127                ;
            ADD R16,A3                  ;
            POP A2                      ; Восстанавливаем старшие два байта NUM вместо тех, которые "пострадали" при распаковке экспоненты.
            POP A3                      ; Экспонента в коде со смещением лежит в [1,126]? 
            BRMI NORMLFT                ; Да, значит истинная экспонента лежит в [-126,-1], а это значит, что NUM<1 и INT(NUM)=0 - нормализуем влево.

NORMRGHT:   PUSH A3                     ; Нет, NUM>=1, значит NUM либо уже нормализован, либо денормализован влево (тогда нормализуем вправо).
            PUSH A2                     ; Бэкапим текущее значение NUM.
            PUSH A1                     ; Возможно, что оно уже нормализовано.
            PUSH A0                     ;

            LDI R16,TEN0                ; B=10.0F.
            LDI R17,TEN1                ;
            LDI R18,TEN2                ;
            LDI R19,TEN3                ;
            MOV B0,R16                  ;
            MOV B1,R17                  ;
            MOV B2,R18                  ;
            MOV B3,R19                  ;

            PUSH EXP                    ;
            CALL FDIV32                 ; A=NUM=FDIV32(NUM,10.0F).
            POP EXP                     ;

            PUSH A3                     ; Бэкапим старшие два байта NUM.
            PUSH A2                     ;
            ROL A2                      ; Распаковываем экспоненту NUM.
            ROL A3                      ;
            LDI R16,-127                ;
            ADD R16,A3                  ;
            POP A2                      ; Восстанавливаем старший байт NUM, искаженный извлечением экспоненты.
            POP A3                      ; Экспонента в коде со смещением лежит в [1,126]?
            BRMI RESTNORM               ; Да, значит истинная экспонента лежит в [-126,-1], а это значит, что NUM<1 и предыдущее значение до деления на 10 уже было нормализованным.
            
            INC EXP                     ; Нет, NUM>=1, значит предыдущее значение не было нормализованным. Запоминаем очередное понижение порядка NUM.

            POP R16                     ; Удаляем предыдущее значение NUM.
            POP R16                     ;
            POP R16                     ;
            POP R16                     ;
            RJMP NORMRGHT               ;

RESTNORM:   POP A0                      ; Восстанавливаем последнее значение NUM, которое уже нормализовано.
            POP A1                      ;
            POP A2                      ;
            POP A3                      ;
            RJMP CONVMANT               ;

NORMLFT:    CLR R16                     ;
            OR R16,A0                   ;
            OR R16,A1                   ;
            OR R16,A2                   ;
            OR R16,A3                   ; NUM=0.0F?
            BREQ CONVMANT               ; Да, NUM=0.0F - FTOAN обработает ноль корректно и вернет строку с символом нуля. EXP тоже остаётся равен нулю. 

            LDI R16,TEN0                ; B=10.0F.
            LDI R17,TEN1                ;
            LDI R18,TEN2                ;
            LDI R19,TEN3                ;
            MOV B0,R16                  ;
            MOV B1,R17                  ;
            MOV B2,R18                  ;
            MOV B3,R19                  ;

            PUSH EXP                    ;
            CALL FMUL32                 ; A=NUM=FMUL32(NUM,10.0F).
            POP EXP                     ;
            INC EXP                     ; EXP++.

            PUSH A3                     ;
            PUSH A2                     ;
            ROL A2                      ;
            ROL A3                      ;
            LDI R16,-127                ;
            ADD R16,A3                  ;
            POP A2                      ; Восстанавливаем NUM.
            POP A3                      ; NUM>=1?
            BRMI NORMLFT                ; Нет, продолжаем нормализацию.

            LDI R16,0b10000000          ; EXP=-EXP. Представляем отрицательную экспоненту в прямом коде.
            OR EXP,R16                  ;

            ;
            ; Конвертация десятичной мантиссы в строку.
            ;
            ; NOTE: Мы нормализовали NUM (если он не был нормализован изначально) и это значение представляет теперь
            ; мантиссу в десятичной экспоненциальной записи.
CONVMANT:   POP MAXLEN                  ; Извлекаем аргумент MAXLEN.

            AND EXP,EXP                 ; EXP=0?
            BREQ CHKSGN                 ; Да, число NUM уже нормализовано, экспоненциальная форма не требуется.

            LDI R16,-4                  ; Нет, резервируем в строке 4 места под экспоненту: E{+|-}00.
            ADD MAXLEN,R16              ; MAXLEN=MAXLEN-4.

CHKSGN:     LDI R16,0b10000000          ; Маска знака.
            AND R16,A3                  ; NUM<0?
            BRNE NUMNEG                 ; Да, резервируем в выходной строке один символ под '-'.
            
            LDI R16,-2                  ; Нет, резервируем только два места под цифру целой части и точку.
            ADD MAXLEN,R16              ; MAXLEN=MAXLEN-2.
            RJMP CALLFTOAN              ;

NUMNEG:     LDI R16,-2-1                ; Два места под цифру целой части и точку и еще одно место - под символ минуса '-'.
            ADD MAXLEN,R16              ; MAXLEN=(MAXLEN-2)-1.

CALLFTOAN:  PUSH EXP                    ;
            CALL FTOAN                  ; STR=FTOAN(NUM,MAXLEN). MAXLEN после вычислений фактически содержит PRECISION,
            POP EXP                     ; Который гарантирует, что не будет превышения исходного значения MAXLEN.

            AND EXP,EXP                 ; EXP=0?
            BREQ EXITFTOAE              ; Да, выходим.

            LDI R16,'E'                 ; Нет, формируем экспоненциальную запись.
            ST X+,R16                   ; STR+='E'.

            ROL EXP                     ; EXP<0? (Отрицательная экспонента представлена в прямом коде).
            BRCC SETPLUS                ; Нет, EXP>0, устанавливаем знак '+'.
            LDI R16,'-'                 ; Да, устанавливаем знак '-'.
            ST X+,R16                   ;
            RJMP EXPTOSTR               ;
SETPLUS:    LDI R16,'+'                 ;
            ST X+,R16                   ;

            ;
            ; Конвертация экспоненты в строку.
            ;
            ; Если экспонента не равна нулю, то модуль экспоненты лежит в [1,38].
            ; Это значит, что неполное частное от деления на 10 не превышает 3 (0b00000011).
            ; А остаток по определению меньше делителя и лежит в [0,9].
            ; Таким образом, после деления экспоненты на 10 неполное частное содержит старшую десятичную цифру экспоненты,
            ; а остаток - младшую.
EXPTOSTR:   CLC                         ; EXP=|EXP|.
            ROR EXP                     ;

            LDI R18,2                   ; Поскольку частное не больше 3, то количество проверяемых двоичных цифр равно двум.

            CLR R17                     ; Здесь формируются цифры частного.

            LDI R16,-(10*2)             ; Q[i]=2=0b00000010. Сразу формируем в доп. коде.
REPEAT:     ADD EXP,R16                 ; EXP-(10*Q[I])>=0?
            BRPL SET1                   ; Да, цифра частного Q[i] равна единице.
            RJMP SET0                   ; Нет, цифра Q[i] равна нулю.

SET1:       SEC                         ; Устанавливаем текущий разряд частного в 1.
            ROL R17                     ;

            DEC R18                     ; Определены обе двоичные цифры частного?
            BREQ SETDECDIG              ; Да, частное содержит старшую десятичную цифру экспонента, а EXP - младшую.
            LDI R16,-(10*1)             ; Нет, определяем младшую цифру частного.
            RJMP REPEAT                 ; Q[i]=1=0b00000001.

SET0:       CLC                         ; Устанавливаем текущий разряд частного в 0.
            ROL R17                     ;

            DEC R18                     ; Определены обе двоичные цифры частного?
            BREQ RESTREM                ; Да, частное содержит старшую десятичную цифру экспонента, а EXP после восстановления остатка - младшую.
            LDI R16,10                  ; Нет, определяем младшую цифру частного.
            RJMP REPEAT                 ; Новый остаток вычисляется без восстановления: (EXP+20)-10=EXP+10.
            
RESTREM:    LDI R16,10                  ; Восстанавливаем последний положительный остаток.
            ADD EXP,R16                 ;

SETDECDIG:  LDI R16,0x30                ; R16='0'.

            OR R17,R16                  ; Формируем ASCII-код старшей десятичной цифры экспоненты.
            ST X+,R17                   ; Добавляем в строку.
            
            OR EXP,R16                  ; Формируем ASCII-код младшей десятичной цифры экспоненты.
            ST X+,EXP                   ; Добавляем в строку.

            LDI R16,0                   ; R16='\0'.
            ST X,R16                    ; Добавляем конец строки.

EXITFTOAE:  RET

;
; Преобразует ASCII-строку с десятичной дробью в бинарный float.
;
; В основе лежит наивный алгоритм из [Kernighan & Ritchie, The C Programming Language],
; который в общем случае даёт не лучшее двоичное приближение к входному десятичному числу.
;
; Основная идея та же, что и для FTOA - мы просто игнорируем тот факт, что десятичное представление
; исходной двоичной дроби искажается при её масштабировании и умножаем двоичную дробь на 10 так,
; словно мы непосредственно умножаем её десятичное представление, игнорируя искажения некоторых разрядов
; нового десятичного представления отмасштабированной двоичной дроби.
;
; NOTE: Поскольку в текущей реализации нет поддержки отрицательного нуля, то при получении на вход
; строки "-0" происходит формирование положительного нуля.
;
; NOTE: Исключение при делении на ноль здесь невозможно.
; А переполнение может произойти только в следующих случаях:
;   - Переполнение NUM в FMUL32 при обработке целой части.
;   - Переполнение NUM в FMUL32 при обработке дробной части.
;   - Переполнение OVERSCALE в FMUL32 при обработке дробной части.
; 
; Переполнение NUM в FADD32 при обработке целой части не может произойти.
;
; Доказательство:
; допустим, что это не так, тогда существует такое целое число, которое не даёт переполнения
; при масштабировании, когда мы извлекаем последний разряд - разряд единиц, но при этом даёт переполнение
; при прибавлении этого разряда к отмасштабированному NUM.
;
; Еще заметим, что максимальный порядок входной числовой строки - 10^38.
; То есть, любые числа, количество цифр в записи которых превышает 39, будут давать переполнение,
; Поэтому они сразу исключаются из рассмотрения.
; 
; Возьмем теперь значение 340282430000000000000000000000000000000, оно даёт переполнение в FMUL32
; уже при анализе самого младшего разряда. Следовательно, интересующее нас значение (если оно существует)
; меньше данного.
; Возьмем теперь значение на единицу меньше - 340282429999999999999999999999999999999.
; Оно не дает переполнения в FMUL32, но оно не даёт переполнения и в FADD32, когда мы прибавляем цифру из
; разряда единиц после масштабирования NUM (и прибавляем мы маскимальное значение - 9).
; Следовательно, если значение, которое даёт переполнение только в FADD32, существует, то
; оно явно должно быть меньше первого (чтобы не давать переполнения в FMUL32), но при этом
; оно должно быть больше второго (чтобы давать переполнение при прибавлении числа из разряда единиц).
; Но между 340282429999999999999999999999999999999 и 340282430000000000000000000000000000000
; не существует других целых чисел, т.е. такого значения попросту не существует.
; 
; Переполнение NUM в FADD32 при обработке дробной части не может произойти по тем же соображениям:
; достаточно заметить, что количество цифр в дробной части не должно превышать 38, чтобы
; не было переполнения OVERSCALE и по аналогии начать рассмотрение с дроби 3.40282430000000000000000000000000000000.
; Более детальные рассуждения относительно граничных входных значений десятичных числовых строк можно найти
; в основной доке.
;
; Аргументы:
;   - STR - указатель на ASCII-строку с нулём в конце, ожидается в XH:XL.
; 
; Результат:
;   - NUM - число в формате плавающей точки, помещается в R11, R10, R9, R8.
            .EQU ONE0=0x00              ; 1.0F.
            .EQU ONE1=0x00              ;
            .EQU ONE2=0x80              ;
            .EQU ONE3=0x3F              ;

            .DEF A0=R8                  ; Первый операнд любой арифметической операции: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF A1=R9                  ;
            .DEF A2=R10                 ;
            .DEF A3=R11                 ;

            .DEF B0=R12                 ; Второй операнд любой арифметической операции: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF B1=R13                 ;
            .DEF B2=R14                 ;
            .DEF B3=R15                 ;

            .DEF TMP0=R22               ; Может быть использован для временного хранения float32.
            .DEF TMP1=R23               ;
            .DEF TMP2=R24               ;
            .DEF TMP3=R25               ;

ATOF:       PUSH ZL                     ; Бэкапим адрес обработчика исключений во внешнем коде,
            PUSH ZH                     ; Поскольку сначала мы перехватываем исключение здесь, внутри ATOF.

            LDI ZL,LOW(FLOATERR0)       ; Устанавливаем обработчик исключений для первого FMUL32.
            LDI ZH,HIGH(FLOATERR0)      ;
            RJMP INITNUM                ;
FLOATERR0:  POP R16                     ; Выбрасываем из стека адрес возврата.
            POP R16                     ;
            POP R16                     ; Выбрасываем DIGIT.
            POP R16                     ; Выбрасываем SIGN.
            POP ZH                      ; Восстанавливаем адрес обработчика исключений во внешнем коде.
            POP ZL                      ; В стеке остался только адрес возврата во внешнем коде после вызова ATOF.
            IJMP                        ; Передаём управление во внешний обработчик исключений.

INITNUM:    CLR A0                      ; A=NUM=0.0F.
            CLR A1                      ;
            CLR A2                      ;
            CLR A3                      ;

            ;
            ; Определение знака числа.
            LD R16,X                    ;
            LDI R17,'-'                 ;
            EOR R16,R17                 ; Первый символ числовой строки - минус?
            BREQ MINUS                  ; Да, формируем отрицательный знак результата и пропускаем первый символ.
            CLR R16                     ; Нет, знак NUM БУДЕТ положительным - MSB старшего байта NUM будет нулевым.
            PUSH R16                    ;
            RJMP GETINT1                ;

MINUS:      LD R16,X+                   ; Пропускаем знак минуса и смещаемся к следующему символу.
            LDI R16,0b10000000          ; MSB старшего байта NUM будет содержать единицу.
            PUSH R16                    ; Сохраняем SIGN в стеке до конца вычислений.

            ;
            ; Формирование целой части.
GETINT1:    LD R16,X+                   ; R16=DIGIT=*STR++.
            AND R16,R16                 ; Прочитали конец строки?
            BREQ EXITATOF               ; Да, выходим.
            LDI R17,0x2E                ; Нет.
            EOR R17,R16                 ; Прочитали точку?
            BREQ GETFRAC1               ; Да, переходим к дробной части.
                                        ; Нет, продолжаем формировать целую часть.
            LDI R17,TEN0                ; B=10.0F
            LDI R18,TEN1                ;
            LDI R19,TEN2                ;
            LDI R20,TEN3                ;
            MOV B0,R17                  ;
            MOV B1,R18                  ;
            MOV B2,R19                  ;
            MOV B3,R20                  ;

            PUSH R16                    ; Если это не первая цифра, значит порядок NUM выше, чем мы предположили.
            CALL FMUL32                 ; A=NUM=FMUL32(NUM,10.0F).
            POP R16                     ;

            PUSH A3                     ; Бэкапим NUM.
            PUSH A2                     ;
            PUSH A1                     ;
            PUSH A0                     ;

            LDI R17,0x0F                ; Извлекаем из ASCII кода цифры обозначаемое ею число.
            AND R16,R17                 ; R16=DIGIT-0x30.
            MOV A0,R16                  ; R8=DIGIT.
            CALL ITOF                   ; A=FDIGIT=FLOAT(DIGIT).
            MOV B0,A0                   ; B=FDIGIT.
            MOV B1,A1                   ;
            MOV B2,A2                   ;
            MOV B3,A3                   ;

            POP A0                      ; A=NUM.
            POP A1                      ;
            POP A2                      ;
            POP A3                      ;

                                        ; Предполагаем, что прочитанная цифра последняя в целой части и т.о. представляет разряд единиц.
            CALL FADD32                 ; A=NUM=NUM+FDIGIT.

            RJMP GETINT1

            ;
            ; Выходим из ATOF.
EXITATOF:   CLR R16                     ;
            OR R16,A0                   ;
            OR R16,A1                   ;
            OR R16,A2                   ;
            OR R16,A3                   ; Ноль?
            BRNE SETSIGN                ; Нет, устанавливаем знак.
            POP R16                     ; Да, удаляем знак из стека.
            POP R16                     ; Удаляем адрес обработчика исключений.
            POP R16                     ;
            RET                         ; Возвращаем положительный ноль.

SETSIGN:    POP R16                     ; R16=SIGN.
            EOR A3,R16                  ; Устанавливаем знак NUM.

            POP R16                     ; ATOF отработал без исключений.
            POP R16                     ; Адрес обработчика исключений в вызывающем коде больше не нужен - удаляем его из стека.
            RET                         ; В стеке остался только адрес возврата после ATOF.

            ;
            ; Формирование дробной части.
DWNSCALE:   POP B0                      ; B=OVERSCALE.
            POP B1                      ;
            POP B2                      ;
            POP B3                      ;
                                        
                                        ; Восстанавливаем истинный порядок числа NUM после извлечения дробной части.
            CALL FDIV32                 ; A=NUM=FDIV32(NUM,OVERSCALE).

            RJMP EXITATOF               ;

GETFRAC1:   LDI R16,ONE3                ; OVERSCALE=1.0F.
            LDI R17,ONE2                ;
            LDI R18,ONE1                ;
            LDI R19,ONE0                ;
            PUSH R16                    ;
            PUSH R17                    ;
            PUSH R18                    ;
            PUSH R19                    ;

            LDI ZL,LOW(FLOATERR1)       ; Устанавливаем обработчик исключений для второго FMUL32, который масштабирует NUM.
            LDI ZH,HIGH(FLOATERR1)      ; Этот же обработчик корректно сработает при переполнении на третьем FMUL32, Который масштабирует OVERSCALE.
            RJMP GETFRAC2               ;
FLOATERR1:  POP R16                     ; Выбрасываем адрес возврата.
            POP R16                     ;
            POP R16                     ; Выбрасываем DIGIT.
            POP R16                     ; Выбрасываем 4 байта константы 1.0f в формате float32 (в случае переполнения при масштабировании NUM - второй FMUL32)
            POP R16                     ; Или 4 байта отмасштабированного с избытком NUM (в случае переполнения при масштабировании OVERSCALE - третий FMUL32).
            POP R16                     ; NOTE: Конечно, можно сразу "спустить" указатель стека в нужное место, а не делать POP для каждого элемента. Но этот способ выбран для простоты и наглядности.
            POP R16                     ;
            POP R16                     ; Выбрасываем SIGN.
            POP ZH                      ; Восстанавливаем адрес обработчика исключений во внешнем коде.
            POP ZL                      ; В стеке остался только адрес возврата во внешнем коде после вызова ATOF.
            IJMP                        ; Передаём управление во внешний обработчик исключений.

GETFRAC2:   LD R16,X+                   ; R16=DIGIT=*STR++.
            AND R16,R16                 ; Прочитали конец строки?
            BREQ DWNSCALE               ; Да, восстанавливаем порядок NUM.
                                        ; Нет, продолжаем извлекать дробные разряды.
            LDI R17,TEN0                ; B=10.0F.
            LDI R18,TEN1                ;
            LDI R19,TEN2                ;
            LDI R20,TEN3                ;
            MOV B0,R17                  ;
            MOV B1,R18                  ;
            MOV B2,R19                  ;
            MOV B3,R20                  ;

            PUSH R16                    ; Завышаем порядок NUM, чтобы текущая цифра представляла разряд единиц.
            CALL FMUL32                 ; A=NUM=FMUL32(NUM,10.0F).
            POP R16                     ;

            POP TMP0                    ; TMP=OVERSCALE.
            POP TMP1                    ;
            POP TMP2                    ;
            POP TMP3                    ;

            PUSH A3                     ; Бэкапим NUM.
            PUSH A2                     ;
            PUSH A1                     ;
            PUSH A0                     ;

            PUSH R16                    ; Бэкапим DIGIT.

            MOV A0,TMP0                 ; A=TMP=OVERSCALE.
            MOV A1,TMP1                 ;
            MOV A2,TMP2                 ;
            MOV A3,TMP3                 ;

            LDI R16,TEN0                ; B=10.0F.
            LDI R17,TEN1                ;
            LDI R18,TEN2                ;
            LDI R19,TEN3                ;
            MOV B0,R16                  ;
            MOV B1,R17                  ;
            MOV B2,R18                  ;
            MOV B3,R19                  ; 

                                        ; Отслеживаем степень завышения истинного порядка NUM.
            CALL FMUL32                 ; A=OVERSCALE=FMUL32(OVERSCALE,10.0F).
            MOV TMP0,A0                 ; TMP=A=OVERSCALE.
            MOV TMP1,A1                 ;
            MOV TMP2,A2                 ;
            MOV TMP3,A3                 ;

            POP R16                     ; R16=DIGIT.

            POP A0                      ; A=NUM.
            POP A1                      ;
            POP A2                      ;
            POP A3                      ;

            PUSH TMP3                   ; Бэкапим OVERSCALE.
            PUSH TMP2                   ;
            PUSH TMP1                   ;
            PUSH TMP0                   ;

            PUSH A3                     ; Бэкапим NUM.
            PUSH A2                     ;
            PUSH A1                     ;
            PUSH A0                     ;

            LDI R17,0x0F                ; Извлекаем из ASCII-кода цифры обозначаемое ею число.
            AND R16,R17                 ; R16=DIGIT-0x30.
            MOV A0,R16                  ; R8=DIGIT.
            CALL ITOF                   ; A=FDIGIT=FLOAT(DIGIT).
            MOV B0,A0                   ; B=FDIGIT.
            MOV B1,A1                   ;
            MOV B2,A2                   ;
            MOV B3,A3                   ;

            POP A0                      ; A=NUM.
            POP A1                      ;
            POP A2                      ;
            POP A3                      ;

            CALL FADD32                 ; A=NUM=NUM+FDIGIT.

            RJMP GETFRAC2               ;
