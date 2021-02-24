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

BIOS_READCURSOR	        = 03h
BIOS_WRITECURSOR	= 02h

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

noteLocation		WORD 0
OldVideoMode		WORD 0

error   		BYTE "Error finding the file", 0


A4                      WORD  54BEh,4FFCh,59C8h
B4                      WORD  4B7Fh,0000h,4FFCh
C4                      WORD  8E85h,8685h
D4                      WORD  7EF8h,77DBh,8685h
E4                      WORD  711Eh,0000h,77DBh
F4                      WORD  6AC4h,64C7h
G4                      WORD  5F23h,59C8h,64C7h

.code

;///////////////////////////////////////////////////////////////////////////////
;       Delay
;///////////////////////////////////////////////////////////////////////////////

Delay PROC
	push cx		
	push bx
	push dx
	pushf

	mov bx,10
	mov dx,0
	div bx

	cmp ax,0
	jz done

	push ax
        mov ah,2Ch
	int DOS
	pop ax

	mov bh,dl

top:	push ax
	mov ah,2Ch
	int DOS
	pop ax
pass:	cmp bh,dl
	jz top
	mov bl,dl
	jl less
	add dl,100
less:	sub dl,bh
	mov dh,0
	sub ax,dx
	mov bh,bl
	cmp ax,0
	jle done
	jmp top

done:	popf
	pop dx
	pop bx
	pop cx
	ret
Delay ENDP

;///////////////////////////////////////////////////////////////////////////////
;       File handling
;///////////////////////////////////////////////////////////////////////////////

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

	mov ax, OldVideoMode
	call SetVideoMode

        mov ax, DOSEXIT
        int DOS
done:
        pop dx
        pop ax
        ret
openthisfile ENDP

;///////////////////////////////////////////////////////////////////////////////
;       Handle reading in
;///////////////////////////////////////////////////////////////////////////////

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
         int DOS
         mov bytesread, ax      ;store the no of bytes read

         popa
         ret
readANote ENDP

readTempo PROC
        pusha

	mov ax,READFILE
	mov bx,filehandle
	mov cx,04h
	mov dx, OFFSET tempo
	int DOS
	mov bytesread,ax

        popa
        ret
readTempo ENDP

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

;///////////////////////////////////////////////////////////////////////////////
;       Handle speaker
;///////////////////////////////////////////////////////////////////////////////

SpeakerOn PROC
	pushf
	push	ax

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
;       Handle note
;///////////////////////////////////////////////////////////////////////////////

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
	mov ax ,OFFSET A4
	mov bx,ax
	mov noteLocation, 240
	jmp done
NoteB:
	cmp ah,'B'
	jne NoteC
	mov ax, OFFSET B4
	mov bx,ax
	mov noteLocation, 260
	jmp done
NoteC:
	cmp ah,'C'
	jne NoteD
	mov ax,OFFSET C4
	mov bx,ax
	mov noteLocation, 140
	jmp done
NoteD:
	cmp ah,'D'
	jne NoteE
	mov ax,OFFSET D4
	mov bx,ax
	mov noteLocation, 160
	jmp done
NoteE:
	cmp ah,'E'
	jne NoteF
	mov ax,OFFSET E4
	mov bx,ax
	mov noteLocation, 180
	jmp done
NoteF:
	cmp ah,'F'
	jne NoteG
	mov ax,OFFSET F4
	mov bx,ax
	mov noteLocation, 200
	jmp done
NoteG:
	cmp ah,'G'
	jne done
	mov ax,OFFSET G4
	mov bx,ax
	mov noteLocation, 220
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
        cmp ah,'S'
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

;///////////////////////////////////////////////////////////////////////////////
;       Handle song playing
;///////////////////////////////////////////////////////////////////////////////

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

	cmp ah, 'R'
	jne RestNote
	mov ax, WaitTime
	shr ax, 4
        call Delay

	mov ax,20h
        call Delay
	jmp top
RestNote:
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
        ; mov ax, WaitTime
        ; call Delay
 	call highlightNote

	;
        call SpeakerOff

	mov ax,20h
        call Delay

        call SpeakerOn

	; push cx
	; mov cx, 20
	; pop cx
        jmp top

done:
        call SpeakerOff

        popa
        popf
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
;	Video modes
;///////////////////////////////////////////////////////////////////////////////

GetVideoMode PROC
	push	cx
	push	ax

	mov	ah, 0fh
	int	BIOS
	mov	cl, al

	pop	ax
	mov	al, cl
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

;///////////////////////////////////////////////////////////////////////////////
;	Pixel Manupilation
;///////////////////////////////////////////////////////////////////////////////

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
;	Palatte setup
;///////////////////////////////////////////////////////////////////////////////

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

;///////////////////////////////////////////////////////////////////////////////
;	Draw the actuall piano
;///////////////////////////////////////////////////////////////////////////////

drawPiano PROC
        pusha

        call	GetVideoMode
        push	ax
        mov	al, 13h		; 320x200 x 256 colors
        call	SetVideoMode

	call	drawlayout

        mov	al, 1		; Set pallete color 1
        mov	ah, 255	; Red
        mov	ch, 255	; CH: Blue, CL: Green
	mov	cl, 255
        call	SetPalleteColor

	call	drawkeys

	; mov	ax, 3000
	; call	Delay
	call	PlaySong

;        mov     ax, 5000
 ;       call    Delay

        pop	ax
	mov	OldVideoMode, ax
	call	SetVideoMode

        popa
        ret
drawPiano ENDP

;///////////////////////////////////////////////////////////////////////////////
;	Piano key stuff
;///////////////////////////////////////////////////////////////////////////////

drawkeys PROC
	pushf
	push	cx
	push	si

	mov	cx, 0		; X
	mov	dx, 0		; Y

	call	drawhori

	call	drawvert
	; call	highlightNote

	push	cx
	mov	cx, 15
	call	drawblack
	pop	cx

	add	cx, 20
	mov	dx, 0

	call	drawvert
	push	cx
	mov	cx, 35
	call	drawblack
	pop	cx

	add	cx, 20
	mov	dx, 0

	call	drawvert

	add	cx, 20
	mov	dx, 0

	call	drawvert
	push	cx
	mov	cx, 75
	call	drawblack
	pop	cx

	add	cx, 20
	mov	dx, 0

	call	drawvert
	push	cx
	mov	cx, 95
	call	drawblack
	pop	cx

	add	cx, 20
	mov	dx, 0

	call	drawvert
	push	cx
	mov	cx, 115
	call	drawblack
	pop	cx

	add	cx, 20
	mov	dx, 0

	call	drawvert

	add	cx, 20
	mov	dx, 0

	call	drawvert

	add	cx, 20
	mov	dx, 0

	call	drawvert

	add	cx, 20
	mov	dx, 0

	call	drawvert
	push	cx
	mov	cx, 155
	call	drawblack
	pop	cx

	add	cx, 20
	mov	dx, 0

	call	drawvert
	push	cx
	mov	cx, 175
	call	drawblack
	pop	cx

	add	cx, 20
	mov	dx, 0

	call	drawvert
	push	cx
	mov	cx, 215
	call	drawblack
	pop	cx

	add	cx, 20
	mov	dx, 0

	call	drawvert
	push	cx
	mov	cx, 235
	call	drawblack
	pop	cx

	add	cx, 20
	mov	dx, 0

	call	drawvert
	push	cx
	mov	cx, 255
	call	drawblack
	pop	cx

	add	cx, 20
	mov	dx, 0

	call	drawvert

	add	cx, 20
	mov	dx, 0

	call	drawvert
	push	cx
	mov	cx, 295
	call	drawblack
	pop	cx

	add	cx, 20
	mov	dx, 0

	call	drawvert
	push	cx
	mov	cx, 315
	call	drawlastblack
	pop	cx

	call	savecursor

	mov	dl, 80
	call	setcursor

	call	drawhori
	call	RestoreCursor

	pop	si
	pop	cx
	popf
	ret
drawkeys ENDP

drawkeys? PROC
	pushf
	push	cx
	push	si

	mov	cx, 0		; X
	mov	dx, 0		; Y
lp:
	call	drawvert

	add	cx, 40
	mov	dx, 0

	inc	si
	cmp	si, 5
	jne	lp

	pop	si
	pop	cx
	popf
	ret
drawkeys? ENDP

drawhori PROC

	mov	bx, 180		; Pallete
	mov	si, 0
	jmp	loopcond2
top2:
	call	DrawPixel
	inc	cx
	inc	si
loopcond2:
	cmp	si, 2880
	jl	top2

	ret
drawhori ENDP

drawvert PROC

	mov	bx, 240		; Pallete
	mov	si, 0
	jmp	loopcond
top:
	call	DrawPixel
	inc	dx
	inc	si
loopcond:
	cmp	si, 84
	jl	top

	ret
drawvert ENDP

drawBvert PROC

	mov	bx, 245 		; Pallete
	mov	si, 0
	jmp	loopcond
top:
	call	DrawPixel
	inc	dx
	inc	si
loopcond:
	cmp	si, 50
	jl	top

	ret
drawBvert ENDP

drawlastblack PROC
	pusha

	mov	dx, 9
	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	popa
	ret
drawlastblack ENDP

drawblack PROC
	pusha

	mov	dx, 9
	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	add	cx, 1
	mov	dx, 9

	call	drawBvert

	popa
	ret
drawblack ENDP

drawlayout PROC
	pushf
	pusha

	; call	GetVideoMode
	; push	ax
	; mov	al, 13h		; 320x200 x 256 colors
	; call	SetVideoMode

	mov	al, 1		; Set pallete color 1
	mov	ah, 255	; Red
	mov	ch, 255	; CH: Blue, CL: Green
	mov	cl, 255
	call	SetPalleteColor

	mov	bx, 1		; Pallete
	mov	dx, 0		; Y
	mov	cx, 0		; X
	mov	si, 0
	jmp	loopcond2
top2:
	call	DrawPixel
	inc	cx
	inc	si
loopcond2:
	cmp	si, 30000
	jl	top2

	; mov     ax, 5200
	; call    Delay
	;
	; pop	ax
	; call	SetVideoMode

	popa
	popf
	ret
drawlayout ENDP

highlightNote PROC
	push	ax
	push	cx
	push	bx

	mov	cx, noteLocation
	push	cx
	mov	bx, 120
	call	drawGreen

	mov 	ax, WaitTime
	call 	Delay

	mov	bx, 1
	pop	cx
	call	drawGreen
	mov	noteLocation, 0

	pop	bx
	pop	cx
	pop	ax
	ret
highlightNote ENDP

drawGreen PROC
	pusha

	pusha
	call	drawKeys
	popa

	;add	cx, 4
	 mov	dx, 9
	 call	drawGVert

	 add	cx, 1
	 mov	dx, 9

	 call	drawGVert

	 add	cx, 1
	 mov	dx, 9

	 call	drawGVert
	;
	 add	cx, 1
	 mov	dx, 9

	call	drawGVert

	 add	cx, 1
	 mov	dx, 9
	;
	 call	drawGVert

	add	cx, 1
	mov	dx, 9

	call	drawGVert

	add	cx, 1
	mov	dx, 9

	call	drawGVert

	add	cx, 1
	mov	dx, 9

	call	drawGVert

	add	cx, 1
	mov	dx, 9

	call	drawGVert

	add	cx, 1
	mov	dx, 9

	call	drawGVert

	mov	dx, 9
	call	drawGVert

	add	cx, 1
	mov	dx, 9

	call	drawGVert

	add	cx, 1
	mov	dx, 9

	call	drawGVert

	add	cx, 1
	mov	dx, 9

	call	drawGVert

	add	cx, 1
	mov	dx, 9

	call	drawGVert

	add	cx, 1
	mov	dx, 9

	call	drawGVert

	 add	cx, 1
	 mov	dx, 9
	;
	 call	drawGVert
	;
	 add	cx, 1
	 mov	dx, 9
	;
	 call	drawGVert
	;
	 add	cx, 1
	 mov	dx, 9
	;
	 call	drawGVert
	;
	 add	cx, 1
	 mov	dx, 9
	;
	 call	drawGVert
	 add	cx, 1
	 mov	dx, 9
	;
	 call	drawGVert

	pusha
	call	drawkeys
	popa
	popa
	ret
drawGreen ENDP

drawGVert PROC

	mov	si, 0
	jmp	loopcond
top:
	call	DrawPixel
	inc	dx
	inc	si
loopcond:
	cmp	si, 81
	jl	top

	ret
drawGVert ENDP

;///////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////

main PROC
	mov ax,@data
	mov ds,ax

	call drawPiano

	mov ax,DOSEXIT
	int DOS
main ENDP
END main
