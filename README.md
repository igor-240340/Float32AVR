# Float32AVR
Floating-point routines for AVR MCUs. Partially compliant with IEEE 754.

Completely built from the ground up: all floating-point related algorithms has been developed from the fundamental basic binary arithmetic principles and with some of the restrictions dictated by IEEE 754 standard in mind.

Some of the research notes can be found [*here*](https://drive.google.com/open?id=17ViZAw4rgcqFg06v3ZrvuvWtl1nly2Ic&usp=drive_fs) (a little bit messy).

Formal proof for division algorithm with immovable divisor can be found [*here*](https://drive.google.com/open?id=10WZpMqTUmbDx7oKYT3m1wm0OJeUH0PQj&usp=drive_fs) (could not find the good one so had to write by myself).

[*Here*](https://github.com/igor-240340/FloatingPointEmulationAVRTest) is the auxiliary repo with test examples. Each test example in this library has its desktop equavalent in that repo. It's primary goal is to check that our floating-point library gives the same resulat as hardware floating-point on a desktop environment.

# Flowcharts
## FADD32
![](docs/flowchart_fadd.png)
## FMUL32
![](docs/flowchart_fmul.png)
## FDIV32
![](docs/flowchart_fdiv.png)
