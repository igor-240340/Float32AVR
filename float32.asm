;
; FLOAT32AVR
; БИБЛИОТЕКА ПОДПРОГРАММ ДЛЯ РАБОТЫ С ЧИСЛАМИ В ФОРМАТЕ ПЛАВАЮЩЕЙ ТОЧКИ ОДИНАРНОЙ ТОЧНОСТИ.
;
; Copyright (c) 2024 IGOR VOYTENKO <igor.240340@gmail.com>
;
; ЧАСТИЧНАЯ СОВМЕСТИМОСТЬ С IEEE 754:
; - НЕ РЕАЛИЗОВАНЫ СПЕЦ. ЗНАЧЕНИЯ: INF, NAN.
; - НЕ РЕАЛИЗОВАНЫ ДЕНОРМАЛИЗОВАННЫЕ ЧИСЛА.
; - РЕАЛИЗОВАН ТОЛЬКО ОДИН РЕЖИМ ОКРУГЛЕНИЯ: К БЛИЖАЙШЕМУ/К ЧЕТНОМУ.
; - РЕАЛИЗОВАН ТОЛЬКО ПОЛОЖИТЕЛЬНЫЙ НОЛЬ.
;
; ТЕМ НЕ МЕНЕЕ, ГРАНИЧНЫЕ ЗНАЧЕНИЯ ЭКСПОНЕНТЫ -127 И 128 (0 И 255 В КОДЕ СО СМЕЩЕНИЕМ)
; ОСТАЮТСЯ ЗАРЕЗЕРВИРОВАННЫМИ ДЛЯ СПЕЦ. ЗНАЧЕНИЙ И ДЕНОРМАЛИЗОВАННЫХ ЧИСЕЛ
; ЧТОБЫ МОЖНО БЫЛО ДОВЕСТИ ДО ПОЛНОЙ СОВМЕСТИМОСТИ В БУДУЩЕМ
; А ТАКЖЕ ДЛЯ УДОБСТВА ТЕСТИРОВАНИЯ И СРАВНЕНИЯ С ЭТАЛОННОЙ IEEE 754 РЕАЛИЗАЦИЕЙ ПРЯМО СЕЙЧАС.
;
; ОБРАБОТКА ИСКЛЮЧИТЕЛЬНЫХ СИТУАЦИЙ.
; В СЛУЧАЕ ВОЗНИКНОВЕНИЯ ИСКЛЮЧИТЕЛЬНОЙ СИТУАЦИИ (ДЕЛЕНИЕ НА НОЛЬ, ПЕРЕПОЛНЕНИЕ)
; ПРОИСХОДИТ ПРЫЖОК НА АДРЕС, КОТОРЫЙ ДОЛЖЕН БЫТЬ ПРЕДВАРИТЕЛЬНО ЗАГРУЖЕН В Z-РЕГИСТР ПЕРЕД ВЫЗОВОМ ПОДПРОГРАММЫ.
            ;
            ; БАЙТЫ ИСХОДНОЙ МАНТИССЫ ДЕЛИМОГО,
            ; РАСШИРЕННЫЕ GUARD-БАЙТОМ ДЛЯ БЕЗОПАСНОГО СДВИГА ВЛЕВО.
            .DEF MANTA0=R8              
            .DEF MANTA1=R9              
            .DEF MANTA2=R10             
            .DEF MANTAG=R2              

            ;
            ; БАЙТЫ ИСХОДНОЙ МАНТИССЫ ДЕЛИТЕЛЯ,
            ; РАСШИРЕННЫЕ GUARD-БАЙТОМ ДЛЯ ФОРМИРОВАНИЯ ДОП. КОДА ОТРИЦАТЕЛЬНОЙ МАНТИССЫ.
            .DEF MANTB0=R12             
            .DEF MANTB1=R13             
            .DEF MANTB2=R14             
            .DEF MANTBG=R3              

            ;
            ; БАЙТЫ ДОП. КОДА ОТРИЦАТЕЛЬНОЙ МАНТИССЫ ДЕЛИТЕЛЯ.
            .DEF MANTB0NEG=R4
            .DEF MANTB1NEG=R5
            .DEF MANTB2NEG=R6
            .DEF MANTBGNEG=R7

            ;
            ; РАСШИРЕННЫЕ ЭКСПОНЕНТЫ.
            .DEF EXPA0=R11                  ; ПЕРВЫЙ ОПЕРАНД. 
            .DEF EXPA1=R20                  ;
            .DEF EXPR0=R11                  ; РЕЗУЛЬТАТ
            .DEF EXPR1=R20                  ;
            .DEF EXPB0=R15                  ; ВТОРОЙ ОПЕРАНД
            .DEF EXPB1=R21                  ;

            ;
            ; БАЙТЫ МАНТИССЫ ЧАСТНОГО.
            .DEF Q0=R22
            .DEF Q1=R23
            .DEF Q2=R24
            .DEF Q3=R25

            .EQU QDIGITS=24+2               ; КОЛИЧЕСТВО ЦИФР ЧАСТНОГО К ВЫЧИСЛЕНИЮ: 24 + R + G + S (S ОПРЕДЕЛЯЕТСЯ ВНЕ ЦИКЛА).

            .DEF STEPS=R17                  ; СЧЕТЧИК ЦИКЛА.

            .EQU RGSMASK=0b00000111         ; МАСКА ДЛЯ ИЗВЛЕЧЕНИЯ RGS-БИТОВ ПРИ ОКРУГЛЕНИИ.
            .DEF RGSBITS=R18                ; ДОПОЛНИТЕЛЬНЫЕ БИТЫ МАНТИССЫ ЧАСТНОГО + STICKY-БИТ ДЛЯ КОРРЕКТНОГО ОКРУГЛЕНИЯ.

            .DEF RSIGN=R0                   ; ЗНАК РЕЗУЛЬТАТА (ЧАСТНОЕ/ПРОИЗВЕДЕНИЕ/АЛГЕБРАИЧЕСКАЯ СУММА).

            ;
            ; МАНТИССА ПРОИЗВЕДЕНИЯ.
            .DEF MANTP0=R17
            .DEF MANTP1=R18
            .DEF MANTP2=R19
            .DEF MANTP3=R23
            .DEF MANTP4=R24
            .DEF MANTP5=R25
            .DEF GUARD=R7                  ; GUARD-РЕГИСТР ДЛЯ ВРЕМЕННОГО ХРАНЕНИЯ R-БИТА МАНТИССЫ ПРОИЗВЕДЕНИЯ.

            .DEF STATUS0=R5                ; РЕГИСТР СТАТУСА ПОСЛЕ ОПЕРАЦИИ НАД МЛАДШИМ БАЙТОМ.
            .DEF STATUS1=R6                ; РЕГИСТР СТАТУСА ПОСЛЕ ОПЕРАЦИИ НАД СТАРШИМ БАЙТОМ.
;
; ДЕЛИТ ДВА ЧИСЛА
; ПО СХЕМЕ С НЕПОДВИЖНЫМ ДЕЛИТЕЛЕМ БЕЗ ВОССТАНОВЛЕНИЯ ОСТАТКА.
;
; ДЕЛИМОЕ ОЖИДАЕТСЯ В РЕГИСТРАХ: R11, R10, R9, R8.
; ДЕЛИТЕЛЬ ОЖИДАЕТСЯ В РЕГИСТРАХ: R15, R14, R13, R12. 
; ЧАСТНОЕ ПОМЕЩАЕТСЯ НА МЕСТО ДЕЛИМОГО: R11, R10, R9, R8.
FDIV32:     ;
            ; ФИЛЬТРАЦИЯ ОПЕРАНДОВ.
            CLR R16                     ;
            OR R16,R8                   ;
            OR R16,R9                   ;
            OR R16,R10                  ;
            OR R16,R11                  ;
            IN R16,SREG                 ; 
            SBRC R16,SREG_Z             ; ДЕЛИМОЕ РАВНО НУЛЮ?
            RJMP SETZERO                ; ДА, ВОЗВРАЩАЕМ НОЛЬ.

            CLR R16                     ; НЕТ, ПРОВЕРЯЕМ ДЕЛИТЕЛЬ.
            OR R16,R12                  ;
            OR R16,R13                  ;
            OR R16,R14                  ;
            OR R16,R15                  ;
            IN R16,SREG                 ; 
            SBRC R16,SREG_Z             ; ДЕЛИТЕЛЬ РАВЕН НУЛЮ?
            IJMP                        ; ДА, ВЫБРАСЫВАЕМ ОШИБКУ.
            
            ;
            ; ОПРЕДЕЛЕНИЕ ЗНАКА ЧАСТНОГО.
            MOV RSIGN,R11               ; КОПИРУЕМ СТАРШИЙ БАЙТ ДЕЛИМОГО.
            MOV R1,R15                  ; КОПИРУЕМ СТАРШИЙ БАЙТ ДЕЛИТЕЛЯ.
            LDI R16,0b10000000          ; ЗАГРУЖАЕМ МАСКУ ЗНАКА.
            AND RSIGN,R16               ; ИЗВЛЕКАЕМ ЗНАК ДЕЛИМОГО.
            AND R1,R16                  ; ИЗВЛЕКАЕМ ЗНАК ДЕЛИТЕЛЯ.
            EOR RSIGN,R1                ; ОПРЕДЕЛЯЕМ ЗНАК ЧАСТНОГО.

            ;
            ; РАСПАКОВКА ДЕЛИМОГО.
            ROL R10                     ; MSB МАНТИССЫ ДЕЛИМОГО СОДЕРЖИТ LSB ЭКСПОНЕНТЫ. СДВИГАЕМ ЕГО В БИТ ПЕРЕНОСА.
            ROL R11                     ; ИЗБАВЛЯЕМСЯ ОТ ЗНАКА ДЕЛИМОГО И ВОССТАНАВЛИВАЕМ МЛАДШИЙ БИТ ЭКСПОНЕНТЫ.
            ROR R10                     ; ВОЗВРАЩАЕМ НА МЕСТО СТАРШИЙ БАЙТ МАНТИССЫ ДЕЛИМОГО.
            OR R10,R16                  ; ВОССТАНАВЛИВАЕМ СКРЫТУЮ ЕДИНИЦУ МАНТИССЫ.

            ;
            ; РАСПАКОВКА ДЕЛИТЕЛЯ.
            ROL R14                     ; ТО ЖЕ САМОЕ ДЛЯ ДЕЛИТЕЛЯ.
            ROL R15                     ; 
            ROR R14                     ; 
            OR R14,R16                  ;

            ;
            ; ВЫЧИСЛЕНИЕ ЭКСПОНЕНТЫ ЧАСТНОГО.
            CLR EXPA1
            CLR EXPB1
            
            COM EXPB0                   ; ФОРМИРУЕМ ДОП. КОД ЭКСПОНЕНТЫ ДЕЛИТЕЛЯ.
            COM EXPB1                   ;
            LDI R16,1                   ; 
            ADD EXPB0,R16               ; 
            LDI R16,0                   ;
            ADC EXPB1,R16               ;

            ADD EXPA0,EXPB0             ; EXPA=EXPA-EXPB.
            ADC EXPA1,EXPB1             ;
            LDI R16,127                 ; ВОССТАНАВЛИВАЕМ РЕЗУЛЬТАТ В КОДЕ СО СМЕЩЕНИЕМ.
            ADD EXPA0,R16               ; 
            LDI R16,0                   ;
            ADC EXPA1,R16               ;
            
            ;
            ; ФОРМИРОВАНИЕ ДОП. КОДА МАНТИССЫ ДЕЛИТЕЛЯ.
            CLR MANTAG                  ;
            CLR MANTBG                  ;

            MOV MANTB0NEG,MANTB0        ; КОПИРУЕМ ПОЛОЖИТЕЛЬНУЮ МАНТИССУ ДЕЛИТЕЛЯ.
            MOV MANTB1NEG,MANTB1        ;
            MOV MANTB2NEG,MANTB2        ;
            MOV MANTBGNEG,MANTBG        ;

            COM MANTB0NEG               ; ПОСКОЛЬКУ 2^N-|B|=(2^N-1-|B|)+1=COM(|B|)+1,
            COM MANTB1NEG               ; ТО ИНВЕРТИРУЕМ БИТЫ ПОЛОЖИТЕЛЬНОЙ МАНТИССЫ
            COM MANTB2NEG               ;
            COM MANTBGNEG               ;

            LDI R16,1                   ; И ПРИБАВЛЯЕМ ЕДИНИЦУ,
            ADD MANTB0NEG,R16           ; НЕ ЗАБЫВАЯ ПРО ВОЗМОЖНОЕ ПОЯВЛЕНИЕ БИТА ПЕРЕНОСА.
            LDI R16,0                   ;
            ADC MANTB1NEG,R16           ; 
            ADC MANTB2NEG,R16           ; 
            ADC MANTBGNEG,R16           ;

            ;
            ; ВЫЧИСЛЕНИЕ МАНТИССЫ ЧАСТНОГО.
            LDI STEPS,QDIGITS           ; КОЛИЧЕСТВО ШАГОВ РАВНО КОЛИЧЕСТВУ ВЫЧИСЛЯЕМЫХ ЦИФР ЧАСТНОГО.
            CLR Q0                      ; ЗАНУЛЯЕМ МАНТИССУ ЧАСТНОГО.
            CLR Q1                      ;
            CLR Q2                      ;
            CLR Q3                      ;

SUBMANTB:   ADD MANTA0,MANTB0NEG        ; ВЫЧИТАЕМ ИЗ МАНТИССЫ ДЕЛИМОГО ИЛИ ОСТАТКА
            ADC MANTA1,MANTB1NEG        ; МАНТИССУ ДЕЛИТЕЛЯ,
            ADC MANTA2,MANTB2NEG        ; УМНОЖЕННУЮ НА ВЕС
            ADC MANTAG,MANTBGNEG        ; ОЧЕРЕДНОЙ ЦИФРЫ ЧАСТНОГО.

CALCDIGIT:  IN R16,SREG                 ;
            SBRS R16,SREG_N             ; ОСТАТОК ОТРИЦАТЕЛЬНЫЙ?
            SBR Q0,1                    ; НЕТ, УСТАНАВЛИВАЕМ ТЕКУЩУЮ ЦИФРУ ЧАСТНОГО В 1.

            DEC STEPS                   ; ВЫЧИСЛЕНЫ ВСЕ ЦИФРЫ ЧАСТНОГО?
            BREQ RESTPOSREM             ; ДА, ВОССТАНАВЛИВАЕМ ПОСЛЕДНИЙ ПОЛОЖИТЕЛЬНЫЙ ОСТАТОК.

            CLC                         ; ОСВОБОЖДАЕМ И ЗАНУЛЯЕМ LSB ДЛЯ СЛЕДУЮЩЕЙ ЦИФРЫ ЧАСТНОГО.
            ROL Q0                      ;
            ROL Q1                      ; 
            ROL Q2                      ;
            ROL Q3                      ;

            CLC                         ; СДВИГАЕМ ОСТАТОК ВЛЕВО ВМЕСТЕ С ВИРТУАЛЬНОЙ
            ROL MANTA0                  ; РАЗРЯДНОЙ СЕТКОЙ, КОТОРАЯ ПРИВЯЗАНА К НЕМУ.
            ROL MANTA1                  ; НЕПОДВИЖНАЯ МАНТИССА ДЕЛИТЕЛЯ В ЭТОЙ СЕТКЕ
            ROL MANTA2                  ; СТАНЕТ ЭКВИВАЛЕНТНА УМНОЖЕННОЙ НА ВЕС СЛЕДУЮЩЕЙ
            ROL MANTAG                  ; МЛАДШЕЙ ЦИФРЫ ЧАСТНОГО, КОТОРУЮ МЫ БУДЕМ ВЫЯСНЯТЬ.

            IN R16,SREG                 ;
            SBRS R16,SREG_N             ; ОСТАТОК ПОЛОЖИТЕЛЬНЫЙ?
            RJMP SUBMANTB               ; ДА, ОТНИМАЕМ МАНТИССУ ДЕЛИТЕЛЯ.
            ADD MANTA0,MANTB0           ; НЕТ, ПРИБАВЛЯЕМ МАНТИССУ ДЕЛИТЕЛЯ.
            ADC MANTA1,MANTB1           ;
            ADC MANTA2,MANTB2           ;
            ADC MANTAG,MANTBG           ;
            RJMP CALCDIGIT              ; ОПРЕДЕЛЯЕМ СЛЕДУЮЩУЮ ЦИФРУ ЧАСТНОГО.

RESTPOSREM: IN R16,SREG                 ;
            SBRS R16,SREG_N             ; ПОСЛЕДНИЙ ОСТАТОК УЖЕ ПОЛОЖИТЕЛЬНЫЙ?
            RJMP CALCSTICKY             ; ДА, ПЕРЕХОДИМ К ВЫЧИСЛЕНИЮ STICKY-БИТА.
            ADD MANTA0,MANTB0           ; НЕТ, ВОССТАНАВЛИВАЕМ ДО ПОСЛЕДНЕГО ПОЛОЖИТЕЛЬНОГО.
            ADC MANTA1,MANTB1           ;
            ADC MANTA2,MANTB2           ;
            ADC MANTAG,MANTBG           ;

            ;
            ; ВЫЧИСЛЕНИЕ STICKY-БИТА ДЛЯ КОРРЕКТНОГО ОКРУГЛЕНИЯ К БЛИЖАЙШЕМУ.
            ;
            ; ЕСЛИ ОСТАТОК НЕНУЛЕВОЙ, ЗНАЧИТ СПРАВА ОТ ЧАСТНОГО СУЩЕСТВУЮТ НЕНУЛЕВЫЕ БИТЫ.
            ; S=1, R>0
            ; S=0, R=0
CALCSTICKY: COM MANTA0                  ; ВЫЧИСЛЕНИЕ ДОП. КОДА ОСТАТКА.
            COM MANTA1                  ; ИНВЕРТИРУЕМ ОСТАТОК: 2^N-1-A < 2^N (ДЛЯ ВСЕХ ЗНАЧЕНИЙ A).
            COM MANTA2                  ; ПРИБАВЛЯЕМ ЕДИНИЦУ: 2^N-1-A+1=2^N-A < 2^N (ТОЛЬКО ДЛЯ НЕНУЛЕВЫХ A).
            COM MANTAG                  ; СЛЕДОВАТЕЛЬНО, ТОЛЬКО ПРИ НУЛЕВОМ ОСТАТКЕ
            LDI R16,1                   ; ИЗ СТАРШЕГО БАЙТА БУДЕТ ЕДИНИЦА ПЕРЕНОСА.
            ADD MANTA0,R16              ; А ЭТО ЗНАЧИТ, ЧТО S=NOT(C).
            LDI R16,0                   ;
            ADC MANTA1,R16              ;
            ADC MANTA2,R16              ;
            ADC MANTAG,R16              ;

            IN R16,SREG                 ; КОНВЕРТИРУЕМ БИТ ПЕРЕНОСА В S-БИТ.
            LDI R17,1                   ; 
            EOR R16,R17                 ;
            OUT SREG,R16                ;

            ROL Q0                      ; ДОБАВЛЯЕМ СПРАВА К МАНТИССЕ ЧАСТНОГО ЗНАЧЕНИЕ S-БИТА.
            ROL Q1                      ; 
            ROL Q2                      ;
            ROL Q3                      ;

            ;
            ; НОРМАЛИЗАЦИЯ МАНТИССЫ ЧАСТНОГО.
            ;
            ; МАНТИССА ЧАСТНОГО ЛЕЖИТ В ИНТЕРВАЛЕ (0.5, 2)
            ; ПОЭТОМУ ДЕНОРМАЛИЗАЦИЯ ВОЗМОЖНА ТОЛЬКО НА 1 РАЗРЯД ВПРАВО.
            SBRC Q3,2                   ; ЦЕЛОЧИСЛЕННАЯ ЕДИНИЦА В ЧАСТНОМ ЕСТЬ?
            RJMP CHECKEXP               ; ДА, ЧАСТНОЕ НОРМАЛИЗОВАНО, ПРОВЕРЯЕМ ЭКСПОНЕНТУ.
            CLC                         ; НЕТ, НОРМАЛИЗУЕМ ВЛЕВО НА 1 РАЗРЯД.
            ROL Q0                      ;
            ROL Q1                      ;
            ROL Q2                      ;
            ROL Q3                      ;
                                        
            LDI R16,0xFF                ; УМЕНЬШАЕМ ЭКСПОНЕНТУ ЧАСТНОГО НА 1.
            LDI R17,0XFF                ;
            ADD EXPR0,R16               ;
            ADC EXPR1,R17               ;

            ;
            ; ПРОВЕРКА ЭКСПОНЕНТЫ НА ПЕРЕПОЛНЕНИЕ/АНТИПЕРЕПОЛНЕНИЕ.
            ;
            ; ПЕРЕПОЛНЕНИЕ: EXP > 127+127=254. ПО СТАНДАРТУ - УСТАНОВКА INF. ТЕКУЩАЯ РЕАЛИЗАЦИЯ - ВЫБРОС ИСКЛЮЧЕНИЯ.
            ; АНТИПЕРЕПОЛНЕНИЕ: EXP < -126+127=1. ПО СТАНДАРТУ - ПЕРЕХОД К ДЕНОРМАЛИЗОВАННОМУ ЧИСЛУ. ТЕКУЩАЯ РЕАЛИЗАЦИЯ - УСТАНОВКА ЧАСТНОГО В НОЛЬ.
CHECKEXP:   MOV R18,EXPR0               ; КОПИРУЕМ РАСШИРЕННУЮ ЭКСПОНЕНТУ ЧАСТНОГО.
            MOV R19,EXPR1               ;

            LDI R16,255                 ; ФОРМИРУЕМ -1 В ДОП. КОДЕ.
            LDI R17,255                 ; 
            ADD R16,R18                 ; ЕСЛИ ИСТИННАЯ ЭКСПОНЕНТА МЕНЬШЕ МИНИМАЛЬНОГО ПРЕДСТАВИМОГО ЗНАЧЕНИЯ (-126),
            ADC R17,R19                 ; ТО В КОДЕ СО СМЕЩЕНИЕМ ПОСЛЕ ВЫЧИТАНИЯ ЕДИНИЦЫ БУДЕТ ПОЛУЧЕНО ОТРИЦАТЕЛЬНОЕ ЧИСЛО.
            IN R16,SREG                 ; 
            SBRC R16,SREG_N             ; ЭКСПОНЕНТА В ПРЯМОМ КОДЕ МЕНЬШЕ -126?
            RJMP SETZERO                ; ДА, АНТИПЕРЕПОЛНЕНИЕ, ВОЗВРАЩАЕМ НОЛЬ.
                                        ; 
            LDI R16,1                   ; НЕТ, ПРОВЕРЯЕМ ЭКСПОНЕНТУ НА ПЕРЕПОЛНЕНИЕ.
            LDI R17,0                   ; ЕСЛИ ИСТИННАЯ ЭКСПОНЕНТА БОЛЬШЕ МАКСИМАЛЬНОГО ПРЕДСТАВИМОГО ЗНАЧЕНИЯ (127),
            ADD R16,R18                 ; ТО В КОДЕ СО СМЕЩЕНИЕМ ПОСЛЕ ПРИБАВЛЕНИЯ ЕДИНИЦЫ СТАРШИЙ БАЙТ РАСШИРЕННОЙ ЭКСПОНЕНТЫ
            ADC R17,R19                 ; БУДЕТ ОТЛИЧЕН ОТ НУЛЯ.
            COM R17                     ; ЕСЛИ СТАРШИЙ БАЙТ СОДЕРЖИТ НОЛЬ,
            LDI R16,1                   ; ТО ВЫЧИСЛЕНИЕ ДОП. КОДА ДАСТ НОЛЬ.
            ADD R16,R17                 ; ЭКСПОНЕНТА В ПРЯМОМ КОДЕ МЕНЬШЕ 128?
            BREQ ROUND                  ; ДА, ПЕРЕПОЛНЕНИЯ НЕТ, ПЕРЕХОДИМ К ОКРУГЛЕНИЮ.
            IJMP                        ; НЕТ, ПЕРЕПОЛНЕНИЕ, ПРЫЖОК НА ОБРАБОТЧИК ОШИБОК, УКАЗАННЫЙ В Z.

            ;
            ; ОКРУГЛЕНИЕ К БЛИЖАЙШЕМУ.
            ;
            ; ВОЗМОЖНЫЕ СОЧЕТАНИЯ БИТОВ RS. ДЛЯ КРАТКОСТИ GUARD-БИТ ЗДЕСЬ НЕ УЧИТЫВАЕТСЯ, ИЛЛЮСТРИРУЕТСЯ САМА ИДЕЯ ОКРУГЛЕНИЯ.
            ; RS
            ; --
            ; 00: ТОЧНОЕ ЗНАЧЕНИЕ. |ERR| = 0.
            ; 01: ОТБРАСЫВАЕМ. |ERR| < 2^-24=2^-23/2=ULP/2. ОШИБКА МЕНЬШЕ ПОЛОВИНЫ ВЕСА ПОСЛЕДНЕГО РАЗРЯДА МАНТИССЫ ОДИНАРНОЙ ТОЧНОСТИ.
            ; 10: ЕСЛИ ТАКАЯ СИТУАЦИЯ ИМЕЕТ МЕСТО, ТО ДЕЛИМОЕ ИМЕЕТ НЕНУЛЕВЫЕ РАЗРЯДЫ ЗА ПРЕДЕЛАМИ ДОСТУПНОЙ СЕТКИ, ЧТО НЕ ВОЗМОЖНО В НАШЕМ СЛУЧАЕ (ОБОСНОВАНИЕ - В ДОКАХ).
            ; 11: ОТБРАСЫВАЕМ И ПРИБАВЛЯЕМ 2^-23. |ERR| < 2^-24=ULP/2.
            ;
            ; КОММЕНТАРИИ К ПОСЛЕДНЕМУ СЛУЧАЮ:
            ; Q - ИСТИННАЯ МАНТИССА ЧАСТНОГО (БЕСКОНЕЧНАЯ ТОЧНОСТЬ).
            ; Q' - ОКРУГЛЕННОЕ ЗНАЧЕНИЕ.
            ; Q' = Q-(2^-24+A)+2^-23, ГДЕ A - БИТЫ ЗА ПРЕДЕЛАМИ СЕТКИ ВПРАВО ОТ R, ИНДИКАТОРОМ КОТОРЫХ ЯВЛЯЕТСЯ S-БИТ, СЛЕДОВАТЕЛЬНО, A < 2^-24.
            ; 2^-23 = 2^-24+2^-24 = 2^-24+(A+B), ГДЕ (A+B) = 2^-24, НО A > 0, СЛЕДОВАТЕЛЬНО B < 2^-24.
            ; ТОГДА МОЖЕМ ЗАПИСАТЬ Q' = Q-2^-24-A+2^-24+A+B = Q+B, ГДЕ B < 2^-24.
            ; ПОЭТОМУ В ПОСЛЕДНЕМ СЛУЧАЕ |ERR| < 2^-24=ULP/2.
ROUND:      MOV RGSBITS,Q0              ; ИЗВЛЕКАЕМ RGS-БИТЫ ИЗ МЛАДШЕГО БАЙТА МАНТИССЫ ЧАСТНОГО.
            LDI R16,RGSMASK             ;
            AND RGSBITS,R16             ;

            LDI STEPS,3                 ; ОТБРАСЫВАЕМ RGS-БИТЫ В МАНТИССЕ ЧАСТНОГО.
RSHIFT3:    CLC                         ; МЫ ВЫЧИСЛЯЛИ 26 ЦИФР ЧАСТНОГО + S-БИТ,
            ROR Q3                      ; ПОЭТОМУ ПОСЛЕ СДВИГА ВСЕ ЦИФРЫ МАНТИССЫ ЧАСТНОГО
            ROR Q2                      ; ПОМЕСТЯТСЯ В ТРЕХ МЛАДШИХ БАЙТАХ.
            ROR Q1                      ;
            ROR Q0                      ;
            DEC STEPS                   ;
            BRNE RSHIFT3                ;

            LDI R16,0xFC                ; ЕСЛИ В RGS УСТАНОВЛЕН БИТ R И ЕСТЬ НЕНУЛЕВЫЕ БИТЫ СПРАВА ОТ НЕГО,
            ADD RGSBITS,R16             ; ТОГДА В RGS НАХОДИТСЯ ЧИСЛО БОЛЬШЕ 4, А ЗНАЧИТ, ОТБРАСЫВАЯ RGS
            IN R16,SREG                 ; МЫ ПОЛУЧАЕМ ОШИБКУ БОЛЬШЕ ULP/2.
            SBRC R16, SREG_N            ; ОТБРОСИЛИ БОЛЬШЕ ULP/2?
            RJMP PACK                   ; НЕТ, ПАКУЕМ ЧАСТНОЕ.

            LDI R16,1                   ; ДА, ПРИБАВЛЯЕМ 2^-23.
            ADD Q0,R16                  ; ПЕРЕПОЛНЕНИЯ ПРИ ЭТОМ НЕ БУДЕТ (БОЛЕЕ ДЕТАЛЬНОЕ ОБОСНОВАНИЕ - В ДОКАХ).
            LDI R16,0                   ; НОРМАЛИЗОВАННАЯ МАНТИССА, КОТОРАЯ ДАСТ ПЕРЕПОЛНЕНИЕ - БОЛЬШЕ МАКСИМАЛЬНОЙ ВОЗМОЖНОЙ НОРМАЛИЗОВАННОЙ МАНТИССЫ,
            ADC Q1,R16                  ; А ДЕНОРМАЛИЗОВАННАЯ МАНТИССА, КОТОРАЯ ДАСТ ПОСЛЕ НОРМАЛИЗАЦИИ ПЕРЕПОЛНЕНИЕ,
            ADC Q2,R16                  ; МОЖЕТ БЫТЬ ПОЛУЧЕНА ТОЛЬКО ЕСЛИ ДЕЛИМОЕ ИМЕЕТ НЕНУЛЕВЫЕ РАЗРЯДЫ ЗА ПРЕДЕЛАМИ ОДИНАРНОЙ ТОЧНОСТИ, ЧТО НЕВОЗМОЖНО В НАШЕМ СЛУЧАЕ.

            ;
            ; УПАКОВКА ЗНАКА, МАНТИССЫ И ЭКСПОНЕНТЫ ЧАСТНОГО И ЗАПИСЬ НА МЕСТО ДЕЛИМОГО.
            ; НОРМАЛИЗОВАННАЯ И ОКРУГЛЕННАЯ МАНТИССА ЧАСТНОГО ТЕПЕРЬ ЗАНИМАЕТ 3 МЛАДШИХ БАЙТАХ.
PACK:       ROL Q0                      ; СДВИГАЕМ МАНТИССУ ВЛЕВО, УБИРАЯ ЦЕЛОЧИСЛЕННУЮ ЕДИНИЦУ.
            ROL Q1                      ;
            ROL Q2                      ;

            CLC                         ; ВЫДВИГАЕМ ВПРАВО LSB ЭКСПОНЕНТЫ В РАЗРЯД ПЕРЕНОСА,
            ROR EXPR0                   ; ОДНОВРЕМЕННО ОСВОБОЖДАЯ MSB ПОД ЗНАК.

            ROR Q2                      ; ВОЗВРАЩАЕМ МАНТИССУ НА МЕСТО
            ROR Q1                      ; С LSB ЭКСПОНЕНТЫ ВМЕСТО ЦЕЛОЧИСЛЕННОЙ ЕДИНИЦЫ.
            ROR Q0                      ;

            OR EXPR0,RSIGN              ; УСТАНАВЛИВАЕМ РАЗРЯД ЗНАКА.

            ;
            ; ЗАПИСЬ МАНТИССЫ ЧАСТНОГО НА МЕСТО ДЕЛИМОГО.
            MOV MANTA0,Q0
            MOV MANTA1,Q1
            MOV MANTA2,Q2

            RJMP EXIT

;
; УМНОЖАЕТ ДВА ЧИСЛА
; ПО СХЕМЕ С НЕПОДВИЖНЫМ МНОЖИТЕЛЕМ.
;
; МНОЖИМОЕ ОЖИДАЕТСЯ В РЕГИСТРАХ: R11, R10, R9, R8.
; МНОЖИТЕЛЬ ОЖИДАЕТСЯ В РЕГИСТРАХ: R15, R14, R13, R12. 
; ПРОИЗВЕДЕНИЕ ПОМЕЩАЕТСЯ НА МЕСТО МНОЖИМОГО: R11, R10, R9, R8.
FMUL32:     ;
            ; ФИЛЬТРАЦИЯ ОПЕРАНДОВ.
            CLR R16                     ;
            OR R16,R8                   ;
            OR R16,R9                   ;
            OR R16,R10                  ;
            OR R16,R11                  ;
            IN R16,SREG                 ; 
            SBRC R16,SREG_Z             ; МНОЖИМОЕ РАВНО НУЛЮ?
            RJMP SETZERO                ; ДА, ВОЗВРАЩАЕМ НОЛЬ.

            CLR R16                     ; НЕТ, ПРОВЕРЯЕМ МНОЖИТЕЛЬ.
            OR R16,R12                  ;
            OR R16,R13                  ;
            OR R16,R14                  ;
            OR R16,R15                  ;
            IN R16,SREG                 ; 
            SBRC R16,SREG_Z             ; МНОЖИТЕЛЬ РАВЕН НУЛЮ?
            RJMP SETZERO                ; ДА, ВОЗВРАЩАЕМ НОЛЬ.

            ;
            ; ОПРЕДЕЛЕНИЕ ЗНАКА ПРОИЗВЕДЕНИЯ.
            MOV RSIGN,R11               ; КОПИРУЕМ СТАРШИЙ БАЙТ МНОЖИМОГО.
            MOV R1,R15                  ; КОПИРУЕМ СТАРШИЙ БАЙТ МНОЖИТЕЛЯ.
            LDI R16,0b10000000          ; ЗАГРУЖАЕМ МАСКУ ЗНАКА.
            AND RSIGN,R16               ; ИЗВЛЕКАЕМ ЗНАК МНОЖИМОГО.
            AND R1,R16                  ; ИЗВЛЕКАЕМ ЗНАК МНОЖИТЕЛЯ.
            EOR RSIGN,R1                ; ОПРЕДЕЛЯЕМ ЗНАК ПРОИЗВЕДЕНИЯ.

            ;
            ; РАСПАКОВКА МНОЖИМОГО.
            ROL R10                     ; MSB МАНТИССЫ СОДЕРЖИТ LSB ЭКСПОНЕНТЫ. СДВИГАЕМ ЕГО В БИТ ПЕРЕНОСА.
            ROL R11                     ; ИЗБАВЛЯЕМСЯ ОТ ЗНАКА И ВОССТАНАВЛИВАЕМ МЛАДШИЙ БИТ ЭКСПОНЕНТЫ.
            SEC                         ; ВОССТАНАВЛИВАЕМ СКРЫТУЮ ЕДИНИЦУ МАНТИССЫ.
            ROR R10                     ; ВОЗВРАЩАЕМ НА МЕСТО СТАРШИЙ БАЙТ МАНТИССЫ.

            ;
            ; РАСПАКОВКА МНОЖИТЕЛЯ.
            ROL R14                     ; ТО ЖЕ САМОЕ ЧТО И ДЛЯ МНОЖИМОГО.
            ROL R15                     ; 
            SEC                         ;
            ROR R14                     ; 

            ;
            ; ВЫЧИСЛЕНИЕ ЭКСПОНЕНТЫ ПРОИЗВЕДЕНИЯ.
            ;
            ; ПОСКОЛЬКУ ЭКСПОНЕНТЫ ПРЕДСТАВЛЕНЫ В КОДЕ СО СМЕЩЕНИЕМ, ТО
            ; ИХ ЗНАЧЕНИЯ ВСЕГДА ЯВЛЯЮТСЯ ПОЛОЖИТЕЛЬНЫМИ ЧИСЛАМИ В ДИАПАЗОНЕ [1,254].
            CLR EXPA1
            CLR EXPB1
            
            ADD EXPA0,EXPB0             ; EXPA=EXPA+EXPB.
            ADC EXPA1,EXPB1             ; СУММА ЭКСПОНЕНТ СОДЕРЖИТ ИЗБЫТОЧНОЕ ЗНАЧЕНИЕ 127.
            LDI R16,-127                ; НЕОБХОДИМО ОТНЯТЬ ЭТО ЗНАЧЕНИЕ.
            LDI R17,255                 ; ФОРМИРУЕМ ДОП. КОД ДЛЯ -127 В ДВОЙНОЙ СЕТКЕ.
            ADD EXPA0,R16               ; ВОССТАНАВЛИВАЕМ СУММУ ЭКСПОНЕНТ
            ADC EXPA1,R17               ; В КОДЕ СО СМЕЩЕНИЕМ.

            ;
            ; ВЫЧИСЛЕНИЕ МАНТИССЫ ПРОИЗВЕДЕНИЯ.
            LDI R22,24                  ; КОЛИЧЕСТВО ШАГОВ ЦИКЛА РАВНО КОЛИЧЕСТВУ ЦИФР МНОЖИМОГО.

            CLR MANTP0                  ; ЗАНУЛЯЕМ ПРОИЗВЕДЕНИЕ.
            CLR MANTP1                  ;
            CLR MANTP2                  ;
            CLR MANTP3                  ;
            CLR MANTP4                  ;
            CLR MANTP5                  ;

NEXTDIGIT:  ROR MANTA2                  ; ИЗВЛЕКАЕМ ОЧЕРЕДНУЮ ЦИФРУ МНОЖИМОГО.
            ROR MANTA1                  ;
            ROR MANTA0                  ;
                                        
            IN R16,SREG                 ; 
            SBRS R16,SREG_C             ; ЦИФРА РАВНА 1?
            RJMP LOOPCOND0              ; НЕТ, РАВНА 0, МНОЖИТЕЛЬ НЕ ПРИБАВЛЯЕМ.
            ADD MANTP3,MANTB0           ; ДА, ПРИБАВЛЯЕМ МНОЖИТЕЛЬ К АККУМУЛЯТОРУ.
            ADC MANTP4,MANTB1           ; МЛАДШИЕ 3 БАЙТА МНОЖИТЕЛЯ В ДВОЙНОЙ СЕТКЕ НУЛЕВЫЕ,
            ADC MANTP5,MANTB2           ; ПОЭТОМУ ДОСТАТОЧНО СЛОЖИТЬ ТОЛЬКО СТАРШИЕ БАЙТЫ.

LOOPCOND0:  DEC R22                     ; ЭТО БЫЛА ПОСЛЕДНЯЯ ЦИФРА МНОЖИМОГО?
            BREQ CHECKOVF0              ; ДА, МАНТИССА ПРОИЗВЕДЕНИЯ ВЫЧИСЛЕНА, ПРОВЕРЯЕМ ЕЁ НА ПЕРЕПОЛНЕНИЕ.

            ROR MANTP5                  ; НЕТ, ДЕЛИМ АККУМУЛЯТОР НА 2.
            ROR MANTP4                  ;
            ROR MANTP3                  ;
            ROR MANTP2                  ;
            ROR MANTP1                  ;
            ROR MANTP0                  ;            

            RJMP NEXTDIGIT              ; ПЕРЕХОДИМ К СЛЕДУЮЩЕЙ ЦИФРЕ МНОЖИМОГО.

CHECKOVF0:  IN R16,SREG                 ; 
            SBRS R16,SREG_C             ; МАНТИССА ПРОИЗВЕДЕНИЯ ДАЛА ПЕРЕПОЛНЕНИЕ?
            RJMP ROUNDPROD              ; НЕТ, ПЕРЕХОДИМ К ЕЁ ОКРУГЛЕНИЮ.
            ROR MANTP5                  ; ДА, НОРМАЛИЗУЕМ МАНТИССУ ПРОИЗВЕДЕНИЯ ВПРАВО НА 1 РАЗРЯД.
            ROR MANTP4                  ;
            ROR MANTP3                  ;
            ROR MANTP2                  ;
            ROR MANTP1                  ;
            ROR MANTP0                  ;

            LDI R16,1                   ; КОРРЕКТИРУЕМ ЭКСПОНЕНТУ.
            ADD EXPA0,R16               ;
            LDI R16,0                   ;
            ADC EXPA1,R16               ;

            ;
            ; ОКРУГЛЕНИЕ МАНТИССЫ ПРОИЗВЕДЕНИЯ.
            ;
            ; ПОСЛЕ УСТАНОВКИ S-БИТА И ИЗВЛЕЧЕНИЯ ПАРЫ RS
            ; MANTP2 МОЖЕТ СОДЕРЖАТЬ СЛЕДУЮЩИЕ ЗНАЧЕНИЯ:
            ; - 0b11000000
            ; - 0b10000000
            ; - 0b01000000
            ; - 0b00000000
ROUNDPROD:  CLR GUARD
            CLC
            
            ROL MANTP0                  ; СДВИГАЕМ R-БИТ В GUARD-РЕГИСТР.
            ROL MANTP1                  ; ТЕПЕРЬ МЛАДШАЯ ЧАСТЬ СОДЕРЖИТ ТОЛЬКО БИТЫ ПОСЛЕ R.
            ROL MANTP2                  ;
            ROL GUARD                   ;

            COM MANTP0                  ; ЕСЛИ ПОСЛЕ R-БИТА ВСЕ БИТЫ НУЛЕВЫЕ,
            COM MANTP1                  ; ТО ВЫЧИСЛЕНИЕ ДОП. КОДА МЛАДШЕЙ ЧАСТИ
            COM MANTP2                  ; ДАСТ БИТ ПЕРЕНОСА.
            LDI R16,1                   ; ПОЭТОМУ ОТСУТСТВИЕ БИТА ПЕРЕНОСА
            ADD MANTP0,R16              ; ИСПОЛЬЗУЕМ КАК ПРИЗНАК ТОГО,
            LDI R16,0                   ; ЧТО ПОСЛЕ R-БИТА ЕСТЬ ХОТЯ БЫ ОДИН НЕНУЛЕВОЙ БИТ.
            ADC MANTP1,R16              ;
            ADC MANTP2,R16              ;

            IN R16,SREG                 ;
            SBRS R16,SREG_C             ; ПОСЛЕ R-БИТА ЕСТЬ НЕНУЛЕВЫЕ БИТЫ?
            SBR MANTP2,0b10000000       ; ДА, УСТАНАВЛИВАЕМ S-БИТ.

            ROR GUARD                   ; НЕТ, ВСЯ МЛАДШАЯ ЧАСТЬ НУЛЕВАЯ (ВКЛЮЧАЯ S-БИТ, ПОЭТОМУ ЯВНО ОБНУЛЯТЬ S-БИТ НЕТ НЕОБХОДИМОСТИ).
            ROR MANTP2                  ; ВОССТАНАВЛИВАЕМ R-БИТ.
            ROR MANTP1                  ;
            ROR MANTP0                  ;

            LDI R16,0b11000000          ; ИЗВЛЕКАЕМ RS-БИТЫ.
            AND MANTP2,R16              ;

            CLR GUARD                   ; ИНТЕРПРЕТИРУЕМ РЕГИСТР С RS-БИТАМИ КАК ЧИСЛО И ФОРМИРУЕМ ЕГО ДОП. КОД.
            COM MANTP2                  ; ДОП. КОД ФОРМИРУЕМ В ДВОЙНОЙ СЕТКЕ, Т.К. ДЛЯ ПРЕДСТАВЛЕНИЯ В ДОП. КОДЕ
            COM GUARD                   ; ЗНАЧЕНИЙ 0b11000000 И 0b10000000 СО ЗНАКОМ МИНУС
            LDI R16,1                   ; ОДИНАРНОЙ СЕТКИ УЖЕ НЕ ДОСТАТОЧНО.
            ADD MANTP2,R16              ;
            LDI R16,0                   ;
            ADC GUARD,R16               ;

            CLR STATUS0                 ; РАЗНОСТЬ МЕЖДУ ОПОРНЫМ ЗНАЧЕНИМ 0b10000000 И ЧИСЛОВОЙ ИНТЕРПРЕТАЦИЕЙ RS
            CLR STATUS1                 ; ОДНОЗНАЧНО СВЯЗАНА С НАПРАВЛЕНИЕМ ОКРУГЛЕНИЯ (СМ. ДОКУ).
            LDI R16,0b10000000          ; ЗА ПРИЗНАК БЕРЕМ НУЛЕВОЙ РЕЗУЛЬТАТ И ЗНАК ПОЛУЧЕННОЙ РАЗНОСТИ.
            ADD MANTP2,R16              ; 
            IN STATUS0,SREG             ; СОХРАНЯЕМ ФЛАГИ ПОСЛЕ ОПЕРАЦИИ С МЛАДШИМ БАЙТОМ.
            LDI R16,0                   ; 
            ADC GUARD,R16               ;
            IN STATUS1,SREG             ; СОХРАНЯЕМ ФЛАГИ ПОСЛЕ ОПЕРАЦИИ СО СТАРШИМ БАЙТОМ.

            SBRS STATUS1,SREG_N         ; RS=0b11000000? [NOTE: ОТРИЦАТЕЛЬНАЯ РАЗНОСТЬ ВОЗМОЖНА ТОЛЬКО В СИТУАЦИИ 0b10000000-0b11000000.]
            RJMP HALFWAY                ; НЕТ, ПРОВЕРЯЕМ СЛЕДУЮЩИЙ ВАРИАНТ.
            LDI R16,1                   ; ДА, МЛАДШАЯ ЧАСТЬ БОЛЬШЕ ULP/2. ОКРУГЛЯЕМ В БОЛЬШУЮ СТОРОНУ.
            ADD MANTP3,R16              ; ОТБРАСЫВАЕМ МЛАДШУЮ ЧАСТЬ И ПРИБАВЛЯЕТ ULP.
            LDI R16,0                   ; ЭТО ЭКВИВАЛЕНТНО ПРИБАВЛЕНИЮ К МЛАДШЕЙ ЧАСТИ ВЕЛИЧИНЫ МЕНЬШЕ ULP/2,
            ADC MANTP4,R16              ; ПРИВОДЯЩЕМУ К ЗАНУЛЕНИЮ МЛАДШЕЙ ЧАСТИ И ПОЯВЛЕНИЮ БИТА ПЕРЕНОСА В MANTP3.
            ADC MANTP5,R16              ;
            RJMP CHECKOVF1              ;

HALFWAY:    AND STATUS1,STATUS0         ; РАЗНОСТЬ НУЛЕВАЯ, ЕСЛИ ФЛАГ Z БЫЛ УСТАНОВЛЕН ДЛЯ КАЖДОГО БАЙТА.
            SBRS STATUS1,SREG_Z         ; RS=0b10000000?
            RJMP CHECKOVF1              ; НЕТ, RS=0b01000000 ИЛИ RS=0b00000000. МЛАДШАЯ ЧАСТЬ МЕНЬШЕ ULP/2, ПРОСТО ОТБРАСЫВАЕМ ЕЁ.
            LDI R16,0b00000001          ; ДА, СИММЕТРИЧНОЕ ОКРУГЛЕНИЕ. МЛАДШАЯ ЧАСТЬ РАВНА ULP/2, ОКРУГЛЯЕМ К ЧЕТНОМУ.
            AND R16,MANTP3              ; ИЗВЛЕКАЕМ ULP В R16.
            ADD MANTP3,R16              ; ЕСЛИ ULP=1, ТО СТАРШАЯ ЧАСТЬ НЕЧЕТНАЯ
            LDI R16,0                   ; И ПРИБАВЛЕНИЕ R16 (КОТОРЫЙ СОДЕРЖИТ ТАКЖЕ СОДЕРЖИТ 1) ДАСТ ПЕРЕХОД К ЧЕТНОМУ.
            ADC MANTP4,R16              ; ЕСЛИ ЖЕ ULP=0, ТО ЗНАЧЕНИЕ УЖЕ ЧЕТНОЕ
            ADC MANTP5,R16              ; И ПРИБАВЛЕНИЕ R16 (КОТОРЫЙ ТАКЖЕ СОДЕРЖИТ 0) НИКАКОГО ЭФФЕКТА НЕ ДАСТ, ОСТАВЛЯЯ ЗНАЧЕНИЕ ЧЕТНЫМ.

            ;
            ; ПРОВЕРКА МАНТИССЫ ПРОИЗВЕДЕНИЯ НА ПЕРЕПОЛНЕНИЕ ПОСЛЕ ОКРУГЛЕНИЯ.
CHECKOVF1:  IN R16,SREG                 ; 
            SBRS R16,SREG_C             ; ОКРУГЛЕНИЕ ДАЛО ПЕРЕПОЛНЕНИЕ?
            RJMP CHECKEXP1              ; НЕТ, ПЕРЕХОДИМ К ПРОВЕРКЕ ЭКСПОНЕНТЫ.
            ROR MANTP5                  ; ДА, НОРМАЛИЗУЕМ МАНТИССУ ПРОИЗВЕДЕНИЯ ВПРАВО НА 1 РАЗРЯД.
            ROR MANTP4                  ;
            ROR MANTP3                  ;

            LDI R16,1                   ; КОРРЕКТИРУЕМ ЭКСПОНЕНТУ.
            ADD EXPA0,R16               ;
            LDI R16,0                   ;
            ADC EXPA1,R16               ;

            ;
            ; ПРОВЕРКА ИТОГОВОГО ПРОИЗВЕДЕНИЯ НА ПЕРЕПОЛНЕНИЕ/АНТИПЕРЕПОЛНЕНИЕ ПО ЭКСПОНЕНТЕ.
            ;
            ; ЕСЛИ ЭКСПОНЕНТА МЕНЬШЕ -126 (-126+127=1 В КОДЕ СО СМЕЩЕНИЕМ), ТО ПРОИЗВЕДЕНИЕ СЛИШКОМ МАЛО И МЫ ПЕРЕХОДИМ К НУЛЮ.
            ; ЕСЛИ ЭКСПОНЕНТА БОЛЬШЕ 127 (127+127=254 В КОДЕ СО СМЕЩЕНИЕМ), ТО ПРОИЗВЕДЕНИЕ СЛИШКОМ ВЕЛИКО И МЫ ВЫБРАСЫВАЕМ ИСКЛЮЧЕНИЕ.
CHECKEXP1:  MOV R18,EXPR0               ; КОПИРУЕМ РАСШИРЕННУЮ ЭКСПОНЕНТУ ПРОИЗВЕДЕНИЯ.
            MOV R19,EXPR1               ;

            LDI R16,255                 ; ФОРМИРУЕМ -1 В ДОП. КОДЕ.
            LDI R17,255                 ; 
            ADD R16,R18                 ; ЕСЛИ ИСТИННАЯ ЭКСПОНЕНТА МЕНЬШЕ МИНИМАЛЬНОГО ПРЕДСТАВИМОГО ЗНАЧЕНИЯ (-126),
            ADC R17,R19                 ; ТО В КОДЕ СО СМЕЩЕНИЕМ ПОСЛЕ ВЫЧИТАНИЯ ЕДИНИЦЫ БУДЕТ ПОЛУЧЕНО ОТРИЦАТЕЛЬНОЕ ЧИСЛО.
            IN R16,SREG                 ; 
            SBRC R16,SREG_N             ; ЭКСПОНЕНТА В ПРЯМОМ КОДЕ МЕНЬШЕ -126?
            RJMP SETZERO                ; ДА, АНТИПЕРЕПОЛНЕНИЕ, ВОЗВРАЩАЕМ НОЛЬ.
                                        ; 
            LDI R16,1                   ; НЕТ, ПРОВЕРЯЕМ ЭКСПОНЕНТУ НА ПЕРЕПОЛНЕНИЕ.
            LDI R17,0                   ; ЕСЛИ ИСТИННАЯ ЭКСПОНЕНТА БОЛЬШЕ МАКСИМАЛЬНОГО ПРЕДСТАВИМОГО ЗНАЧЕНИЯ (127),
            ADD R16,R18                 ; ТО В КОДЕ СО СМЕЩЕНИЕМ ПОСЛЕ ПРИБАВЛЕНИЯ ЕДИНИЦЫ СТАРШИЙ БАЙТ РАСШИРЕННОЙ ЭКСПОНЕНТЫ БУДЕТ ОТЛИЧЕН ОТ НУЛЯ.
            ADC R17,R19                 ; ЭКСПОНЕНТА В ПРЯМОМ КОДЕ МЕНЬШЕ 128?
            BREQ PACKPROD               ; ДА, ПЕРЕПОЛНЕНИЯ НЕТ, ПЕРЕХОДИМ К УПАКОВКЕ.
            IJMP                        ; НЕТ, ПЕРЕПОЛНЕНИЕ, ПРЫЖОК НА ОБРАБОТЧИК ОШИБОК, УКАЗАННЫЙ В Z.
            
            ;
            ; УПАКОВКА МАНТИССЫ И ЭКСПОНЕНТЫ ПРОИЗВЕДЕНИЯ.
PACKPROD:   ROL MANTP3                  ; СДВИГАЕМ МАНТИССУ ВЛЕВО, УБИРАЯ ЦЕЛОЧИСЛЕННУЮ ЕДИНИЦУ.
            ROL MANTP4                  ;
            ROL MANTP5                  ;

            CLC                         ; ВЫДВИГАЕМ ВПРАВО LSB ЭКСПОНЕНТЫ В РАЗРЯД ПЕРЕНОСА,
            ROR EXPR0                   ; ОДНОВРЕМЕННО ОСВОБОЖДАЯ MSB ПОД ЗНАК.

            ROR MANTP5                  ; ВОЗВРАЩАЕМ МАНТИССУ НА МЕСТО
            ROR MANTP4                  ; С LSB ЭКСПОНЕНТЫ ВМЕСТО ЦЕЛОЧИСЛЕННОЙ ЕДИНИЦЫ.
            ROR MANTP3                  ;

            OR EXPR0,RSIGN              ; УСТАНАВЛИВАЕМ РАЗРЯД ЗНАКА.

            MOV MANTA0,MANTP3           ; ЗАПИСЬ МАНТИССЫ ПРОИЗВЕДЕНИЯ НА МЕСТО МАНТИССЫ МНОЖИМОГО.
            MOV MANTA1,MANTP4
            MOV MANTA2,MANTP5

            RJMP EXIT
            
EXIT:       RET

            ;
            ; УСТАНОВКА РЕЗУЛЬТАТА В НОЛЬ.
            ;
            ; ВЫПОЛНЯЕТСЯ В СЛЕДУЮЩИХ СЛУЧАЯХ:
            ; - АНТИПЕРЕПОЛНЕНИЕ РЕЗУЛЬТАТА ДЛЯ ЛЮБОЙ ОПЕРАЦИИ.
            ; - ДЕЛИМОЕ РАВНО НУЛЮ.
            ; - ХОТЯ БЫ ОДИН СОМНОЖИТЕЛЬ РАВЕН НУЛЮ.
SETZERO:    CLR MANTA0
            CLR MANTA1
            CLR MANTA2
            CLR EXPA0
            RJMP EXIT
