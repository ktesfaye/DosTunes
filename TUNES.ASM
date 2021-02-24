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

BIOS_READCURSOR	        = 03h
BIOS_WRITECURSOR	= 02h

.data
space 			WORD 0
xpos 			BYTE 0
ypos 			BYTE 0
oldpos 			WORD 0
num 			BYTE 0

filehandle 		WORD ?
filename 		BYTE 260 dup(0)
error   		BYTE "This file does not exist", 0
ferror 			BYTE "This file didn't close properly", 0

Cn			WORD	4572
Csh			WORD	4308
Dn			WORD	4058
Dsh			WORD	3836
Dp			WORD	4308
En			WORD	3620
Eb			WORD	3836
Fn			WORD	3426
Fsh			WORD	3225
Gn			WORD	3043
Gsh			WORD	2873
Gb			WORD	3225
An			WORD	2711
Ash			WORD	2556
Ab			WORD	2873
Bn			WORD	2416
Bb			WORD	2556
.code

;///////////////////////////////////////////////////////////////////////////////
;	Get a file from command line and read bytes in
;///////////////////////////////////////////////////////////////////////////////

openfil PROC
	push ax
	push dx
	call cmdin

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
openfil ENDP

closefil PROC
	push ax
	push dx

	mov ax, CLOSEFILE		; call sys intrupt to close a file
	mov bx, filehandle 		; take the filename from the data

	int DOS
	jc err

	mov filehandle, ax		; save the file handle
	jmp done
err:
	mov dx, OFFSET ferror
	call WriteString
done:
	pop dx
	pop ax
	ret
closefil ENDP

cmdin PROC
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
cmdin ENDP

;///////////////////////////////////////////////////////////////////////////////
;	Turn on/off the speaker
;///////////////////////////////////////////////////////////////////////////////
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

;///////////////////////////////////////////////////////////////////////////////
;	Frequency stuff
;///////////////////////////////////////////////////////////////////////////////
.data
BPM	  WORD 0
tempo	  BYTE 10 DUP(0) 			; Buffer used when reading file
bytesread WORD 0 			; Helps to get BPM from top of file

.code
getTempo PROC
	pushf
	push 	ax
	push	bx
	push	cx
	push	dx

	mov	ax, 0
	mov 	ah,03Fh
	mov 	bx,filehandle
	mov 	cx,04h
	mov 	dx,OFFSET tempo
	int 	DOS
	mov 	bytesread, ax

done:
	pop	dx
	pop	cx
	pop	bx
	pop 	ax
	popf
	ret
getTempo ENDP

.data
fastestNote	BYTE 	8
full_tempo	WORD	0
.code
convertTempo 	PROC
	pushf
	push	ax
	push	dx

	call	getTempo
	mov 	ax, 60000000
	mov 	dx, OFFSET tempo
	div 	dx

	mov 	dx, OFFSET fastestNote
	div	dx

	mov	dx, OFFSET full_tempo
	mov	dx, ax

	pop	dx
	pop	ax
	popf
	ret
convertTempo ENDP

.data
noteRead	BYTE 5 dup(0)
.code
readNote PROC
readonebyte PROC
	push 	ax
	push 	bx
	push 	cx
	push 	dx

	mov 	ax, READFILE
	mov 	bx,filehandle
	mov 	cx,06h
	mov 	dx,OFFSET noteRead
	int 	DOS
	mov 	bytesread,ax
	ret
readonebyte ENDP
readNote ENDP

.data
noteSpeed	BYTE	0
.code
findNoteSpeed PROC
	pushf
	push	ax
	push	bx
	push	di
	push	si
	push	dx

	mov	bx, OFFSET noteRead
	mov	ax, OFFSET tempo
	mov	di, OFFSET noteSpeed
	mov	si, 0
eigthNote:
	mov	cl, 8
	cmp	cl, ah		;Check for 8th note
	jne	quarterNote
	mul	cl
	mov	di, ax
	jmp	done
quarterNote:
	mov	cl, 4
	cmp	cl, ah		;check for qurter note
	jne	halfNote
	mul	cl
	mov	di, ax
	jmp	done
halfNote:
	mov	cl, 2
	cmp	cl, ah		;check for half note
	jne 	wholeNote
	mul	cl
	mov	di, ax
	jmp	done
wholeNote:
	mov	cl, 1
	cmp	cl, ah		;check for hole note
	mul	cl
	mov	di, ax
done:
	pop	dx
	pop	si
	pop	di
	pop	bx
	pop	ax
	popf
	ret
findNoteSpeed ENDP

.data
temp		BYTE	3 dup(0)
foundFrequency	BYTE	0
.code
findNoteFreq PROC
	pushf
	push ax
	push cx
	push dx

	; mov	bx, OFFSET noteRead
;///////////////////////////////////////////////////////////////////////////////
NoteA:
	cmp ah,'A'
	jne NoteB
	mov ax ,OFFSET An
	mov bx,ax
	jmp done
;///////////////////////////////////////////////////////////////////////////////
NoteB:
	cmp ah,'B'
	jne NoteC
	mov ax, OFFSET Bn
	mov bx,ax
	jmp done
;///////////////////////////////////////////////////////////////////////////////
NoteC:
	cmp ah,'C'
	jne NoteD
	mov ax,OFFSET Cn
	mov bx,ax
	jmp done
;///////////////////////////////////////////////////////////////////////////////
NoteD:
	cmp ah,'D'
	jne NoteE
	mov ax,OFFSET Dn
	mov bx,ax
	jmp done
;///////////////////////////////////////////////////////////////////////////////
NoteE:
	cmp ah,'E'
	jne NoteF
	mov ax,OFFSET En
	mov bx,ax
	jmp done
;///////////////////////////////////////////////////////////////////////////////
NoteF:
	cmp ah,'F'
	jne NoteG
	mov ax,OFFSET Fn
	mov bx,ax
	jmp done
;///////////////////////////////////////////////////////////////////////////////
NoteG:
	cmp ah,'G'
	jne done
	mov ax,OFFSET Gn
	mov bx,ax
;///////////////////////////////////////////////////////////////////////////////
done:
	pop dx
	pop cx
	pop ax
	popf
	ret
findNoteFreq ENDP

PlayFrequency PROC
	;; Frequency is found in DX

	pushf
	push	ax

	mov	al, READY_TIMER			; Get the timer ready
	out	TIMER_CONTROL_PORT, al

	mov	al, dl
	out	TIMER_DATA_PORT, al		; Send the count low byte

	mov	al, dh
	out	TIMER_DATA_PORT, al		; Send the count high byte

	pop	ax
	popf
	ret
PlayFrequency ENDP

playSong PROC
	pushf
	push	ax
	push	dx

	call	cmdin
	call	OpenFil

	call	SpeakerOn
top:
	call	convertTempo

	call	readNote
	cmp	bytesRead, 0
	je	done

	cmp	ax, 0
	je	done

	call	findNoteFreq
	call	findNoteSpeed
	call	convertTempo

	mov	ax, OFFSET noteSpeed
	call	Delay
	mov	dx, OFFSET foundFrequency
	call	PlayFrequency
	jmp	top

done:
	call	closeFil
	call	SpeakerOff

	pop	dx
	pop	ax
	ret
playSong ENDP

;///////////////////////////////////////////////////////////////////////////////
;	Cursor munpliation
;///////////////////////////////////////////////////////////////////////////////

getCursor PROC
	push ax
	push bx
	push cx

	mov ah,3
	mov bh,0
	int 10h

	pop cx
	pop bx
	pop ax
	ret
getCursor ENDP

SetCursor PROC
;Set the cursor to the top right poistion
        pushf
        push 	ax
        push 	bx
        push 	cx

	mov 	bh, 0
        mov 	ah, BIOS_WRITECURSOR
        int 	BIOS

        pop 	cx
        pop 	bx
        pop 	ax
        popf
        ret
SetCursor ENDP

RestoreCursor PROC
;restore the old cursor position
        pushf
        push 	ax
        push 	bx
        push 	cx
        push 	dx

        mov 	dh, OLDCURSOR_ROW
        mov 	dl, OLDCURSOR_COLUMN

	mov 	bh, 0
        mov 	ah, BIOS_WRITECURSOR
        int 	BIOS

        pop 	dx
        pop 	cx
        pop 	bx
        pop 	ax
        popf
        ret
RestoreCursor ENDP

AdvanceCursor PROC
; Advances the cursor one space forward.
	push	ax
	push	bx
	push	cx
	push	dx
	pushf

	mov	bh, 0			; BH = video page
	mov	ah, BIOS_READCURSOR	; AH = interrupt
	int	BIOS			; DH = row, DL = column

	inc	DL			; DL = new column
	mov	ah, BIOS_WRITECURSOR	; AH = interrupt
	int	BIOS

	popf
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
AdvanceCursor ENDP

.data
OLDCURSOR_ROW    BYTE 4 dup(0), 0
OLDCURSOR_COLUMN BYTE 4 dup(0), 0
.code
SaveCursor PROC
;save the old cursor position
        pushf
        push 	ax
        push 	bx
        push 	cx
        push 	dx

        mov 	bh, 0
        mov 	ah, BIOS_READCURSOR
        int 	BIOS

        mov 	OLDCURSOR_ROW, dh
        mov 	OLDCURSOR_COLUMN, dl

        pop 	dx
        pop 	cx
        pop 	bx
        pop 	ax
        popf
        ret
SaveCursor ENDP

;///////////////////////////////////////////////////////////////////////////////
;	Delay
;///////////////////////////////////////////////////////////////////////////////

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

;///////////////////////////////////////////////////////////////////////////////
;	Video modes
;///////////////////////////////////////////////////////////////////////////////

;; Returns:
;; 	AL - Video Mode
;; 	AH - Number of character columns
;; 	BH - Active Page
.data
OldVideoMode	BYTE 0
.code
GetVideoMode PROC
	push	cx
	push	ax

	mov	ah, 0fh
	int	BIOS
	; mov	cl, al
	mov	OldVideoMode, al

	pop	ax
	; mov	al, cl
	pop	cx
	ret
GetVideoMode ENDP

;; AL - Video mode
SetVideoMode PROC
	push	ax

	mov	ah, 00
	int	BIOS

	pop	ax
	ret
SetVideoMode ENDP

;; BH - Page number
;; CX - X
;; DX - Y
;;
;; Returns:
;;
;; AL - Color

ReadPixel PROC
	push	ax

	mov	ah, 0dh
	int	BIOS

	pop	ax
	ret
ReadPixel ENDP

;; AL - Color
;; BH - Page
;; CX - X
;; DX - Y
WritePixel PROC
	push	ax

	mov	ah, 0fch
	int	BIOS

	pop	ax
	ret
WritePixel ENDP

;; BL - Palette id

SetPalette PROC
	push	ax
	push	bx

	mov	ah, 0bh
	mov	bh, 01h
	int	BIOS

	pop	bx
	pop	ax
	ret
SetPalette ENDP


;; AL - Pallete Index
;; AH - Red
;; CX - Blue:Green

SetPalleteColor PROC
	push	ax
	push	dx

	mov	dx, 3c8h	; Video pallete port
	out	dx, al		; Write the color out

	mov	dx, 3c9h	; Color selection port

	mov	al, ah		; Red
	out	dx, al
	mov	al, cl		; Green
	out	dx, al
	mov	al, ch		; Blue
	out	dx, al

	pop	dx
	pop	ax
	ret
SetPalleteColor ENDP

;; BX - Color Index
;; CX - X
;; DX - Y
DrawPixel PROC
	;; Screen resolution is 320x200

	push	ax
	push	dx
	push	di
	push	es

	mov	ax, 320
	mul	dx		; AX = 320 * Y
	add	ax, cx		; AX = 320 * Y + X

	mov	di, ax		; Set di to the offset

	push	0A000h		; Set ES to the video segment
	pop	es

	mov	BYTE PTR es:[di], bl ; Set the pixel to the given color

	pop	es
	pop	di
	pop	dx
	pop	ax
	ret
DrawPixel ENDP

;///////////////////////////////////////////////////////////////////////////////
;		Draw Piano Keys
;///////////////////////////////////////////////////////////////////////////////


drawPiano PROC
	push ax
	push bx
	push cx
	push dx
	pushf

	; Save the Cursor
	call SaveCursor

	; Draw Borders
	mov cs:xpos,0
	mov cs:ypos,0
	call drawLine

	;------------------------------MAKE KEYS----------------------
	call DrawKeys
	mov cs:space,0

	; ;-----------------------------LABEL NOTES---------------------
	mov cs:xpos,1
	mov cs:ypos,0
	call labelNotes

	;-------------------------------------------------------------

	mov cs:space,0

	; mov dx,cs:oldpos
	; call setCursor
	call RestoreCursor

	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
;---------------------------------------------------------PIANO DRAW---
drawPiano ENDP

drawKeys PROC
	push dx
	pushf

	mov dh,1
	mov dl,0
keys:	call drawVert
	inc dl
	call drawWhite
	inc dl
	call drawBlack
	inc dl
	call drawWhite
	inc dl
	call drawBlack
	inc dl
	call drawWhite
	inc dl
	call drawVert
	inc dl
	call drawWhite
	inc dl
	call drawBlack
	inc dl
	call drawWhite
	inc dl
	cmp dl,80
	jge done
	call drawBlack
	inc dl
	call drawWhite
	inc dl
	call drawBlack
	inc dl
	call drawWhite
	inc dl
	jmp keys

done:	popf
	pop dx
	ret
drawKeys ENDP

labelNotes PROC
	push ax
	push bx
	push cx
	push dx
	pushf

	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor

	mov cs:num,'C'
L1:	cmp dl,80
	jge done
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,00011011b	; yellow text on blue
	int 10h

	mov ah,9
	mov al,cs:num
	mov cx,1
	int 10h

	inc cs:num
	cmp cs:num,'H'
	jnz sev
	mov cs:num,'A'

sev:	mov dh,cs:ypos
	add cs:xpos,2
	mov dl,cs:xpos
	call setCursor
	jmp L1

done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
labelNotes ENDP

drawBlack PROC
	push ax
	push bx
	push cx
	push dx
	pushf

	mov cs:ypos,dh
	mov cs:xpos,dl
	call setCursor

L1:	cmp cs:space,4
	jge next	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,0Fh	; blue
	int 10h

	mov ah,9
	mov al,' '
	mov cx,1
	int 10h

	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor

	inc cs:space
	jmp L1
next:	mov cs:space,0

L2:	cmp cs:space,3
	jge done	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,70h	; blue
	int 10h

	mov ah,9
	mov al,179
	mov cx,1
	int 10h

	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor

	inc cs:space
	jmp L2

done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawBlack ENDP

drawBack PROC
	push ax
	push bx
	push cx
	push dx
	pushf

	mov cs:ypos,dh
	mov cs:xpos,dl
	call setCursor

L1:	cmp cs:space,4
	jge next	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,0Ah	; cyan highlight
	int 10h

	mov ah,9
	mov al,219
	mov cx,1
	int 10h

	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor

	inc cs:space
	jmp L1
next:	mov cs:space,0

L2:	cmp cs:space,3
	jge done	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,70h	; blue
	int 10h

	mov ah,9
	mov al,179
	mov cx,1
	int 10h

	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor

	inc cs:space
	jmp L2

done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawBack ENDP

drawWhite PROC
	push ax
	push bx
	push cx
	push dx
	pushf

	mov cs:ypos,dh
	mov cs:xpos,dl
	call setCursor

L1:	cmp cs:space,7
	jge done	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,70h	; white
	int 10h

	mov ah,9
	mov al,' '
	mov cx,1
	int 10h

	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor

	inc cs:space
	jmp L1

done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawWhite ENDP

drawYell PROC
	push ax
	push bx
	push cx
	push dx
	pushf

	mov cs:ypos,dh
	mov cs:xpos,dl
	call setCursor

L1:	cmp cs:space,7
	jge done	; done with divider
	;-----------------------------------------BLUE LINE------
	mov ah,0Bh
	mov bh,0
	mov bl,0Ah	; red on red
	int 10h

	mov ah,9
	mov al,219
	mov cx,1
	int 10h

	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor

	inc cs:space
	jmp L1

done:	mov cs:space,0
	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawYell ENDP

drawVert PROC
	push ax
	push bx
	push cx
	push dx
	pushf

	mov cs:ypos,dh
	mov cs:xpos,dl
	call setCursor

L1:
	cmp cs:space,7
	jge done	; done with divider
	; Black separator line
	mov ah,0Bh
	mov bh,0
	mov bl,01110000b	; lightgray
	int 10h

	mov ah,9
	mov al,179				; Draw '|'
	mov cx,1
	int 10h

	inc cs:ypos
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor

	inc cs:space
	jmp L1

done:
	mov cs:space,0

	popf
	pop dx
	pop cx
	pop bx
	pop ax
	ret
drawVert ENDP

drawLine PROC
	pushf
	push 	ax
	push 	bx
	push 	cx

	; call	GetVideoMode
; 	push	ax
; 	mov	al, 13h		; 320x200 x 256 colors
; 	call	SetVideoMode
;
; 	mov	al, 1		; Set pallete color 1
; 	mov	ah, 0fh		; Red
; 	mov	cx, 00000h	; CH: Blue, CL: Green
; 	call	SetPalleteColor
;
; 	mov	bx, 1		; Pallete
; 	mov	cx, 0		; X
; 	mov	dx, 0		; Y
; 	jmp	loopcond
; top:
; 	call	DrawPixel
;
; 	inc	cx
; loopcond:
; 	cmp	cx, 2560
; 	jl	top
	mov dh,cs:ypos
	mov dl,cs:xpos
	call setCursor

L1:
	cmp cs:space,80
	jge done		; When you reach the border stop

	mov ah,0Bh
	mov bh,0
	mov bl,11h	; blue
	int 10h

	mov ah,9
	mov al,' '
	mov cx,1
	int 10h

	mov dh,cs:ypos
	inc cs:xpos
	mov dl,cs:xpos
	call setCursor

	inc cs:space
	jmp L1

done:	mov cs:space,0

	;
	; mov	ax, 5000
	; call	Delay

	; pop	ax
	;call	SetVideoMode	; Restore the video mode

	pop	cx
	pop	bx
	pop	ax
	popf
	ret
drawLine ENDP

;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////

main PROC
	mov ax, @data
	mov ds, ax

	; call playsong
	call drawpiano

	; loop	lp

	mov ax, DOSEXIT
	int DOS
	ret
main ENDP
END main
