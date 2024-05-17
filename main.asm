            .INCLUDE <M328PDEF.INC>

            .EQU SP=RAMEND-4*3              ; СМЕЩАЕМ УКАЗАТЕЛЬ СТЕКА НА 12 БАЙТ ВВЕРХ.

            .DSEG
            .ORG SP+1                       ; РЕЗЕРВИРУЕМ ПОД СТЕКОМ 12 БАЙТ ДЛЯ ТРЕХ ПЕРЕМЕННЫХ ТИПА FLOAT32.
A:          .BYTE 4                         ; ДЕЛИМОЕ.
B:          .BYTE 4                         ; ДЕЛИТЕЛЬ.
C:          .BYTE 4                         ; ЧАСТНОЕ.

            .CSEG
            .ORG 0x00
            RJMP RESET
            
            .INCLUDE "FLOAT32.ASM"

RESET:      LDI YL,LOW(SP)
            LDI YH,HIGH(SP)
            OUT SPL,YL
            OUT SPH,YH

            LDI ZL,LOW(FLOATERR)            ; ЗАПИСЫВАЕМ В Z АДРЕС ОБРАБОТЧИКА ОШИБОК
            LDI ZH,HIGH(FLOATERR)           ; ДЛЯ БИБЛИОТЕКИ FLOAT32.
            
MAIN:       ;
            ; СЛУЧАЙ 1.         
            ;LDI R16,0x00                    ; A=1.0F.
            ;LDI R17,0x00
            ;LDI R18,0x80
            ;LDI R19,0x3F

            ;LDI R20,0xFF                    ; B=1.99999988079071044921875F.
            ;LDI R21,0xFF
            ;LDI R22,0xFF
            ;LDI R23,0x3F

            ;
            ; СЛУЧАЙ 2.         
            ;LDI R16,0x20                    ; A=1.688541412353515625F.
            ;LDI R17,0x22
            ;LDI R18,0xD8
            ;LDI R19,0x3F

            ;LDI R20,0x00                    ; B=1.00885009765625F.
            ;LDI R21,0x22
            ;LDI R22,0x81
            ;LDI R23,0x3F

            ;
            ; СЛУЧАЙ 3.         
            ;LDI R16,0x00                    ; A=1.3125F.
            ;LDI R17,0x00
            ;LDI R18,0xA8
            ;LDI R19,0x3F

            ;LDI R20,0x00                    ; B=1.75F.
            ;LDI R21,0x00
            ;LDI R22,0xE0
            ;LDI R23,0x3F

            ;
            ; СЛУЧАЙ 4.         
            ;LDI R16,0x00                    ; A=1.6875F.
            ;LDI R17,0x00
            ;LDI R18,0xD8
            ;LDI R19,0x3F

            ;LDI R20,0x00                    ; B=1.5F.
            ;LDI R21,0x00
            ;LDI R22,0xC0
            ;LDI R23,0x3F

            ;
            ; СЛУЧАЙ 5.         
            ;LDI R16,0xFF                    ; A=(2^24 - 1) * 2^-23.
            ;LDI R17,0xFF
            ;LDI R18,0xFF
            ;LDI R19,0x3F

            ;LDI R20,0xFF                    ; B=A.
            ;LDI R21,0xFF
            ;LDI R22,0xFF
            ;LDI R23,0x3F

            ;
            ; СЛУЧАЙ 6.         
            ;LDI R16,0xFF                    ; A=(2^24 - 1) * 2^-23.
            ;LDI R17,0xFF
            ;LDI R18,0xFF
            ;LDI R19,0x3F

            ;LDI R20,0x00                    ; B=1.0F.
            ;LDI R21,0x00
            ;LDI R22,0x80
            ;LDI R23,0x3F

            ;
            ; СЛУЧАЙ 7.
            ;LDI R16,0x20                    ; A=1.688541412353515625F * 2^97.
            ;LDI R17,0x22
            ;LDI R18,0x58
            ;LDI R19,0x70

            ;LDI R20,0x00                    ; B=1.00885009765625F * 2^-95.
            ;LDI R21,0x22
            ;LDI R22,0x01
            ;LDI R23,0x10

            ;
            ; СЛУЧАЙ 8.
            ;LDI R16,0x20                    ; A=1.688541412353515625F * 2^-116.
            ;LDI R17,0x22
            ;LDI R18,0xD8
            ;LDI R19,0x05

            ;LDI R20,0x00                    ; B=1.00885009765625F * 2^20.
            ;LDI R21,0x22
            ;LDI R22,0x81
            ;LDI R23,0x49

            ;
            ; СЛУЧАЙ 9.
            ;LDI R16,0x00                    ; A=1.0F * 2^-96.
            ;LDI R17,0x00
            ;LDI R18,0x80
            ;LDI R19,0x0F

            ;LDI R20,0xFF                    ; B=(2^24 - 1) * 2^-23 * 2^30.
            ;LDI R21,0xFF
            ;LDI R22,0xFF
            ;LDI R23,0x4E

            ;
            ; СЛУЧАЙ 10.
            ;LDI R16,0x00                    ; A=1.0F * 2^20.
            ;LDI R17,0x00
            ;LDI R18,0x80
            ;LDI R19,0x49

            ;LDI R20,0xFF                    ; B=(2^24 - 1) * 2^-23 * 2^-108.
            ;LDI R21,0xFF
            ;LDI R22,0xFF
            ;LDI R23,0x09

            ;
            ; ОБА ОПЕРАНДА ОТРИЦАТЕЛЬНЫЕ.
            ; РЕЗУЛЬТАТ ПОЛОЖИТЕЛЬНЫЙ.
            ;LDI R16,0x00                    ; A=-1.0F * 2^20.
            ;LDI R17,0x00
            ;LDI R18,0x80
            ;LDI R19,0xC9

            ;LDI R20,0xFF                    ; B=-(2^24 - 1) * 2^-23 * 2^-108.
            ;LDI R21,0xFF
            ;LDI R22,0xFF
            ;LDI R23,0x89

            ;
            ; ПЕРВЫЙ ОПЕРАНД ОТРИЦАТЕЛЬНЫЙ.
            ; ВТОРОЙ ОПЕРАНД ПОЛОЖИТЕЛЬНЫЙ.
            ; РЕЗУЛЬТАТ ОТРИЦАТЕЛЬНЫЙ.
            ;LDI R16,0x00                    ; A=-1.0F * 2^20.
            ;LDI R17,0x00
            ;LDI R18,0x80
            ;LDI R19,0xC9

            ;LDI R20,0xFF                    ; B=(2^24 - 1) * 2^-23 * 2^-108.
            ;LDI R21,0xFF
            ;LDI R22,0xFF
            ;LDI R23,0x09

            ;
            ; ПЕРВЫЙ ОПЕРАНД ПОЛОЖИТЕЛЬНЫЙ.
            ; ВТОРОЙ ОПЕРАНД ОТРИЦАТЕЛЬНЫЙ.
            ; РЕЗУЛЬТАТ ОТРИЦАТЕЛЬНЫЙ.
            LDI R16,0x00                    ; A=1.0F * 2^20.
            LDI R17,0x00
            LDI R18,0x80
            LDI R19,0x49

            LDI R20,0xFF                    ; B=-(2^24 - 1) * 2^-23 * 2^-108.
            LDI R21,0xFF
            LDI R22,0xFF
            LDI R23,0x89

            STD Y+1,R16
            STD Y+2,R17
            STD Y+3,R18
            STD Y+4,R19

            STD Y+5,R20
            STD Y+6,R21
            STD Y+7,R22
            STD Y+8,R23

            LDD R8,Y+1                      ; ПЕРЕДАЕМ A И B В ПОДПРОГРАММУ ДЕЛЕНИЯ.
            LDD R9,Y+2
            LDD R10,Y+3
            LDD R11,Y+4

            LDD R12,Y+5
            LDD R13,Y+6
            LDD R14,Y+7
            LDD R15,Y+8

            CALL FDIV

            STD Y+9,R8                      ; ЗАПИСЫВАЕМ ЧАСТНОЕ В ПАМЯТЬ.
            STD Y+10,R9
            STD Y+11,R10
            STD Y+12,R11

END:        RJMP END

            ;
            ; ОБРАБОТЧИК ОШИБОК, ВОЗНИКАЮЩИХ ПРИ ВЫЧИСЛЕНИЯХ С ПЛАВАЮЩЕЙ ТОЧКОЙ:
            ; - ДЕЛЕНИЕ НА НОЛЬ.
            ; - ПЕРЕПОЛНЕНИЕ.
FLOATERR:   RJMP END