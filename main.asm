            .INCLUDE <M328PDEF.INC>

            .EQU SP=RAMEND-4*3              ; СМЕЩАЕМ УКАЗАТЕЛЬ СТЕКА НА 12 БАЙТ ВВЕРХ.

            .DSEG
            .ORG SP+1                       ; РЕЗЕРВИРУЕМ ПОД СТЕКОМ 12 БАЙТ ДЛЯ ТРЕХ ПЕРЕМЕННЫХ ТИПА FLOAT32.
A:          .BYTE 4                         ; ДЕЛИМОЕ.
B:          .BYTE 4                         ; ДЕЛИТЕЛЬ.
C:          .BYTE 4                         ; ЧАСТНОЕ.

            .CSEG
            .ORG 0x00
            JMP RESET
            
            .INCLUDE "FLOAT32.ASM"

RESET:      LDI YL,LOW(SP)
            LDI YH,HIGH(SP)
            OUT SPL,YL
            OUT SPH,YH
            
MAIN:       LDI R16,0x00                   ; A=1.0F.
            LDI R17,0x00
            LDI R18,0x80
            LDI R19,0x3F
            STD Y+1,R16
            STD Y+2,R17
            STD Y+3,R18
            STD Y+4,R19

            LDI R16,0xFF                   ; B=1.99999988079071044921875F.
            LDI R17,0xFF
            LDI R18,0xFF
            LDI R19,0x3F
            STD Y+5,R16
            STD Y+6,R17
            STD Y+7,R18
            STD Y+8,R19

            LDD R0,Y+1                     ; ПЕРЕДАЕМ A И B В ПОДПРОГРАММУ ДЕЛЕНИЯ.
            LDD R1,Y+2
            LDD R2,Y+3
            LDD R3,Y+4

            LDD R4,Y+5
            LDD R5,Y+6
            LDD R6,Y+7
            LDD R7,Y+8

            CALL FDIV

            STD Y+9,R0                     ; ЗАПИСЫВАЕМ ЧАСТНОЕ В ПАМЯТЬ.
            STD Y+10,R1
            STD Y+11,R2
            STD Y+12,R3

END:        JMP END