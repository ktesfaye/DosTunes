TITLE DOSTUNES

INCLUDE cs240.inc
.386

DOSEXIT			= 4C00h
DOS			= 21h
BIOS			= 10h

FREQUENCY		= 1193180
READY_TIMER		= 0B6h
TIMER_DATA_PORT		= 42h
TIMER_CONTROL_PORT	= 43h
SPEAKER_PORT		= 61h

OPENFILE 		= 3D00h
READFILE 		= 3F00h
CLOSEFILE 		= 3E00h
PSP 			= 6200h
CMDTAIL 		= 80h


.data

cmdbuffer               WORD 120 dup(0)
filehandle              WORD ?
buffsize                WORD 10
buffer                  BYTE 10 dup(0)
tempo			BYTE 0
garbageBuffer		BYTE 10 dup(0)
bytesread               WORD ?

WAITTIME                WORD 0
LINECOUNT               WORD 0
Full_Tempo              WORD 0
filename	        BYTE 260 dup(0)

error   		BYTE "Error finding the file", 0


A1                      WORD  54BEh,4FFCh,59C8h
B1                      WORD  4B7Fh,0000h,4FFCh
C1                      WORD  8E85h,8685h
D1                      WORD  7EF8h,77DBh,8685h
E1                      WORD  711Eh,0000h,77DBh
F1                      WORD  6AC4h,64C7h
G1                      WORD  5F23h,59C8h,64C7h

.code

Delay PROC
;*********************************************************************
; cx is number of milliseconds
; return after that number of milliseconds
;*********************************************************************
	push cx		; save registers
	push bx
	push dx
	pushf

	mov bx,10	; we need to div by 1000
	mov dx,0	; clear dx
	div bx		; to get ax into seconds

	cmp ax,0	; if 0
	jz done		; don't do anything

	push ax		; save ax
	mov ah,2Ch	; set DOS function 2C (get system time)
	int 21h		; get current time (ch=hr,cl=min,dh=sec,dl=csec)
	pop ax		; restore ax

	mov bh,dl	; storing current csec in bh

top:	push ax		; saving ax
	mov ah,2Ch	; DOS function get system time
	int 21h		; get system time
	pop ax		; restore ax
pass:	cmp bh,dl	; see if csec is still the same
	jz top		; if same, get time again
	mov bl,dl	; otherwise, store new time
	jl less		; if bh is less, a new second has no occured
	add dl,100	; if bh is more, we need to add 100 (carry)
less:	sub dl,bh	; get difference in dl
	mov dh,0	; clear dh
	sub ax,dx	; subtract that time from ax
	mov bh,bl	; store new time in bh
	cmp ax,0	; see if ax is now 0
	jle done	; if yeah, we are done
	jmp top		; if not DO IT AGAIN!!!

done:	popf		; restore regs
	pop dx
	pop bx
	pop cx
	ret		; RETURN!!!
Delay ENDP

getfilename PROC
        pushf
        push ax
        push bx
        push dx
        push es
        push si
        push cx
        push bp

        mov ax, PSP			;grab the system stack
        int DOS

        mov cx, 0

        mov es, bx			;and get a pointer to it
        mov si, CMDTAIL			;the start of the arg at OFFSET 80

        inc si				;80-size of the argument
        mov bx, OFFSET filename

next:
        inc si
        mov dl, es:[si]
        cmp dl, 21h			;check for exclamation
        jb next
        cmp dl, 7Eh			;check for tilde
        ja next

file:
        cmp dl, 21h			;check for exclamation
        jb done
        cmp dl, 7Eh
        ja done
        mov [bx], dl
        inc bx
        inc si
        mov dl, es:[si]
        jmp file
done:
        pop bp
        pop cx
        pop si
        pop es
        pop dx
        pop bx
        pop ax
        popf
        ret
getfilename ENDP

readTempo PROC
        pusha

	mov ax,READFILE
	mov bx,filehandle
	mov cx,04h
	mov dx, OFFSET tempo
	int 21h
	mov bytesread,ax

        popa
        ret
readTempo ENDP

readnewline PROC
        pusha

	mov ax, READFILE
	mov bx, filehandle
	mov cx, 02h
	mov dx, OFFSET garbagebuffer
	int DOS
	mov bytesread, ax

        popa
	ret
readnewline ENDP

readANote PROC		;read bytes equal to cx value
        pusha

         mov ax, 0
         mov ah,03Fh            ;command to read from file
         mov bx,filehandle
         mov cx,06h
         mov dx,OFFSET buffer   ;read bytes stored in buffe
         int 21h
         mov bytesread, ax      ;store the no of bytes read

         popa
         ret
readANote ENDP

openthisfile PROC	;open file by passing command to ah
        push ax
        push dx


        mov ax, OPENFILE		; call sys intrupt to open a file
        mov dx, OFFSET filename 	; take the filename from the data

        int DOS
        jc err

        mov filehandle, ax		; save the file handle
        jmp done

err:
        mov dx, OFFSET error
        call WriteString

        mov ax, DOSEXIT
        int DOS
done:
        pop dx
        pop ax
        ret
openthisfile ENDP

.data
MUTED		BYTE 0
.code
SpeakerOn PROC
	pushf
	push	ax

	cmp	MUTED, 1
	je	done

	in	al, SPEAKER_PORT		; Read the speaker register
	or	al, 03h				; Set the two low bits high
	out	SPEAKER_PORT, al		; Write the speaker register

done:
	pop	ax
	popf
	ret
SpeakerOn ENDP

SpeakerOff PROC

	pushf
	push	ax

	in	al, SPEAKER_PORT		; Read the speaker register
	and	al, 0FCh			; Clear the two low bits high
	out	SPEAKER_PORT, al		; Write the speaker register

	pop	ax
	popf
	ret
SpeakerOff ENDP

ConvertTempo PROC
	pusha

	call readTempo
	mov si, OFFSET tempo
	mov cl,0
	mov bx,0
	mov ax,0
	mov dx,0

Tem1:
	mov bl,[si]
	sub bl,30h
	shl bx,cl
	add ax,bx
	mov bx,0
	add cl,4
	inc si
	inc dx
	cmp dx,4
	jb Tem1

	mov Full_Tempo,ax
	call readnewline

	popa
	ret
ConvertTempo ENDP

ReadNoteSpeed PROC
        pushf

	cmp ah,'F'
	jne HalfNote
	mov dx,Full_Tempo
	mov WAITTIME,dx
	jmp EndofNotes
HalfNote:
	cmp ah,'H'
	jne QuarterNote
	mov dx,Full_Tempo
	mov WaitTime,dx
	mov cl,1h
	shr WaitTime,cl
	jmp EndofNotes

QuarterNote:
	cmp ah,'Q'
	jne EigthNote
	mov dx,Full_Tempo
	mov WaitTime,dx
	mov cl,02h
	shr WaitTime,cl
	jmp EndofNotes

EigthNote:
	cmp ah,'E'
	jne SixteenNote
	mov dx,Full_Tempo
	mov WaitTime,dx
	mov cl,03h
	shr WaitTime,cl
	jmp EndofNotes

SixteenNote:
	cmp ah,'S'
	jne EndofNotes
	mov dx,Full_Tempo
	mov WaitTime,dx
	mov cl,4
	shr WaitTime,cl

EndofNotes:
        popf
	ret
ReadNoteSpeed ENDP

Read_note PROC
        pushf

        mov ax,0
        mov ah,[si+1]
NoteA:
	cmp ah,'A'
	jne NoteB
	mov ax ,OFFSET A1
	mov bx,ax
	jmp done
NoteB:
	cmp ah,'B'
	jne NoteC
	mov ax, OFFSET B1
	mov bx,ax
	jmp done
NoteC:
	cmp ah,'C'
	jne NoteD
	mov ax,OFFSET C1
	mov bx,ax
	jmp done
NoteD:
	cmp ah,'D'
	jne NoteE
	mov ax,OFFSET D1
	mov bx,ax
	jmp done
NoteE:
	cmp ah,'E'
	jne NoteF
	mov ax,OFFSET E1
	mov bx,ax
	jmp done
NoteF:
	cmp ah,'F'
	jne NoteG
	mov ax,OFFSET F1
	mov bx,ax
	jmp done
NoteG:
	cmp ah,'G'
	jne done
	mov ax,OFFSET G1
	mov bx,ax
done:
        popf
	ret
Read_note ENDP

read_octave PROC
        pushf

        mov ax, 0
        mov ah, [si+2]
OCTAVE1:
	cmp ah,'1'
	jne OCTAVE2
	mov cl,0
	jmp done

OCTAVE2:
	cmp ah,'2'
	jne OCTAVE3
	mov cl,1
	jmp done

OCTAVE3:
	cmp ah,'3'
	jne OCTAVE4
	mov cl,2
	jmp done

OCTAVE4:
	cmp ah,'4'
	jne OCTAVE5
	mov cl,3
	jmp done

OCTAVE5:
	cmp ah,'5'
	jne OCTAVE6
	mov cl,4
	jmp done
OCTAVE6:
	cmp ah,'6'
	jne OCTAVE7
	mov cl,5
	jmp done
OCTAVE7:
	cmp ah,'7'
	jne OCTAVE8
	mov cl,6
	jmp done
OCTAVE8:
	cmp ah,'8'
	jne OCTAVE9
	mov cl,7
	jmp done
OCTAVE9:
	cmp ah,'9'
	jne OCTAVE10
	mov cl,8
	jmp done
OCTAVE10:
	cmp ah,'A'
	jne OCTAVE0
	mov cl,9
	jmp done
OCTAVE0:
	cmp ah,'0'
	jne done
	mov cl,1

done:
        popf
	ret
read_octave ENDP

findNoteNature PROC
        pushf

        mov ax, 0
SharpNote:
        mov ah,[si+3]
        cmp ah,'R'
        jne FlatNote
        mov ax,0
        mov ax,[bx+2]
        mov bx,ax
        jmp done
FlatNote:
        mov ax,0
        cmp ah,'b'
        jne NormalNote
        mov ax,0
        mov ax,[bx+4]
        mov bx,ax
        jmp done
NormalNote:
        mov ax, 0
        mov ax,[bx]  ;Move counts into ax
        mov bx,ax    ;bx has the number of counts
done:
        popf
        ret
findNoteNature ENDP

PlayFrequency PROC
	;; Frequency is found in AH
        pushf

        mov     dx, ax

        mov	al, READY_TIMER			; Get the timer ready
	out	TIMER_CONTROL_PORT, al

	mov	al, dl
	out	TIMER_DATA_PORT, al		; Send the count low byte

	mov	al, dh
	out	TIMER_DATA_PORT, al		; Send the count high byte

        popf
	ret
PlayFrequency ENDP

playSong PROC
        pushf
        pusha

        call getfilename
        call openthisfile

        call SpeakerOn
        call ConvertTempo
top:
        call readANote
        cmp bytesread,0
        je done

	cmp bytesread, 78
	jne continue
	call readnewline
	mov bytesread, 0
continue:
        mov si, OFFSET buffer   ; grab a note to play
        mov ax, 0
        mov ah, [si]

        cmp ah, '0'             ; check if we are at the end of file
        jne cont            ; if so exit
        mov ah,[si+2]
        cmp ah,'0'
        jne cont
        jmp done

cont:
        call ReadNoteSpeed

        call Read_note
        call findNoteNature

        call read_octave
        cmp ah,'0'
        jne RightShift

LeftShift:
        shl bx,cl
        mov ax,bx
        jmp SpeakerOut

RightShift:
        shr bx,cl
        mov ax,bx

SpeakerOut:
        call PlayFrequency

        mov ax, WaitTime
        call Delay

        mov ax,20h

        call SpeakerOff
        call Delay
        call SpeakerOn

        jmp top

done:
        call SpeakerOff

        popa
        popf
        ret
playSong ENDP

main PROC
	mov ax,@data
	mov ds,ax

        call playsong

	mov ax,4C00h
	int 21h
main ENDP
END main
