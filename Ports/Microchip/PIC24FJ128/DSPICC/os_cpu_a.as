;********************************************************************************************************
;                                              uC/OS-II
;                                        The Real-Time Kernel
;
;                    Copyright 1992-2021 Silicon Laboratories Inc. www.silabs.com
;
;                                 SPDX-License-Identifier: APACHE-2.0
;
;               This software is subject to an open source license and is distributed by
;                Silicon Laboratories Inc. pursuant to the terms of the Apache License,
;                    Version 2.0 available at www.apache.org/licenses/LICENSE-2.0.
;
;********************************************************************************************************

;********************************************************************************************************
;
;                                           PIC24 MPLab Port
;                                    For the Hi-Tech dsPICC Compiler
;
; Filename : os_cpu_a.as
; Version  : V2.93.01
;********************************************************************************************************


;
;********************************************************************************************************
;                                                CONSTANTS
;********************************************************************************************************
;

;
;********************************************************************************************************
;                                               INCLUDES
;********************************************************************************************************
;

    #include <asdspic.h>                                                ; Include assembly equates for various CPU registers and bit masks
    #include "os_cpu_util_a.as"                                         ; Include an assembly utility files with macros for saving and restoring the CPU registers

;
;********************************************************************************************************
;                                             LINKER SPECIFICS
;********************************************************************************************************
;

	psect	text,global,reloc=4,class=CODE,delta=2                      ; Locate this file in the text region of the build

;
;********************************************************************************************************
;                                               CONSTANTS
;********************************************************************************************************
;
    IPL3    EQU    0x0003
;
;********************************************************************************************************
;                                               GLOBALS
;********************************************************************************************************
;

    GLOBAL  _OSStartHighRdy
    GLOBAL  _OSCtxSw
    GLOBAL  _OSIntCtxSw
    GLOBAL  _OSTaskSwHook
    GLOBAL  _OSRunning
    GLOBAL  _OSTCBHighRdy
    GLOBAL  _OSPrioHighRdy
    GLOBAL  _OSPrioCur

;
;********************************************************************************************************
;                                            OSStartHighRdy
;
; Description : This function determines the highest priority task that is ready to run after
;               OSInit() is called.
;********************************************************************************************************
;

_OSStartHighRdy:
    call   _OSTaskSwHook                          ; Call user defined task switch hook

    mov    #0x0001, w0                            ; Set OSRunning to TRUE
    mov    #_OSRunning, w1
    mov.b  w0, [w1]                               ; Set OSRunning to TRUE

                                                  ; Get stack pointer of the task to resume
    mov    _OSTCBHighRdy, w0                      ; Get the pointer to the stack to resume
    mov    [w0], w15                              ; Dereference the pointer and store the data (the new stack address) W15, the stack pointer register

    OS_REGS_RESTORE                               ; Restore all of this tasks registers from the stack

    retfie                                        ; Return from the interrupt, the task is now ready to run

;
;********************************************************************************************************
;                                            OSCtxSw
;
; Description : TThe code to perform a 'task level' context switch.  OSCtxSw() is called
;               when a higher priority task is made ready to run by another task or,
;               when the current task can no longer execute (e.g. it calls OSTimeDly(),
;               OSSemPend() and the semaphore is not available, etc.).
;********************************************************************************************************
;

_OSCtxSw:
                                                  ; Ideally, a TRAP (interrupt) would bring us here, not 'call' (see os_cpu.h).
                                                  ; Since the PIC24 has no software TRAP instruction, it is necessary to correct the stack
                                                  ; to simulate an interrupt. In other words, this function must also save SR and IPL3 to
                                                  ; the stack, not just the PC.

    mov.b  SR, wreg                               ; Load SRL
    sl     w0, #8, w0                             ; Shift left by 8
    btsc   CORCON, #IPL3                          ; Test IPL3 bit, skip if clear
    bset   w0, #7;                                ; Copy IPL3 to bit7 of w0

    ior    w0, [--w15], w0                        ; Merge IPL3 bit with last byte pushed <SRL|IPL3>
    mov    w0, [w15++]                            ; Readjust stack pointer so there is no net change due to previous write

    OS_REGS_SAVE                                  ; Save processor registers

                                                  ; Save current task's stack pointer into the currect tasks TCB
    mov    _OSTCBCur, w0                          ; Get the address of the location in this tasks TCB to store the stack pointer
    mov    w15, [w0]                              ; Store the stack pointer in this tasks TCB

    call   _OSTaskSwHook                          ; Call the user defined task switch hook

    mov    _OSTCBHighRdy, w1                      ; Set the current running TCB to the TCB of the highest priority task ready to run
    mov    w1, _OSTCBCur
    mov    #_OSPrioHighRdy, w0
    mov    #_OSPrioCur, w2
    mov.b  [w0], [w2]

    mov    [w1], w15                              ; Load W15 with the stack pointer from the task that is ready to run

    OS_REGS_RESTORE                               ; Restore registers

    retfie                                        ; Return from interrupt

;
;********************************************************************************************************
;                                            OSIntCtxSw
;
; Description : When an ISR (Interrupt Service Routine) completes, OSIntExit() is called to
;               determine whether a more important task than the interrupted task needs to
;               execute.  If that's the case, OSIntExit() determines which task to run next
;               and calls OSIntCtxSw() to perform the actual context switch to that task.
;********************************************************************************************************
;

_OSIntCtxSw:
    call   _OSTaskSwHook                          ; Call the user defined task switch hook

    mov    _OSTCBHighRdy, w1                      ; Set the current running TCB to the TCB of the highest priority task ready to run
    mov    w1, _OSTCBCur
    mov    #_OSPrioHighRdy, w0
    mov    #_OSPrioCur, w2
    mov.b  [w0], [w2]

    mov    [w1], w15                              ; Load W15 with the stack pointer from the task that is ready to run

    OS_REGS_RESTORE                               ; Restore registers

    retfie                                        ; Return from interrupt
