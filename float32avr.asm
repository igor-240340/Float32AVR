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
; Input:
;   - R11, R10, R9, R8: The dividend.
;   - R15, R14, R13, R12: The divisor.
;
; Output:
;   - R11, R10, R9, R8: The quotient.
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
; Input:
;   - R11, R10, R9, R8: The multiplicand.
;   - R15, R14, R13, R12: The multiplier.
;
; Output:
;   - R11, R10, R9, R8: The product.
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
            ADC MANTP1,R16              ; NOTE: Of course, we could detect all zeroes
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
            LDI R16,1                   ; NOTE: In fact the single range is insufficent only to distinguish negative values
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
            ; - The result of subtraction is zero.
SETZERO:    CLR MANTA0
            CLR MANTA1
            CLR MANTA2
            CLR EXPA0
            RJMP EXIT

;
; Computes the difference between two numbers.
;
; Input:
;   - R11, R10, R9, R8: The minuend.
;   - R15, R14, R13, R12: The subtrahend.
;
; Output:
;   - R11, R10, R9, R8: The difference.
FSUB32:     LDI R16,0b10000000          ; B=-B.
            EOR B3,R16                  ;
            RJMP FADD32                 ;

;
; Adds two numbers.
;
; Input:
;   - R11, R10, R9, R8: The first addend.
;   - R15, R14, R13, R12: The second addend.
;
; Output:
;   - R11, R10, R9, R8: The sum.
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
            ; Aligning the exponents.
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
            ADD R17,R16                 ; EXP(A)-EXP(B)=0? NOTE: R17 now contains the difference of the exponents in the range [0,253].
            BREQ CHOOSEOP               ; Yes, the exponents are equal; alignment is not required.
            LDI R16,31                  ; No, determine which range the difference falls into: [1,30] or [31,253]. NOTE: We've extended RGS on the whole byte.
            COM R16                     ; Form the two's complement of -31 within a byte. NOTE: There is no need for a double grid.
            INC R16                     ;
            ADD R16,R17                 ; (EXP(A)-EXP(B))-31<0? NOTE: If the true difference in the double grid is negative, there will be no carry bit from the lower byte.
            BRCC SHIFTMANTB             ; Yes, the difference is in the range [1,30]; shift the mantissa of B and form the S-bit.
            CLR MANTB0                  ; No, the difference is in the range [31,253];
            CLR MANTB1                  ; set the value of the mantissa of B to 2^-31 (rounding to the S-bit).
            CLR MANTB2                  ;
            LDI R16,0b00000001          ;
            MOV R7,R16                  ;
            RJMP CHOOSEOP               ;

            ;
            ; Shift the mantissa of B right step-by-step by the exponent difference.
            ;
            ; The exponent difference here takes values in the range [1,30].
            ; If at least one bit outside the RGS zone is set to 1, the S-bit is set.
SHIFTMANTB: CLR R16                     ; R16 will store the carry bit value in the LSB after each shift.
            CLC                         ;
            ROR MANTB2                  ; Shift the mantissa of B right by 1 bit along with the RGS bits.
            ROR MANTB1                  ;
            ROR MANTB0                  ;
            ROR R7                      ;
            ROL R16                     ; Extract the carry bit into R16.
            OR R7,R16                   ; If C!=0, a non-zero bit exists outside the RGS, so set the S-bit.

            DEC R17                     ; Is the mantissa of B shifted by the exponent difference?
            BREQ CHOOSEOP               ; Yes, proceeding to select the arithmetic operation.
            RJMP SHIFTMANTB             ; No, continue shifting.

            ;
            ; Selection of the arithmetic operation.
CHOOSEOP:   EOR R1,R0                   ; SIGN(A)=SIGN(B)?
            BRNE DIFF                   ; No, signs differ, proceed to subtraction.
                                        ; Yes, calculate the sum.

            ;
            ; Calculation of the sum of mantissa magnitudes.
            ;
            ; Only overflow is possible here.
            ; The sum is written in place of mantissa A.
SUM:        ADD R6,R7                   ; Add mantissas A and B.
            ADD R8,R12                  ; The RGS zone of mantissa A is always zero, so a carry bit is not possible.
            ADC R9,R13                  ;
            ADC R10,R14                 ;
                                        ; Is there an overflow?
            BRCC ROUNDSUM               ; No, proceed to rounding.
            ROR R10                     ; Yes, normalize the mantissa to the right.
            ROR R9                      ;
            ROR R8                      ;
            ROR R6                      ;
            CLR R16                     ; Set the S-bit if a non-zero bit was lost during normalization.
            ROL R16                     ; 
            OR R6,R16                   ;
            INC EXPA0                   ; Adjust the exponent.
            RJMP ROUNDSUM               ; In the worst case, the exponent is already 254, so adding one will not produce a carry bit in the highest byte.
            
            ;
            ; Calculation of the difference between mantissa magnitudes.
            ;
            ; NOTE: In the worst case, denormalization of the result to the right may occur within the range [0,24] when A=1 and B=((2^24)-1)*2^-23*2^-1.
            ; Assuming that after subtraction we could get a denormalization by more than 24 bits to the right (keeping in mind that the mantissa of A is always normalized),
            ; the mantissa of B would need to have more than 24 bits, which is impossible.
DIFF:       COM R7                      ; Calculate the pseudo two's complement of the mantissa B. This is a complement to 2 instead of 4.
            COM MANTB0                  ; The result is always positive, so a true two's complement is not required: the most significant bit
            COM MANTB1                  ; will always be 1, and the lower part will always generate a carry bit, zeroing out the MSB of the true two's complement.
            COM MANTB2                  ;
            LDI R16,1                   ;
            ADD R7,R16                  ;
            CLR R16                     ;
            ADC MANTB0,R16              ;
            ADC MANTB1,R16              ;
            ADC MANTB2,R16              ;

            LDI SREGACC,0b00000010      ; Mask for the Z-flag.
            ADD R6,R7                   ; Add the RGS registers.
            IN R16,SREG                 ; Extract only the Z-flag from the status register.
            AND SREGACC,R16             ;
            ADD MANTA0,MANTB0           ; Add the next pair of mantissa bytes. NOTE: Mantissa A always has a zeroed RGS zone, so no carry bit from the previous operation is possible.
            IN R16,SREG                 ;
            AND SREGACC,R16             ;
            ADC MANTA1,MANTB1           ; Add the next pair of bytes.
            IN R16,SREG                 ;
            AND SREGACC,R16             ;
            ADC MANTA2,MANTB2           ; Add the next pair of bytes.
            IN R16,SREG                 ;
            AND SREGACC,R16             ; Is the result zero? NOTE: SREGACC=(STATUS0)&(STATUS1)&(STATUS2)&(STATUS3)&(0b00000010), where STATUS<N> is the status register after adding another pair of mantissa bytes.
            BRNE SETZERO1               ; Yes, set positive zero. NOTE: If the Z flag was set for each pair of bytes, SREGACC will be non-zero.

            SBRC MANTA2,7               ; Is the difference mantissa denormalized?
            RJMP ROUNDSUM               ; No, the mantissa is normalized, proceed to rounding.
                                        ; Yes, normalize and adjust the exponent.
            CLR R16                     ; Accumulates the degree of denormalization.
            LDI R17,255                 ; We increase the degree of denormalization by -1 getting its negative value directly in two's complement.
NORM:       CLC                         ;
            ROL R6                      ; Normalize left.
            ROL MANTA0                  ;
            ROL MANTA1                  ;
            ROL MANTA2                  ;
            ADD R16,R17                 ; DEC R16. NOTE: Of course we could use native DEC instruction.
            SBRS MANTA2,7               ; Has the mantissa of the difference been normalized?
            RJMP NORM                   ; No, continue shifting.
            ADD EXPA0,R16               ; Yes, adjust the exponent: EXPA-K, where K=R16 is the degree of denormalization.
            ADC EXPA1,R17               ; R17,R16: expanded the two's complement in R16 to two bytes, leveraging that R17 already holds the value 255.

            ;
            ; Rounding.
            ;
            ; After shifting the R-bit left, the C and Z flags in the status register are checked.
            ; If C=1 and Z=0 after the shift, it indicates halfway rounding; otherwise, it is rounding up.
ROUNDSUM:   MOV R16,R6                  ; Copy RGS.
            CLC                         ;
            ROL R16                     ; Is the R-bit zero?
            BRCC CHECKEXP2              ; Yes, RGS=000|001|010|011. Discard RGS, ERR<ULP/2.
            BREQ HALFWAY1               ; No, RGS=100, halfway rounding, ERR=ULP/2.
            LDI R16,1                   ; No, RGS=101|110|111.
            RJMP ADDULP                 ; Discard RGS and add ULP. ERR<ULP/2.

HALFWAY1:   LDI R16,1                   ; Extract the value of the ULP bit.
            AND R16,R8                  ;
ADDULP:     ADD R8,R16                  ; Add ULP.
            CLR R16                     ; If the value is odd, adding ULP=1 makes the result even.
            ADC R9,R16                  ; If the value is already even, ULP=0, and adding zero does not change the result.
            ADC R10,R16                 ; Is there overflow?
            BRCC CHECKEXP2              ; No, proceed to the exponent check.
            ROR MANTA2                  ; Yes, normalize mantissa A. Since there was an overflow during rounding, the two least significant bytes of the mantissa are already zero.
            INC EXPA0                   ; Adjust the exponent.

            ;
            ; Check the exponent for overflow/underflow.
            ;
            ; The biased exponent ranges from -22 to 255.
            ; NOTE: Consider the difference between A=1*2^-125 and B=((2^24)-1)*2^-23*2^-126.
            ; This difference results in a maximum right denormalization of 24 bits.
            ; Therefore, after normalization, the exponent of the difference will be equal to -125-24=-149 or -149+127=-22 in biased representation.
            ; The same conclusion can be reached by taking A=(1+2^-23)*2^-126 and B=1*2^-126.
            ;
            ; If there is an overflow, the exponent is 255, and subtracting it from 255 results in zero.
            ; If there is no overflow, subtracting the exponent from 255 will yield a positive value.
            ; If there is underflow, the exponent takes values in the range [-22,0], and subtracting one from the exponent will always yield a negative value.
            ; If there is no underflow, then, since overflow is already excluded, the exponent lies in [1,254], and subtracting one will always yield a non-negative value.
CHECKEXP2:  LDI R17,255                 ; Write 255 into two bytes.
            LDI R18,0                   ;

            MOV R21,EXPA0               ; Copy the extended exponent of A.
            MOV R22,EXPA1               ;

            COM R21                     ; Calculate the two-byte two's complement of the exponent.
            COM R22                     ; NOTE: We don't actually need extended two's complement:
            LDI R16,1                   ; we could just check first byte of the result for zero and check the carry bit.
            ADD R21,R16                 ;
            CLR R16                     ;
            ADC R22,R16                 ;

            ADD R17,R21                 ; 255-EXP(A).
            IN STATUS0,SREG             ; Save flags after adding the lower bytes.
            ADC R18,R22                 ;
            IN STATUS1,SREG             ; Save flags after adding the higher bytes

            AND STATUS0,STATUS1         ; The result is zero if the Z flag was set for each byte.
            SBRC STATUS0,SREG_Z         ; Is the exponent equal to 255?
            IJMP                        ; Yes, overflow. Jump to error handler specified in register Z.
            LDI R16,255                 ; No, check for underflow.
            LDI R17,255                 ;
            ADD R16,EXPA0               ; EXP(A)-1.
            ADC R17,EXPA1               ; Is the result negative?
            BRMI SETZERO1               ; Yes, underflow; the exponent is in [0,-22] and cannot be represented. Flush to zero.
                                        ; No, the exponent is in [1,254] and can be represented in single-precision float.

            ;
            ; Packing the sum.
            ROL MANTA0                  ; Shift the integer one of the sum's mantissa into the carry bit.
            ROL MANTA1                  ;
            ROL MANTA2                  ;
            ROL RSIGN                   ; Shift the sign bit into the carry bit.
            ROR EXPA0                   ; Insert the sign bit into the MSB of the exponent and shift the LSB of the exponent into the carry bit.
            ROR MANTA2                  ; Restore the original bits of the mantissa by shifting the LSB of the exponent into the MSB of the higher byte
            ROR MANTA1                  ; of the mantissa instead of the integer one.
            ROR MANTA0                  ;

            RJMP EXIT1
            
            ; Exit from FADD32.
EXIT1:      RET

            ;
            ; Set the result to zero.
            ;
            ; Executed in the following cases:
            ; - Underflow of the result for any operation.
            ; - The dividend is zero.
            ; - At least one multiplicand is zero.
            ; - Both addends are zero.
            ; - The result of subtraction is zero
SETZERO1:   CLR MANTA0
            CLR MANTA1
            CLR MANTA2
            CLR EXPA0
            RJMP EXIT1

;
; Truncates a floating-point number to an integer.
;
; Works only with positive normalized decimal numbers in the range [1,10).
; Thus, it returns an integer value in the range [1,9] within a byte.
; 
; Input:
;   - R11, R10, R9, R8: A number NUM.
;
; Output:
;   - R8: Integer part of NUM.
            .DEF A0=R8                  ;
            .DEF A1=R9                  ;
            .DEF A2=R10                 ;
            .DEF A3=R11                 ;

            .DEF STATUS=R21             ; STATUS regiser.

FTOI:       ROL A2                      ; Unpacking NUM.
            ROL A3                      ; A3=EXP(NUM). Since NUM is in [1,10), all bits of the integer part of the true decimal value
            SEC                         ; are entirely contained within the higher byte of the binary normalized mantissa, and there is no need to shift the lower bytes.
            ROR A2                      ;
           
            CLR A0                      ; Only A2 contains all bits of the integer part of the true value, so we can use A0 for holding the resulting integer value.
            LDI R16,-127                ; A3=EXP(NUM)-127. The exponent falls within [127,127+3], so the difference is always non-negative and it's enough to have two's complement within a byte.
            ADD A3,R16                  ; Is the exponent zero? (If zero, the integer part of the mantissa already represents the integer part of the true value, which is equal to one.)
            BREQ SHFTMSB                ; Yes, perform the final shift.
            MOV R16,A3                  ; No, set the loop counter to the exponent value and denormalize the mantissa to the left.
DENORM:     ROL A2                      ; MANT(A)<<1
            ROL A0                      ;
            DEC R16                     ; Is the mantissa denormalized to the left by the value of the exponent?
            BREQ SHFTMSB                ; Yes, perform the final shift.
            RJMP DENORM                 ; No, continue shifting.

SHFTMSB:    ROL A2                      ; A0=INT(NUM). (The MSB of the mantissa contains the LSB of the integer part of the true value - shift it into A0.)
            ROL A0                      ;

            RET

;
; Converts a positive one-byte integer to a floating-point number.
;
; Input:
;   - R8: Integer value NUM.
;
; Output: 
;   - R11, R10, R9, R8: Floating-point representation of NUM.
            .DEF A0=R8                  ;
            .DEF A1=R9                  ;
            .DEF A2=R10                 ;
            .DEF A3=R11                 ;

            .DEF STATUS=R21             ; STATUS register.

SETZERO3:   CLR A0                      ; A=0.0F.
            CLR A1                      ;
            CLR A2                      ;
            CLR A3                      ;
            RET                         ;

ITOF:       AND A0,A0                   ; NUM=0?
            BREQ SETZERO3               ; Yes, return 0.0f.

            CLR A1                      ; Lower bytes of the mantissa.
            CLR A2                      ;
            LDI R16,-1                  ; Exponent byte. Initialize to -1 for a dummy increment during the first shift.
            MOV A3,R16                  ; NOTE: The first shift does not change the weight of the LSB of the true integer value.

            CLC                         ; A2 is zero, so the final shift of A2 always clears the carry bit and there is no need to clear it on each iteration.
NORM0:      INC A3                      ; Combine the LSB of the integer with the MSB of the mantissa,
            ROR A0                      ; effectively producing a left-denormalized mantissa.
            IN STATUS,SREG              ; Save the Z flag for A0.
            ROR A2                      ; 
            SBRS STATUS,SREG_Z          ; Is the mantissa normalized? (If A0 initially equals 1, it will zero out, and the mantissa will be immediately normalized.)
            RJMP NORM0                  ; No, continue normalization.
                                        ; Yes, proceed to packing.
            LDI R16,127                 ; Make the exponent biased.
            ADD A3,R16                  ;

                                        ; Remove the integer one from the mantissa.
            ROL A2                      ; The input number fits within one byte, so all non-zero bits are already in A2, while A0 and A1 are set to zero.

            CLC                         ; The result will be positive – the sign bit is zero.
            ROR A3                      ; Shift the exponent close to the mantissa without the integer one.

            ROR A2                      ; Place the LSB of the exponent into the MSB of the mantissa.

            RET

;
; Converts a normalized decimal number in floating-point representation to an ASCII string.
;
; Based on a naive algorithm implemented in z88dk, but simplified to support only normalized decimal numbers.
; [https://github.com/z88dk/z88dk/blob/aa60b9c9e4bab3318b9b10e919919058a4d3aaee/libsrc/math/cimpl/ftoa.c]
;
; Main idea of the algorithm: we ignore the fact that the decimal representation of the original binary fraction is distorted when it is scaled.
; As a result, not all decimal digits in the string are exact.
; Furthermore, when rounding the decimal string representation, digits are simply truncated.
;
; Input:
;   - R11, R10, R9, R8: Floating-point number NUM within the range [1,10).
;   - R12: Number of required digits PRECISION in the string after the decimal point.
;   - XH:XL: Pointer STR to the SRAM location where the ASCII string representation of the number will be stored.
;
; Output:
;   - XH:XL: ASCII string representation STR of the number.
            .EQU TEN0=0x00              ; 10.0f.
            .EQU TEN1=0x00              ;
            .EQU TEN2=0x20              ;
            .EQU TEN3=0x41              ;

            .DEF A0=R8                  ; The first operand of any arithmetic operation: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF A1=R9                  ;
            .DEF A2=R10                 ;
            .DEF A3=R11                 ;

            .DEF B0=R12                 ; The second operand of any arithmetic operation: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF B1=R13                 ;
            .DEF B2=R14                 ;
            .DEF B3=R15                 ;

            ;
            ; Form the string "0" if NUM = 0.0f.
SETZERO2:   LDI R16,0x30                ;
            ST X+,R16                   ; *STR++='0'.
            RJMP EXITFTOAN              ;

FTOAN:      CLR R16                     ;
            OR R16,A0                   ;
            OR R16,A1                   ;
            OR R16,A2                   ;
            OR R16,A3                   ; NUM=0?
            BREQ SETZERO2               ; Yes, form a fixed string "0".

            PUSH R12                    ; Backup PRECISION, as it is located in one of the input registers for arithmetic operations.

            LDI R16,0b10000000          ; Extract the sign of NUM.
            AND R16,A3                  ; NUM>0?
            BREQ GETINT                 ; Yes, NUM is positive, continue.
            EOR A3,R16                  ; No, calculate the absolute value NUM=|NUM| and
            LDI R16,0x2D                ; start the string with the '-' sign.
            ST X+,R16                   ; *STR++='-'.

            ;
            ; Extract the decimal digit of the integer part.
GETINT:     PUSH A3                     ; Backup NUM=|NUM|.
            PUSH A2                     ;
            PUSH A1                     ;
            PUSH A0                     ;
            CALL FTOI                   ; A0=DIGIT=INT(NUM).
            
            LDI R16,0x30                ; *STR++=ASCII(DIGIT).
            ADD R16,A0                  ;
            ST X+,R16                   ;

            CALL ITOF                   ; A=FDIGIT=FLOAT(DIGIT). The extracted digit is now stored as a float32 number, not an integer.

            MOV B0,A0                   ; B=A=FDIGIT.
            MOV B1,A1                   ;
            MOV B2,A2                   ;
            MOV B3,A3                   ;

            POP A0                      ; A=NUM=|NUM|.
            POP A1                      ;
            POP A2                      ;
            POP A3                      ;

            CALL FSUB32                 ; A=NUM=FSUB32(NUM,FDIGIT). Now the integer decimal digit has been removed from NUM, the digit we just extracted.

            ;
            ; Adding the decimal point to the string.
            LDI R16,0x2E                ; *STR++='.'.
            ST X+,R16                   ;

            ;
            ; Extracting fractional decimal digits.
            ;
            ; Input value NUM<1.
            ; NOTE: The minimum normalized decimal number NUM=2^0=1.
            ; The maximum normalized number NUM=(2^3+2^1)-(2^-23*2^3)=10-2^-20=9.99999904632568359375f.
            ; The minimum normalized value that will yield a non-zero result after extracting the integer part is 2^0+2^-23.
            ; Thus, the binary exponent after extracting the integer part lies in the range [-23,-1] or [104,126] in biased form.
            ; And after multiplying by 10, the exponent lies in the range [-20,3] or [107,130] in biased form.
GETFRAC:    LDI R16,TEN0                ; B=10.0f.
            LDI R17,TEN1                ;
            LDI R18,TEN2                ;
            LDI R19,TEN3                ;
            MOV B0,R16                  ;
            MOV B1,R17                  ;
            MOV B2,R18                  ;
            MOV B3,R19                  ;

            CALL FMUL32                 ; A=NUM'=FMUL32(NUM,10.0f). After GETINT: A=NUM,NUM<1.

            PUSH A3                     ; Back up NUM' as we'll be unpacking its exponent next.
            PUSH A2                     ;
            PUSH A1                     ;
            PUSH A0                     ;

            ROL A2                      ; If the number remains less than one after extracting the integer part and multiplying by 10,
            ROL A3                      ; the exponent will lie in [-20,-1] or [107,126] in biased form. Therefore,
            LDI R16,-127                ; adding the two's complement of -127 within a byte will not produce a carry, indicating that the true exponent is negative, and the number is less than one (the integer part is zero).
            ADD R16,A3                  ; NUM' is in [0,1)? (If NUM' is zero, the exponent field is also zero, which will result in a negative difference so this condition is already covered.)
            BRCS ASCIIDIG1              ; No, in the integer part of NUM', there is a non-zero decimal fractional digit, extract it.
            LDI R16,0x30                ; Yes, the next fractional digit is zero, setting the digit to zero.
            ST X+,R16                   ; *STR++='0'.

            POP A0                      ; A=NUM'.
            POP A1                      ; Restoring the state expected in COND1.
            POP A2                      ; Now PRECISION is at the top of the stack.
            POP A3                      ;

            RJMP COND1                  ;

ASCIIDIG1:  POP A0                      ; A=NUM', now NUM' is a normalized decimal fraction.
            POP A1                      ; Restore the original value,
            POP A2                      ; unaffected by the exponent unpacking.
            POP A3                      ;

            PUSH A3                     ; Backup NUM' again,
            PUSH A2                     ; as we will need to remove
            PUSH A1                     ; the integer part from it next.
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

                                        ; Subtract the extracted fractional digit from the integer part of NUM'.
            CALL FSUB32                 ; A=NUM=FSUB32(NUM',FDIGIT). Now again, NUM<1.

COND1:      POP R16                     ; R16=PRECISION.
            DEC R16                     ; PRECISION--. Did we extract the specified number of fractional digits?
            BREQ EXITFTOAN              ; Yes, STR contains the decimal digits of the number NUM, the stack holds the return address.
            PUSH R16                    ; No, we back up PRECISION again and
            RJMP GETFRAC                ; extract the next decimal fractional digit.

EXITFTOAN:  LDI R16,0                   ;
            ST X,R16                    ; Add the end of the line '\0'.
            RET

;
; Forms an ASCII string with the decimal representation of a float variable in exponential form.
;
; If the number is already decimal-normalized, conversion to a string is simply performed via FTOAN,
; considering the maximum string length limit MAXLEN.
;
; Otherwise, decimal normalization of the number is performed, followed by conversion of the normalized number
; to a string via FTOAN, with a limited number of digits after the decimal point to ensure that the total
; length of the resulting string (including the minus sign, decimal point, and exponent) does not exceed MAXLEN.
;
; Input:
;   - R11, R10, R9, R8: The floating-point number NUM.
;   - R12: The maximum output string length MAXLEN. Currently expected to be 16, matching the character limit of the LCD1602.
;   - XH:XL: Pointer STR to the SRAM area where the ASCII string will be stored.
;
; Output:
;   - XH:XL: ASCII string located at address XH:XL.
            .DEF EXP=R0                 ; Binary exponent value.

            .DEF A0=R8                  ; First operand of any arithmetic operation: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF A1=R9                  ; It also holds NUM value.
            .DEF A2=R10                 ;
            .DEF A3=R11                 ;

            .DEF MAXLEN=R12             ; Maximum length of the output string with the decimal representation of NUM.

            .DEF B0=R12                 ; Second operand of any arithmetic operation: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF B1=R13                 ;
            .DEF B2=R14                 ;
            .DEF B3=R15                 ;

            .DEF TMP0=R22               ; Can be used for temporary storage of a float32 value.
            .DEF TMP1=R23               ;
            .DEF TMP2=R24               ;
            .DEF TMP3=R25               ;
            
FTOAE:      PUSH MAXLEN                 ; Back up MAXLEN.

            CLR EXP                     ; EXP=0.

            PUSH A3                     ; Back up the two most significant bytes of NUM.
            PUSH A2                     ;
            ROL A2                      ; Unpack the exponent of NUM.
            ROL A3                      ;
            LDI R16,-127                ;
            ADD R16,A3                  ;
            POP A2                      ; Restore the higher two bytes of NUM, replacing those that were modified during the unpacking of the exponent.
            POP A3                      ; Is the biased exponent in [1,126] or exponent field is zero?
            BRMI NORMLFT                ; Yes, this means either the true exponent is in the range [-126,-1], which means NUM<1 and INT(NUM)=0, or NUM is zero. In both cases proceed to normalizing to the left.

NORMRGHT:   PUSH A3                     ; No, NUM>=1, this means NUM is either already normalized, or denormalized to the left (in that case, normalize to the right).
            PUSH A2                     ; Backup the current value of NUM. NOTE: It may already be normalized.
            PUSH A1                     ;
            PUSH A0                     ;

            LDI R16,TEN0                ; B=10.0f.
            LDI R17,TEN1                ;
            LDI R18,TEN2                ;
            LDI R19,TEN3                ;
            MOV B0,R16                  ;
            MOV B1,R17                  ;
            MOV B2,R18                  ;
            MOV B3,R19                  ;

            PUSH EXP                    ;
            CALL FDIV32                 ; A=NUM=FDIV32(NUM,10.0f).
            POP EXP                     ;

            PUSH A3                     ; Back up the higher two bytes of NUM.
            PUSH A2                     ;
            ROL A2                      ; Unpack the exponent of NUM.
            ROL A3                      ;
            LDI R16,-127                ;
            ADD R16,A3                  ;
            POP A2                      ; Restore the higher byte of NUM, modified by the extraction of the exponent.
            POP A3                      ; Is the biased exponent in the range [1,126]?
            BRMI RESTNORM               ; Yes, this means the true exponent is in [-126,-1], implying that NUM<1, and the previous value before division by 10 was already normalized.
            
            INC EXP                     ; No, NUM>=1, so the previous value was not normalized. Remember the decrease in the decimal order of NUM.

            POP R16                     ; Remove the previous value of NUM.
            POP R16                     ;
            POP R16                     ;
            POP R16                     ;
            RJMP NORMRGHT               ;

RESTNORM:   POP A0                      ; Restore the last value of NUM, which is already normalized.
            POP A1                      ;
            POP A2                      ;
            POP A3                      ;
            RJMP CONVMANT               ;

NORMLFT:    CLR R16                     ;
            OR R16,A0                   ;
            OR R16,A1                   ;
            OR R16,A2                   ;
            OR R16,A3                   ; NUM=0.0f?
            BREQ CONVMANT               ; Yes, NUM=0.0f - FTOAN will handle zero correctly and return a string with the zero character. EXP also remains zero.

            LDI R16,TEN0                ; B=10.0f.
            LDI R17,TEN1                ;
            LDI R18,TEN2                ;
            LDI R19,TEN3                ;
            MOV B0,R16                  ;
            MOV B1,R17                  ;
            MOV B2,R18                  ;
            MOV B3,R19                  ;

            PUSH EXP                    ;
            CALL FMUL32                 ; A=NUM=FMUL32(NUM,10.0f).
            POP EXP                     ;
            INC EXP                     ; EXP++.

            PUSH A3                     ; Back up the higher two bytes of NUM.
            PUSH A2                     ;
            ROL A2                      ; Unpack the exponent of NUM.
            ROL A3                      ;
            LDI R16,-127                ;
            ADD R16,A3                  ;
            POP A2                      ; Restore NUM.
            POP A3                      ; NUM>=1?
            BRMI NORMLFT                ; No, continue normalization.

            LDI R16,0b10000000          ; EXP=-EXP. Represent the negative exponent in sign-magnitude format.
            OR EXP,R16                  ;

            ;
            ; Convert the decimal mantissa to a string.
            ;
            ; NOTE: We normalized NUM (if it wasn't initially normalized), and this value now represents
            ; the mantissa in decimal exponential notation.
CONVMANT:   POP MAXLEN                  ; Restore MAXLEN.

            AND EXP,EXP                 ; EXP=0?
            BREQ CHKSGN                 ; Yes, the true value of NUM is already normalized; exponential form is not required.

            LDI R16,-4                  ; No, reserve 4 characters in the string for the exponent: E{+|-}00.
            ADD MAXLEN,R16              ; MAXLEN=MAXLEN-4.

CHKSGN:     LDI R16,0b10000000          ; Sign mask.
            AND R16,A3                  ; NUM<0?
            BRNE NUMNEG                 ; Yes, reserve one character in the output string for '-'.
            
            LDI R16,-2                  ; No, reserve only two characters for the integer digit and the decimal point.
            ADD MAXLEN,R16              ; MAXLEN=MAXLEN-2.
            RJMP CALLFTOAN              ;

NUMNEG:     LDI R16,-2-1                ; Reserve two characters for the integer digit and the decimal point, plus one more character for the '-' sign.
            ADD MAXLEN,R16              ; MAXLEN=(MAXLEN-2)-1.

CALLFTOAN:  PUSH EXP                    ;
            CALL FTOAN                  ; STR=FTOAN(NUM,MAXLEN). After calculations, MAXLEN effectively holds PRECISION,
            POP EXP                     ; which ensures that the initial MAXLEN value will not be exceeded.

            AND EXP,EXP                 ; EXP=0?
            BREQ EXITFTOAE              ; Yes, exit.

            LDI R16,'E'                 ; No, append the exponent after the string.
            ST X+,R16                   ; STR+='E'.

            ROL EXP                     ; EXP<0? NOTE: The negative exponent is represented in sign-magnitude format.
            BRCC SETPLUS                ; No, EXP>0, set '+'.
            LDI R16,'-'                 ; Yes, set '-'.
            ST X+,R16                   ;
            RJMP EXPTOSTR               ;
SETPLUS:    LDI R16,'+'                 ;
            ST X+,R16                   ;

            ;
            ; Convert the exponent to a string.
            ;
            ; If the exponent is non-zero, then the absolute value of the exponent lies in the range [1,38].
            ; This means that the incomplete quotient from division by 10 does not exceed 3 (0b00000011).
            ; The remainder, by definition, is less than the divisor and lies in the range [0,9].
            ; Thus, after dividing the exponent by 10, the quotient contains the most significant decimal digit of the exponent,
            ; and the remainder contains the least significant decimal digit.
EXPTOSTR:   CLC                         ; EXP=|EXP|.
            ROR EXP                     ;

            LDI R18,2                   ; Since the quotient does not exceed 3, the number of binary digits to check is two.

            CLR R17                     ; The digits of the quotient are formed here.

            LDI R16,-(10*2)             ; Q[i]=2=0b00000010. Form immediately in two's complement.
REPEAT:     ADD EXP,R16                 ; EXP-(10*Q[i])>=0?
            BRPL SET1                   ; Yes, the quotient digit Q[i] equals one.
            RJMP SET0                   ; No, the digit Q[i] equals zero.

SET1:       SEC                         ; Set the current digit of the quotient to 1.
            ROL R17                     ;

            DEC R18                     ; Are both binary digits of the quotient determined?
            BREQ SETDECDIG              ; Yes, the quotient contains the value corresponding to the most significant decimal digit of the exponent, while EXP holds the remainder, corresponding to the least significant digit.
            LDI R16,-(10*1)             ; No, determine the least significant binary digit of the quotient.
            RJMP REPEAT                 ; Q[i]=1=0b00000001.

SET0:       CLC                         ; Set the current bit of the quotient to 0.
            ROL R17                     ;

            DEC R18                     ; Are both binary digits of the quotient determined?
            BREQ RESTREM                ; Yes, the quotient contains the value corresponding to the most significant decimal digit of the exponent, while EXP will hold the remainder (after restoring), corresponding to the least significant digit.
            LDI R16,10                  ; No, determine the least significant binary digit of the quotient.
            RJMP REPEAT                 ; The new remainder is calculated without restoring: (EXP+20)-10=EXP+10.
            
RESTREM:    LDI R16,10                  ; Restore the last non-negative remainder.
            ADD EXP,R16                 ;

SETDECDIG:  LDI R16,0x30                ; R16='0'.

            OR R17,R16                  ; Form the ASCII code of the most significant decimal digit of the exponent.
            ST X+,R17                   ; Append to the string.
            
            OR EXP,R16                  ; Form the ASCII code of the least significant decimal digit of the exponent.
            ST X+,EXP                   ; Append to the string.

            LDI R16,0                   ; R16='\0'.
            ST X,R16                    ; Append the end of the line.

EXITFTOAE:  RET

;
; Converts an ASCII string containing a decimal fraction into a binary float.
;
; Based on the naive algorithm from [Kernighan & Ritchie, The C Programming Language],
; which generally does not provide the best binary approximation for the input decimal number.
;
; The main idea is the same as for FTOA - we simply ignore the fact that the decimal representation
; of the initial binary fraction gets distorted during scaling and multiply the binary fraction by 10
; as if we were directly multiplying its decimal representation, disregarding distortions in certain
; digits of the new decimal representation of the scaled binary fraction.
;
; NOTE: Since the current implementation does not support negative zero,
; an input string "-0" results in positive zero.
;
; NOTE: Division by zero exception is not possible here.
; Overflow can only occur in the following cases:
;   - Overflow of NUM in FMUL32 during the processing of the integer part.
;   - Overflow of NUM in FMUL32 during the processing of the fractional part.
;   - Overflow of OVERSCALE in FMUL32 during the processing of the fractional part.
; 
; Overflow of NUM in FADD32 during the processing of the integer part cannot occur.
;
; Proof:
; Assume this is not the case. Then there exists an integer that does not cause overflow
; during scaling when extracting the last digit (the ones place), but causes overflow
; when adding this digit to the scaled NUM.
;
; Note also that the maximum order of the input numeric string is 10^38.
; That is, any numbers with more than 39 digits in their representation will cause overflow
; and are therefore immediately excluded from consideration.
; 
; Now consider the value 340282430000000000000000000000000000000, which causes overflow in FMUL32
; even during the analysis of the least significant digit. Therefore, the value we are interested in (if it exists)
; is less than this one.
; Now consider the value one less than the previous one - 340282429999999999999999999999999999999.
; It does not cause overflow in FMUL32, nor does it cause overflow in FADD32, when adding the digit
; from the units place after scaling NUM (and we add the maximum value - 9).
; Therefore, if a value that causes overflow only in FADD32 exists,
; it must be less than the first value (to avoid overflow in FMUL32),
; yet greater than the second value (to cause overflow when adding the digit from the units place).
; However, there are no other integers between 340282429999999999999999999999999999999 and 340282430000000000000000000000000000000,
; meaning such a value simply does not exist (for any fractional number between the mentioned ones we get overflow in FMUL32).
; 
; Overflow of NUM in FADD32 during fractional part processing cannot occur for the same reason.
; First, note that the number of digits in the fractional part must not exceed 38 to avoid OVERSCALE overflow and
; then start by considering the fraction 3.40282430000000000000000000000000000000.
; More detailed reasoning about the boundary input values of decimal numeric strings
; can be found in the main documentation.
;
; Input:
;   - XH:XL: Pointer STR to an ASCII string with a null terminator.
; 
; Output:
;   - R11, R10, R9, R8: Floating-point number NUM.
            .EQU ONE0=0x00              ; 1.0f.
            .EQU ONE1=0x00              ;
            .EQU ONE2=0x80              ;
            .EQU ONE3=0x3F              ;

            .DEF A0=R8                  ; The first operand of any arithmetic operation: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF A1=R9                  ;
            .DEF A2=R10                 ;
            .DEF A3=R11                 ;

            .DEF B0=R12                 ; The second operand of any arithmetic operation: FDIV32,FMUL32,FADD32,FSUB32.
            .DEF B1=R13                 ;
            .DEF B2=R14                 ;
            .DEF B3=R15                 ;

            .DEF TMP0=R22               ; Can be used for temporary storage of a float32.
            .DEF TMP1=R23               ;
            .DEF TMP2=R24               ;
            .DEF TMP3=R25               ;

ATOF:       PUSH ZL                     ; Back up the exception handler address in external code,
            PUSH ZH                     ; as we first intercept the exception here within ATOF.

            LDI ZL,LOW(FLOATERR0)       ; Set the exception handler for the first call of FMUL32.
            LDI ZH,HIGH(FLOATERR0)      ;
            RJMP INITNUM                ;
FLOATERR0:  POP R16                     ; Discard the return address.
            POP R16                     ;
            POP R16                     ; Discard DIGIT.
            POP R16                     ; Discard SIGN.
            POP ZH                      ; Restore the exception handler address in the external code.
            POP ZL                      ; The stack now contains only the return address after the ATOF call in the external code.
            IJMP                        ; Pass control to the external exception handler.

INITNUM:    CLR A0                      ; A=NUM=0.0f.
            CLR A1                      ;
            CLR A2                      ;
            CLR A3                      ;

            ;
            ; Determine the sign of the number.
            LD R16,X                    ;
            LDI R17,'-'                 ;
            EOR R16,R17                 ; Is the first character of the numeric string a minus sign?
            BREQ MINUS                  ; Yes, form the negative sign for the result and skip the first character.
            CLR R16                     ; No, the sign of NUM will be positive - the MSB of the higher byte of NUM will be zero.
            PUSH R16                    ;
            RJMP GETINT1                ;

MINUS:      LD R16,X+                   ; Skip the minus sign and move to the next character.
            LDI R16,0b10000000          ; The MSB of the higher byte of NUM will contain 1.
            PUSH R16                    ; Save SIGN to the stack until the end of calculations.

            ;
            ; Handling the integer part.
GETINT1:    LD R16,X+                   ; R16=DIGIT=*STR++.
            AND R16,R16                 ; End of string reached?
            BREQ EXITATOF               ; Yes, exit.
            LDI R17,0x2E                ; No.
            EOR R17,R16                 ; Decimal point reached?
            BREQ GETFRAC1               ; Yes, proceed to the fractional part.
                                        ; No, continue handling the integer part.
            LDI R17,TEN0                ; B=10.0f
            LDI R18,TEN1                ;
            LDI R19,TEN2                ;
            LDI R20,TEN3                ;
            MOV B0,R17                  ;
            MOV B1,R18                  ;
            MOV B2,R19                  ;
            MOV B3,R20                  ;

            PUSH R16                    ; If this is not the first digit, the order of NUM is higher than initially assumed.
            CALL FMUL32                 ; A=NUM=FMUL32(NUM,10.0f).
            POP R16                     ;

            PUSH A3                     ; Backup NUM.
            PUSH A2                     ;
            PUSH A1                     ;
            PUSH A0                     ;

            LDI R17,0x0F                ; Extract the numeric value represented by the ASCII code of the digit.
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

                                        ; Assume the read digit is the last in the integer part and thus represents the units place.
            CALL FADD32                 ; A=NUM=NUM+FDIGIT.

            RJMP GETINT1

            ;
            ; Exit ATOF.
EXITATOF:   CLR R16                     ;
            OR R16,A0                   ;
            OR R16,A1                   ;
            OR R16,A2                   ;
            OR R16,A3                   ; Zero?
            BRNE SETSIGN                ; No, set the sign.
            POP R16                     ; Yes, discard the sign from the stack.
            POP R16                     ; Discard the backed-up external exception handler from the stack.
            POP R16                     ;
            RET                         ; Return positive zero.

SETSIGN:    POP R16                     ; R16=SIGN.
            EOR A3,R16                  ; Set the sign for NUM.

            POP R16                     ; ATOF finished without exceptions, so the backed up address of the exception handler in the calling code
            POP R16                     ; is no longer needed. That's why we remove it from the stack.
            RET                         ; Only the return address after the ATOF call remains on the stack.

            ;
            ; Handling the fractional part.
DWNSCALE:   POP B0                      ; B=OVERSCALE.
            POP B1                      ;
            POP B2                      ;
            POP B3                      ;
                                        
                                        ; Restore the true order of the number NUM after extracting the fractional part.
            CALL FDIV32                 ; A=NUM=FDIV32(NUM,OVERSCALE).

            RJMP EXITATOF               ;

GETFRAC1:   LDI R16,ONE3                ; OVERSCALE=1.0f.
            LDI R17,ONE2                ;
            LDI R18,ONE1                ;
            LDI R19,ONE0                ;
            PUSH R16                    ;
            PUSH R17                    ;
            PUSH R18                    ;
            PUSH R19                    ;

            LDI ZL,LOW(FLOATERR1)       ; Set the exception handler for the second FMUL32 call, which scales NUM.
            LDI ZH,HIGH(FLOATERR1)      ; The same handler will correctly handle overflow during the third FMUL32 call, which increases OVERSCALE.
            RJMP GETFRAC2               ;
FLOATERR1:  POP R16                     ; Discard the return address.
            POP R16                     ;
            POP R16                     ; Discard DIGIT.
            POP R16                     ; Discard 4 bytes of OVERSCALE (in case of overflow during the NUM scaling - the second FMUL32 call)
            POP R16                     ; or discard 4 bytes of excessively scaled NUM (in case of overflow during OVERSCALE scaling - the third FMUL32 call).
            POP R16                     ; NOTE: Of course, we could adjust the stack pointer directly to the desired position instead of performing a POP for each element.
            POP R16                     ; But the main goal here is explicitness.
            POP R16                     ; Discard SIGN.
            POP ZH                      ; Restore the address of the exception handler in the external code.
            POP ZL                      ; Only the return address after the ATOF call in the external code remains on the stack.
            IJMP                        ; Pass control to the external exception handler.

GETFRAC2:   LD R16,X+                   ; R16=DIGIT=*STR++.
            AND R16,R16                 ; End of string reached?
            BREQ DWNSCALE               ; Yes, restore the true order of NUM.
                                        ; No, continue extracting fractional digits.
            LDI R17,TEN0                ; B=10.0f.
            LDI R18,TEN1                ;
            LDI R19,TEN2                ;
            LDI R20,TEN3                ;
            MOV B0,R17                  ;
            MOV B1,R18                  ;
            MOV B2,R19                  ;
            MOV B3,R20                  ;

            PUSH R16                    ; Increase the order of NUM so that the current digit represents the units place.
            CALL FMUL32                 ; A=NUM=FMUL32(NUM,10.0f).
            POP R16                     ;

            POP TMP0                    ; TMP=OVERSCALE.
            POP TMP1                    ;
            POP TMP2                    ;
            POP TMP3                    ;

            PUSH A3                     ; Backup NUM.
            PUSH A2                     ;
            PUSH A1                     ;
            PUSH A0                     ;

            PUSH R16                    ; Backup DIGIT.

            MOV A0,TMP0                 ; A=TMP=OVERSCALE.
            MOV A1,TMP1                 ;
            MOV A2,TMP2                 ;
            MOV A3,TMP3                 ;

            LDI R16,TEN0                ; B=10.0f.
            LDI R17,TEN1                ;
            LDI R18,TEN2                ;
            LDI R19,TEN3                ;
            MOV B0,R16                  ;
            MOV B1,R17                  ;
            MOV B2,R18                  ;
            MOV B3,R19                  ; 

                                        ; Keep track of how much the true order of NUM is exceeded.
            CALL FMUL32                 ; A=OVERSCALE=FMUL32(OVERSCALE,10.0f).
            MOV TMP0,A0                 ; TMP=A=OVERSCALE.
            MOV TMP1,A1                 ;
            MOV TMP2,A2                 ;
            MOV TMP3,A3                 ;

            POP R16                     ; R16=DIGIT.

            POP A0                      ; A=NUM.
            POP A1                      ;
            POP A2                      ;
            POP A3                      ;

            PUSH TMP3                   ; Backup OVERSCALE.
            PUSH TMP2                   ;
            PUSH TMP1                   ;
            PUSH TMP0                   ;

            PUSH A3                     ; Backup NUM.
            PUSH A2                     ;
            PUSH A1                     ;
            PUSH A0                     ;

            LDI R17,0x0F                ; Extract the numeric value represented by the ASCII code of the digit.
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
