            .INCLUDE <m328pdef.inc>

            .EQU SP=RAMEND-(3*4+255)        ; Under the stack: 3 variables of 4 bytes each + a 255-byte ASCII string.

            .DSEG
            .ORG SP+1                       ;
A:          .BYTE 4                         ; Operand A.
B:          .BYTE 4                         ; Operand B.
C:          .BYTE 4                         ; Result C.
NUMSTR:     .BYTE 255                       ; Pointer to the numeric ASCII string in SRAM.

            .CSEG
            .ORG 0x00

            RJMP RESET
            
            .INCLUDE "float32avr.asm"

RESET:      LDI YL,LOW(SP)
            LDI YH,HIGH(SP)
            OUT SPL,YL
            OUT SPH,YH

;===========================================================================================
; Begin: Test ATOF.
;===========================================================================================
;            LDI ZL,LOW(NUMPRG << 1)         ; From here, in the program memory, we will read the numeric string.
;            LDI ZH,HIGH(NUMPRG << 1)        ;
;            LDI XL,LOW(NUMSTR)              ; Here, in SRAM, we will write the read string.
;            LDI XH,HIGH(NUMSTR)             ;
;READNUM:    LPM R0,Z+                       ; Read a byte from program memory.
;            ST X+,R0                        ; Write it to SRAM at the STR pointer.
;            AND R0,R0                       ; Reached NUL?
;            BRNE READNUM                    ; No, continue.
;===========================================================================================
; End: Test ATOF.
;===========================================================================================

            LDI ZL,LOW(FLOATERR)            ; Store in Z the address of the exception handler
            LDI ZH,HIGH(FLOATERR)           ; for the Float32AVR library.
            
MAIN:       

;===========================================================================================
; Begin: Division examples.
;===========================================================================================
            ;
            ; Case 1.
;            LDI R16,0x00                    ; A=1.0f.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x3F

;            LDI R20,0xFF                    ; B=1.99999988079071044921875f.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x3F

            ;
            ; Case 2.
;            LDI R16,0x20                    ; A=1.688541412353515625f.
;            LDI R17,0x22
;            LDI R18,0xD8
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=1.00885009765625f.
;            LDI R21,0x22
;            LDI R22,0x81
;            LDI R23,0x3F

            ;
            ; Case 3.
;            LDI R16,0x00                    ; A=1.3125f.
;            LDI R17,0x00
;            LDI R18,0xA8
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=1.75f.
;            LDI R21,0x00
;            LDI R22,0xE0
;            LDI R23,0x3F

            ;
            ; Case 4.
;            LDI R16,0x00                    ; A=1.6875f.
;            LDI R17,0x00
;            LDI R18,0xD8
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=1.5f.
;            LDI R21,0x00
;            LDI R22,0xC0
;            LDI R23,0x3F

            ;
            ; Case 5.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x3F

;            LDI R20,0xFF                    ; B=A.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x3F

            ;
            ; Case 6.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=1.0f.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0x3F

            ;
            ; Case 7.
;            LDI R16,0x20                    ; A=1.688541412353515625f * 2^97.
;            LDI R17,0x22
;            LDI R18,0x58
;            LDI R19,0x70

;            LDI R20,0x00                    ; B=1.00885009765625f * 2^-95.
;            LDI R21,0x22
;            LDI R22,0x01
;            LDI R23,0x10

            ;
            ; Case 8.
;            LDI R16,0x20                    ; A=1.688541412353515625f * 2^-116.
;            LDI R17,0x22
;            LDI R18,0xD8
;            LDI R19,0x05

;            LDI R20,0x00                    ; B=1.00885009765625f * 2^20.
;            LDI R21,0x22
;            LDI R22,0x81
;            LDI R23,0x49

            ;
            ; Case 9.
;            LDI R16,0x00                    ; A=1.0f * 2^-96.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x0F

;            LDI R20,0xFF                    ; B=1.99999988079071044921875f * 2^30.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x4E

            ;
            ; Case 10.
;            LDI R16,0x00                    ; A=1.0f * 2^20.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x49

;            LDI R20,0xFF                    ; B=1.99999988079071044921875f * 2^-108.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x09

            ;
            ; Case 11.
;            LDI R16,0x20                    ; A=1.688541412353515625f * 2^3.
;            LDI R17,0x22
;            LDI R18,0x58
;            LDI R19,0x41

;            LDI R20,0x00                    ; B=1.00885009765625f * 2^106.
;            LDI R21,0x22
;            LDI R22,0x81
;            LDI R23,0x74

            ;
            ; Case 12.
;            LDI R16,0x00                    ; A=1.0f * 2^3.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x41

;            LDI R20,0xFF                    ; B=1.99999988079071044921875f * 2^106
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x74

            ;
            ; Case 13.
;            LDI R16,0x00                    ; A=1.0f * 2^20.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x49

;            LDI R20,0xFF                    ; B=1.99999988079071044921875f * 2^109.
;            LDI R21,0xFF
;            LDI R22,0x7F
;            LDI R23,0x09

            ;
            ; Case 14.
;            LDI R16,0x00                    ; A=1.0f * 2^-115.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x06

;            LDI R20,0xFF                    ; B=1.99999988079071044921875f * 2^12.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x45

            ;
            ; Case 15.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f * 2^-100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x0D

;            LDI R20,0x00                    ; B=1.0f * 2^27.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x4D

            ;
            ; Both operands are negative.
            ; The result is positive.
;            LDI R16,0x00                    ; A=-1.0f * 2^20.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0xC9

;            LDI R20,0xFF                    ; B=-1.99999988079071044921875f * 2^-108.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x89

            ;
            ; The first operand is negative.
            ; The second operand is positive.
            ; The result is negative.
;            LDI R16,0x00                    ; A=-1.0f * 2^20.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0xC9

;            LDI R20,0xFF                    ; B=1.99999988079071044921875f * 2^-108.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x09

            ;
            ; The first operand is positive.
            ; The second operand is negative.
            ; The result is negative.
;            LDI R16,0x00                    ; A=1.0f * 2^20.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x49

;            LDI R20,0xFF                    ; B=-1.99999988079071044921875f * 2^-108.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x89

            ;
            ; The dividend is zero.
            ; The result is zero.
;            LDI R16,0x00                    ; A=0.0f.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x00

;            LDI R20,0xFF                    ; B=-1.99999988079071044921875f * 2^-108.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x89

            ;
            ; The divisor is zero.
            ; Exception.
;            LDI R16,0x00                    ; A=1.0f * 2^20.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x49

;            LDI R20,0x00                    ; B=0.0f.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x00

            ;
            ; Both operands are zero.
            ; Exception.
;            LDI R16,0x00                    ; A=0.0f.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x00

;            LDI R20,0x00                    ; B=0.0f.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x00

            ;
            ; Additional example 1.
            ; The example was discovered during testing of the FTOA.
            ;
            ; NOTE: Additional examples have no equivalents in desktop tests.
            ; These are isolated cases that occur and are verified on the spot.
;            LDI R16,0x02                    ; A=1.0000002384185791015625f.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=10.0f.
;            LDI R21,0x00
;            LDI R22,0x20
;            LDI R23,0x41
;===========================================================================================
; End: Division examples.
;===========================================================================================

;===========================================================================================
; Begin: Multiplication examples.
;===========================================================================================
            ;
            ; Case 1.
;            LDI R16,0x00                    ; A=1.875f.
;            LDI R17,0x00
;            LDI R18,0xF0
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=1.5f.
;            LDI R21,0x00
;            LDI R22,0xC0
;            LDI R23,0x3F

            ;
            ; Case 2.
;            LDI R16,0x00                    ; A=1.25f.
;            LDI R17,0x00
;            LDI R18,0xA0
;            LDI R19,0x3F

;            LDI R20,0xCE                    ; B=1.6000001430511474609375f.
;            LDI R21,0xCC
;            LDI R22,0xCC
;            LDI R23,0x3F

            ;
            ; Case 3.
;            LDI R16,0x00                    ; A=1.5f.
;            LDI R17,0x00
;            LDI R18,0xC0
;            LDI R19,0x3F

;            LDI R20,0xAB                    ; B=1.33333337306976318359375f.
;            LDI R21,0xAA
;            LDI R22,0xAA
;            LDI R23,0x3F

            ;
            ; Case 4.
;            LDI R16,0xFA                    ; A=1.9999992847442626953125f.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=1.5f.
;            LDI R21,0x00
;            LDI R22,0xC0
;            LDI R23,0x3F

            ;
            ; Case 5.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=1.5f.
;            LDI R21,0x00
;            LDI R22,0xC0
;            LDI R23,0x3F

            ;
            ; Case 6.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x3F

;            LDI R20,0x01                    ; B=1.00000011920928955078125f.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0x3F

            ;
            ; Case 7.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x71

;            LDI R20,0x00                    ; B=1.5f * 2^27.
;            LDI R21,0x00
;            LDI R22,0x40
;            LDI R23,0x4D

            ;
            ; Case 8.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x71

;            LDI R20,0x00                    ; B=1.5f * 2^26.
;            LDI R21,0x00
;            LDI R22,0xC0
;            LDI R23,0x4C

            ;
            ; Case 9.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x71

;            LDI R20,0x00                    ; B=1.5f * 2^28.
;            LDI R21,0x00
;            LDI R22,0xC0
;            LDI R23,0x4D

            ;
            ; Case 10.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^-100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x0D

;            LDI R20,0x00                    ; B=1.5f * 2^-27.
;            LDI R21,0x00
;            LDI R22,0x40
;            LDI R23,0x32

            ;
            ; Case 11.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^-100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x0D

;            LDI R20,0x00                    ; B=1.5f * 2^-28.
;            LDI R21,0x00
;            LDI R22,0xC0
;            LDI R23,0x31

            ;
            ; Case 12.
;            LDI R16,0x00                    ; A=1.25f * 2^100.
;            LDI R17,0x00
;            LDI R18,0xA0
;            LDI R19,0x71

;            LDI R20,0xAB                    ; B=1.33333337306976318359375f * 2^27.
;            LDI R21,0xAA
;            LDI R22,0x2A
;            LDI R23,0x4D

            ;
            ; Case 13.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x71

;            LDI R20,0x01                    ; B=1.00000011920928955078125f * 2^28.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0x4D

            ;
            ; Case 14.
;            LDI R16,0x00                    ; A=1.25f * 2^-126.
;            LDI R17,0x00
;            LDI R18,0xA0
;            LDI R19,0x00

;            LDI R20,0xAB                    ; B=1.33333337306976318359375f * 2^-25.
;            LDI R21,0xAA
;            LDI R22,0x2A
;            LDI R23,0x33            

            ;
            ; Case 15.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x71

;            LDI R20,0x01                    ; B=1.00000011920928955078125f * 2^27.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x4D

            ;
            ; Case 16.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x71

;            LDI R20,0x01                    ; B=1.00000011920928955078125f * 2^26.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0x4C

            ;
            ; Case 17.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^-100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x0D

;            LDI R20,0x01                    ; B=1.00000011920928955078125f * 2^-27.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x32

            ;
            ; Case 18.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^-100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x0D

;            LDI R20,0x01                    ; B=1.00000011920928955078125f * 2^-30.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0x30

            ;
            ; Case 19.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875fF * 2^-126.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x00

;            LDI R20,0x00                    ; B=1.0f * 2^-1.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x3F

            ;
            ; The first operand is zero.
            ; The result is zero.
;            LDI R16,0x00                    ; A=0.0f.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x00

;            LDI R20,0x01                    ; B=1.00000011920928955078125f * 2^26.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0x4C

            ;
            ; The second operand is zero.
            ; The result is zero.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x71

;            LDI R20,0x00                    ; B=0.0f.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x00

            ;
            ; Both operands are negative.
            ; The result is positive.
;            LDI R16,0xFE                    ; A=-1.9999997615814208984375f * 2^100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0xF1

;            LDI R20,0x01                    ; B=-1.00000011920928955078125f * 2^26.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0xCC

            ;
            ; The first operand is negative.
            ; The second operand is positive.
            ; The result is negative.
;            LDI R16,0xFE                    ; A=-1.9999997615814208984375f * 2^100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0xF1

;            LDI R20,0x01                    ; B=1.00000011920928955078125f * 2^26.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0x4C

            ;
            ; The first operand is positive.
            ; The second operand is negative.
            ; The result is negative.
;            LDI R16,0xFE                    ; A=1.9999997615814208984375f * 2^100.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x71

;            LDI R20,0x01                    ; B=-1.00000011920928955078125f * 2^26.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0xCC

            ;
            ; Example 20.
            ; BUGFIX: Overflow in the rounding branch.
;            LDI R16,0xF9                    ; A=10^10.
;            LDI R17,0x02
;            LDI R18,0x15
;            LDI R19,0x50

;            LDI R20,0x00                    ; B=10.
;            LDI R21,0x00
;            LDI R22,0x20
;            LDI R23,0x41
;===========================================================================================
; End: Multiplication examples.
;===========================================================================================

;===========================================================================================
; Begin: Examples for FADD32.
;===========================================================================================
            ;
            ; Case 1.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f * 2^127.
;            LDI R17,0xFF
;            LDI R18,0x7F
;            LDI R19,0x7F

;            LDI R20,0xFF                    ; B=A.
;            LDI R21,0xFF
;            LDI R22,0x7F
;            LDI R23,0x7F

            ;
            ; Case 2.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f * 2^-126.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x00

;            LDI R20,0xFF                    ; B=A.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x00

            ;
            ; Case 3.
;            LDI R16,0x00                    ; A=1.0f * 2^127.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x7F

;            LDI R20,0x03                    ; B=1.00000035762786865234375f * 2^127.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x7F

            ;
            ; Case 4.
;            LDI R16,0x00                    ; A=1.0f * 2^-126.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x00

;            LDI R20,0x03                    ; B=1.00000035762786865234375f * 2^-126.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0x00

            ;
            ; Case 5.
;            LDI R16,0x00                    ; A=1.0f * 2^127.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x7F

;            LDI R20,0x01                    ; B=1.00000011920928955078125f * 2^127.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x7F

            ;
            ; Case 6.
;            LDI R16,0x00                    ; A=1.0f * 2^-126.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x00

;            LDI R20,0x01                    ; B=1.00000011920928955078125f * 2^-126.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0x00

            ;
            ; Case 7.
;            LDI R16,0x00                    ; A=1.0f * 2^127.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x7F

;            LDI R20,0xFE                    ; B=1.9999997615814208984375f * 2^127.
;            LDI R21,0xFF
;            LDI R22,0x7F
;            LDI R23,0x7F

            ;
            ; Case 8.
;            LDI R16,0x00                    ; A=1.0f * 2^-126.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x00

;            LDI R20,0xFE                    ; B=1.9999997615814208984375f * 2^-126.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x00

            ;
            ; Case 9.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f * 2^127.
;            LDI R17,0xFF
;            LDI R18,0x7F
;            LDI R19,0x7F

;            LDI R20,0xE9                    ; B=1.99993622303009033203125f * 2^118.
;            LDI R21,0xFD
;            LDI R22,0xFF
;            LDI R23,0x7A

            ;
            ; Case 10.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f * 2^-117.
;            LDI R17,0xFF
;            LDI R18,0x7F
;            LDI R19,0x05

;            LDI R20,0xE9                    ; B=1.99993622303009033203125f * 2^-126.
;            LDI R21,0xFD
;            LDI R22,0xFF
;            LDI R23,0x00

            ;
            ; Case 11.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f * 2^127.
;            LDI R17,0xFF
;            LDI R18,0x7F
;            LDI R19,0x7F

;            LDI R20,0xE9                    ; B=1.99999725818634033203125f * 2^118.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x7A

            ;
            ; Case 12.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f * 2^-117.
;            LDI R17,0xFF
;            LDI R18,0x7F
;            LDI R19,0x05

;            LDI R20,0xED                    ; B=1.99999773502349853515625f * 2^-126.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x00

            ;
            ; Case 14.
;            LDI R16,0x00                    ; A=1.99609375f * 2^126.
;            LDI R17,0x80
;            LDI R18,0xFF
;            LDI R19,0x7E

;            LDI R20,0xE9                    ; B=1.99999725818634033203125f * 2^117.
;            LDI R21,0xFF
;            LDI R22,0x7F
;            LDI R23,0x7A

            ;
            ; Case 15.
;            LDI R16,0x00                    ; A=1.99609375f * 2^127.
;            LDI R17,0x80
;            LDI R18,0x7F
;            LDI R19,0x7F

;            LDI R20,0xE9                    ; B=1.99993622303009033203125f * 2^118.
;            LDI R21,0xFD
;            LDI R22,0xFF
;            LDI R23,0x7A

            ;
            ; Case 16.
;            LDI R16,0x00                    ; A=1.99609375f * 2^127.
;            LDI R17,0x80
;            LDI R18,0x7F
;            LDI R19,0x7F

;            LDI R20,0xEB                    ; B=1.99996697902679443359375f * 2^118.
;            LDI R21,0xFE
;            LDI R22,0xFF
;            LDI R23,0x7A

            ;
            ; Case 26.
;            LDI R16,0x00                    ; A=1.99609375f * 2^100.
;            LDI R17,0x80
;            LDI R18,0xFF
;            LDI R19,0x71

;            LDI R20,0x00                    ; B=1.999969482421875f * 2^92.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x6D

            ;
            ; Case 36.
;            LDI R16,0x00                    ; A=1.9921875f * 2^100.
;            LDI R17,0x00
;            LDI R18,0xFF
;            LDI R19,0x71

;            LDI R20,0x80                    ; B=1.9999847412109375f * 2^92.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x6D

            ;
            ; Case 40.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f * 2^127.
;            LDI R17,0xFF
;            LDI R18,0x7F
;            LDI R19,0x7F

;            LDI R20,0xFF                    ; B=1.99999988079071044921875f * 2^96.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x6F

            ;
            ; Case 41.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f * 2^127.
;            LDI R17,0xFF
;            LDI R18,0x7F
;            LDI R19,0x7F

;            LDI R20,0xFF                    ; B=1.99999988079071044921875f * 2^-126.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0x00

            ;
            ; Case 42.
;            LDI R16,0xBF                    ; A=-1.01158893108367919921875f.
;            LDI R17,0x7B
;            LDI R18,0x81
;            LDI R19,0xBF

;            LDI R20,0xFF                    ; B=-0.00006100535028963349759578704833984375f.
;            LDI R21,0xDF
;            LDI R22,0x7F
;            LDI R23,0xB8
;===========================================================================================
; End: Examples for FADD32.
;===========================================================================================

;===========================================================================================
; Begin: Examples for FADD32. The second operand is negative.
;===========================================================================================
            ;
            ; Case 0.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x3F

;            LDI R20,0xFF                    ; B=-1.99999988079071044921875f.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0xBF
            
            ;
            ; Case 1.
;            LDI R16,0x01                    ; A=1.00000011920928955078125f * 2^-126.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x00

;            LDI R20,0x00                    ; B=-1.0f * 2^-126.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0x80

            ;
            ; Case 2.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f * 2^-125.
;            LDI R17,0xFF
;            LDI R18,0x7F
;            LDI R19,0x01

;            LDI R20,0x00                    ; B=-1.0f * 2^-125.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x81

            ;
            ; Case 4.
;            LDI R16,0x00                    ; A=1.0f * 2^-102.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x0C

;            LDI R20,0xFF                    ; B=-1.99999988079071044921875f * 2^-103.
;            LDI R21,0xFF
;            LDI R22,0x7F
;            LDI R23,0x8C

            ;
            ; Case 5.
;            LDI R16,0x02                    ; A=1.5000002384185791015625f.
;            LDI R17,0x00
;            LDI R18,0xC0
;            LDI R19,0x3F

;            LDI R20,0x01                    ; B=-1.00000011920928955078125f * 2^-1.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0xBF

            ;
            ; Case 6.
;            LDI R16,0x01                    ; A=1.50000011920928955078125f.
;            LDI R17,0x00
;            LDI R18,0xC0
;            LDI R19,0x3F

;            LDI R20,0x01                    ; B=-1.00000011920928955078125f * 2^-1.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0xBF

            ;
            ; Case 8.
;            LDI R16,0x00                    ; A=1.0f * 2^127.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x7F

;            LDI R20,0x01                    ; B=-1.93750011920928955078125f * 2^101.
;            LDI R21,0x00
;            LDI R22,0x78
;            LDI R23,0xF2

            ;
            ; Case 10.
;            LDI R16,0x00                    ; A=1.0f * 2^-102.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x0C

;            LDI R20,0x01                    ; B=-1.48437511920928955078125f * 2^-126.
;            LDI R21,0x00
;            LDI R22,0xBE
;            LDI R23,0x80

            ;
            ; Case 12.
;            LDI R16,0x00                    ; A=1.0f * 2^-101.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x0D

;            LDI R20,0x01                    ; B=-1.48437511920928955078125f * 2^-126.
;            LDI R21,0x00
;            LDI R22,0xBE
;            LDI R23,0x80

            ;
            ; Case 20.
;            LDI R16,0x00                    ; A=1.0f.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=-1.0f * 2^-25.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0xB3

            ;
            ; Case 33.
;            LDI R16,0x00                    ; A=1.5f.
;            LDI R17,0x00
;            LDI R18,0xC0
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=-1.0f * 2^-31.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0xB0

            ;
            ; Case 34.
;            LDI R16,0x00                    ; A=1.0f.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=-1.0f * 2^-32.
;            LDI R21,0x00
;            LDI R22,0x80
;            LDI R23,0xAF

            ;
            ; Case 36.
;            LDI R16,0x00                    ; A=-10.0f.
;            LDI R17,0x00
;            LDI R18,0x20
;            LDI R19,0xC1

;            LDI R20,0x00                    ; B=5.0f.
;            LDI R21,0x00
;            LDI R22,0xA0
;            LDI R23,0x40

            ;
            ; |A| < |B| => swap.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f * 2^5.
;            LDI R17,0xFF
;            LDI R18,0x7F
;            LDI R19,0x42

;            LDI R20,0x00                    ; B=-1.5f * 2^10.
;            LDI R21,0x00
;            LDI R22,0xC0
;            LDI R23,0xC4

            ;
            ; Both operand are zero.
            ; The result is zero.
;            LDI R16,0x00                    ; A=0.0f.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x00

;            LDI R20,0x00                    ; B=0.0f.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x00

            ;
            ; Only the first operand is zero.
            ; The result is the second operand.
;            LDI R16,0x00                    ; A=0.0f.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x00

;            LDI R20,0xFF                    ; B=-1.99999988079071044921875f.
;            LDI R21,0xFF
;            LDI R22,0xFF
;            LDI R23,0xBF

            ;
            ; Only the second operand is zero.
            ; The result is the first operand.
;            LDI R16,0xFF                    ; A=1.99999988079071044921875f.
;            LDI R17,0xFF
;            LDI R18,0xFF
;            LDI R19,0x3F

;            LDI R20,0x00                    ; B=0.0f.
;            LDI R21,0x00
;            LDI R22,0x00
;            LDI R23,0x00
;===========================================================================================
; End: Examples for FADD32. The second operand is negative.
;===========================================================================================

;===========================================================================================
; Begin: Examples for FSUB32.
;===========================================================================================
            ;
            ; Case 1. Both operands are negative.
            ; NOTE: The example was added due to a detected issue during calculations.
;            LDI R16,0x00                    ; A=-12.0f.
;            LDI R17,0x00
;            LDI R18,0x40
;            LDI R19,0xC1

;            LDI R20,0x00                    ; B=-14.0f.
;            LDI R21,0x00
;            LDI R22,0x60
;            LDI R23,0xC1

            ;
            ; Case 2. The first operand is negative, the second operand is positive.
            ; NOTE: The example was added due to a detected issue during calculations.
;            LDI R16,0x00                    ; A=-12.0f.
;            LDI R17,0x00
;            LDI R18,0x40
;            LDI R19,0xC1

;            LDI R20,0x00                    ; B=14.0f.
;            LDI R21,0x00
;            LDI R22,0x60
;            LDI R23,0x41
;===========================================================================================
; End: Examples for FSUB32.
;===========================================================================================

;===========================================================================================
; Begin: Arithmetic test.
;===========================================================================================
;            STD Y+1,R16                     ; Write the input operands in memory.
;            STD Y+2,R17                     ; In the test code, this is unnecessary because we immediately read from memory
;            STD Y+3,R18                     ; and pass the operands to a subroutine.
;            STD Y+4,R19                     ; This is done solely for the sake of demonstrating the complete usage of subroutines.

;            STD Y+5,R20
;            STD Y+6,R21
;            STD Y+7,R22
;            STD Y+8,R23

;            LDD R8,Y+1                      ; Pass A and B to a subroutine.
;            LDD R9,Y+2
;            LDD R10,Y+3
;            LDD R11,Y+4

;            LDD R12,Y+5
;            LDD R13,Y+6
;            LDD R14,Y+7
;            LDD R15,Y+8

;            CALL FDIV32
;            CALL FMUL32
;            CALL FADD32
;            CALL FSUB32

;            STD Y+9,R8                      ; Write the result in memory.
;            STD Y+10,R9
;            STD Y+11,R10
;            STD Y+12,R11
;===========================================================================================
; End: Arithmetic test.
;===========================================================================================

;===========================================================================================
; Begin: Examples for FTOI.
;===========================================================================================
            ;
            ; Example 1.
;            LDI R16,0x00                    ; A=1.0f.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x3F

            ;
            ; Example 2.
;            LDI R16,0xFF                    ; A=9.99999904632568359375f.
;            LDI R17,0xFF
;            LDI R18,0x1F
;            LDI R19,0x41
;===========================================================================================
; End: Examples for FTOI.
;===========================================================================================

;===========================================================================================
; Begin: Test FTOI.
;===========================================================================================
;            STD Y+1,R16
;            STD Y+2,R17
;            STD Y+3,R18
;            STD Y+4,R19

;            LDD R8,Y+1                      ; Pass the number NUM.
;            LDD R9,Y+2
;            LDD R10,Y+3
;            LDD R11,Y+4

;            CALL FTOI
;===========================================================================================
; End: Test FTOI.
;===========================================================================================

;===========================================================================================
; Begin: Examples for ITOF.
;===========================================================================================
            ;
            ; Example 1.
;            LDI R16,1
;            MOV R8,R16

            ;
            ; Example 2.
;            LDI R16,9
;            MOV R8,R16

            ;
            ; Example 3.
;            LDI R16,23
;            MOV R8,R16

            ;
            ; Example 4.
;            LDI R16,137
;            MOV R8,R16

            ;
            ; Example 5.
;            LDI R16,255
;            MOV R8,R16

            ;
            ; Example 6.
;            LDI R16,0
;            MOV R8,R16
;===========================================================================================
; End: Examples for ITOF.
;===========================================================================================

;===========================================================================================
; Begin: Test ITOF.
;===========================================================================================
;            CALL ITOF
;===========================================================================================
; End: Test ITOF.
;===========================================================================================

;===========================================================================================
; Begin: Examples for FTOAN.
;===========================================================================================
            ;
            ; Example 1.
;            LDI R16,0x00                    ; A=0.0f.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x00

            ;
            ; Example 2.
;            LDI R16,0x00                    ; A=1.0f.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x3F

            ;
            ; Example 3.
;            LDI R16,0xFF                    ; A=9.99999904632568359375f.
;            LDI R17,0xFF
;            LDI R18,0x1F
;            LDI R19,0x41

            ;
            ; Example 4.
;            LDI R16,0xC4                    ; A=-4.5832233428955078125f.
;            LDI R17,0xA9
;            LDI R18,0x92
;            LDI R19,0xC0
            
;            LDI R20,23                      ; Precision.
;            MOV R12,R20                     ;
;===========================================================================================
; End: Examples for FTOAN.
;===========================================================================================

;===========================================================================================
; Begin: Test FTOAN.
;===========================================================================================
;            STD Y+1,R16
;            STD Y+2,R17
;            STD Y+3,R18
;            STD Y+4,R19

;            LDD R8,Y+1                      ; Pass the number NUM.
;            LDD R9,Y+2
;            LDD R10,Y+3
;            LDD R11,Y+4

;            LDI XL,LOW(NUMSTR)              ; Pass the pointer to the string NUMSTR.
;            LDI XH,HIGH(NUMSTR)

;            CALL FTOAN
;===========================================================================================
; End: Test FTOAN.
;===========================================================================================

;===========================================================================================
; Begin: Test ATOF.
;===========================================================================================
;            LDI XL,LOW(NUMSTR)              ; Pass the pointer to the numeric string.
;            LDI XH,HIGH(NUMSTR)

;            CALL ATOF

;            STD Y+9,R8                      ; Write the result in memory.
;            STD Y+10,R9
;            STD Y+11,R10
;            STD Y+12,R11
;===========================================================================================
; End: Test ATOF.
;===========================================================================================

;===========================================================================================
; Begin: Examples for FTOAE.
;===========================================================================================
            ;
            ; Example 1.
            LDI R16,0xFF                    ; A=340282346638528859811704183484516925440.0f.
            LDI R17,0xFF
            LDI R18,0x7F
            LDI R19,0x7F

            ;
            ; Example 2.
;            LDI R16,0x00                    ; A=-10.0f.
;            LDI R17,0x00
;            LDI R18,0x20
;            LDI R19,0xC1

            ;
            ; Example 3.
;            LDI R16,0xFF                    ; A=9.99999904632568359375.0f.
;            LDI R17,0xFF
;            LDI R18,0x1F
;            LDI R19,0x41

            ;
            ; Example 4.
;            LDI R16,0x00                    ; A=-1.0f.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0xBF

            ;
            ; Example 5.
;            LDI R16,0xFF                    ; A=0.999999940395355224609375f.
;            LDI R17,0xFF
;            LDI R18,0x7F
;            LDI R19,0x3F

            ;
            ; Example 6.
;            LDI R16,0x00                    ; A=-2^-126.
;            LDI R17,0x00
;            LDI R18,0x80
;            LDI R19,0x80

            ;
            ; Example 7.
;            LDI R16,0xC2                    ; A=10^37 (the value before mapping to float32).
;            LDI R17,0xBD
;            LDI R18,0xF0
;            LDI R19,0x7C

            ;
            ; Example 8.
;            LDI R16,0x19                    ; A=10^33 (the value before mapping to float32).
;            LDI R17,0x37
;            LDI R18,0x45
;            LDI R19,0x76

            ;
            ; Example 9.
;            LDI R16,0x27                    ; A=25307.576171875f.
;            LDI R17,0xB7
;            LDI R18,0xC5
;            LDI R19,0x46

            ;
            ; Example 10.
;            LDI R16,0xF2                    ; A=1.3023970127105712890625f * 2^-34.
;            LDI R17,0xB4
;            LDI R18,0xA6
;            LDI R19,0x2E

            ;
            ; Example 11.
;            LDI R16,0x00                    ; A=0.0f.
;            LDI R17,0x00
;            LDI R18,0x00
;            LDI R19,0x00
            
            LDI R20,16                      ; MAXLEN.
            MOV R12,R20
;===========================================================================================
; End: Examples for FTOAE.
;===========================================================================================

;===========================================================================================
; Begin: Test FTOAE.
;===========================================================================================
            STD Y+1,R16
            STD Y+2,R17
            STD Y+3,R18
            STD Y+4,R19

            LDD R8,Y+1                      ; Pass the number NUM.
            LDD R9,Y+2
            LDD R10,Y+3
            LDD R11,Y+4

            LDI XL,LOW(NUMSTR)              ; Pass the pointer to the string NUMSTR.
            LDI XH,HIGH(NUMSTR)

            CALL FTOAE
;===========================================================================================
; End: Test FTOAE.
;===========================================================================================

END:        RJMP END

            ;
            ; Exception handler for floating-point operations:
            ; - Division by zero.
            ; - Overflow.
FLOATERR:   RJMP END

;===========================================================================================
; Begin: Examples for ATOF.
;===========================================================================================
            ; Example 0.
;NUMPRG:     .DB "0.000000000000000000000000000000000000009",0

            ; Example 1.
;NUMPRG:     .DB "0.00000000000000000000000000000000000001",0

            ; Example 2.
;NUMPRG:     .DB "0.00000000000000000000000000000000000002",0

            ; Example 3.
;NUMPRG:     .DB "0.340282429999999999999999999999999999999",0

            ; Example 4.
;NUMPRG:     .DB "3.40282429999999999999999999999999999999",0

            ; Example 5.
;NUMPRG:     .DB "340282429999999999.999999999999999999999",0

            ; Example 6.
;NUMPRG:     .DB "340282429999999999999999999999999999999",0

            ; Example 7.
;NUMPRG:     .DB "340282429999999999999999999999999999999.0",0

            ; Example 8.
;NUMPRG:     .DB "0.340282430000000000000000000000000000000",0

            ; Example 9.
;NUMPRG:     .DB "3.40282430000000000000000000000000000000",0

            ; Example 10.
;NUMPRG:     .DB "3402824300000000.00000000000000000000000",0

            ; Example 11.
;NUMPRG:     .DB "340282430000000000000000000000000000000",0

            ; Example 12.
;NUMPRG:     .DB "11111111111111111.11111111111111111111119999",0

            ; Example 13.
;NUMPRG:     .DB "297270070.293992768437644036421190501130",0

            ; Example 14.
;NUMPRG:     .DB "406.93306",0

            ; Example 15.
;NUMPRG:     .DB "70856.4138686531",0

            ; Example 16.
;NUMPRG:     .DB "0",0

            ; Example 17.
;NUMPRG:     .DB "0.00",0

            ; Example 18.
;NUMPRG:     .DB "-16.123",0

            ; Example 19.
;NUMPRG:     .DB "-0.0",0

            ;
            ; Example 1. Exception handling.
            ; Gives overflow in FMUL32. When processing integer part. When scaling NUM.
;NUMPRG:     .DB "3402824299999999999999999999999999999990",0

            ;
            ; Example 2. Exception handling.
            ; Gives overflow in FMUL32. When processing fractional part. When scaling NUM.
;NUMPRG:     .DB "340282429999999999999999999999999999999.0",0

            ;
            ; Example 3. Exception handling.
            ; Gives overflow in FMUL32. When processing fractional part. When calculating OVERSCALE.
;NUMPRG:     .DB "0.340282429999999999999999999999999999999",0
;===========================================================================================
; End: Examples for ATOF.
;===========================================================================================
