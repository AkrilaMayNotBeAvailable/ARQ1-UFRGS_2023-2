;;======================================================
;; Universidade Federal do Rio Grande do Sul - UFRGS
;; Arquitetura de Computadores 1 - 23/2
;; Trabalho INTEL 8086
;;======================================================
.model  small
.stack 1024
	CR					equ		0dh
	LF					equ		0ah
	LOW_TENSION			equ		7fh ; Hexadecimal correspondente ao 127
	; Ele não aceita sem o zero antes, maldito intel.
	HIGH_TENSION		equ		0dch	; Hexadecimal correspondente ao 220
	
.data
	stdInputFile 		db 	"a.in",0	; Entrada padrão
	stdOutputFile 		db 	"a.out",0	; Saída padrão

	;========================================================
	; Parafernalha para deixar bonitinho
	;========================================================
	linhaDeEquals		db	"=========================================", CR, LF, 0
	debugNotes			db	"--------- DEBUGGING DO PROGRAMA ---------", CR, LF, 0
	breakLine			db	CR, LF, 0
	labelInput			db	"Entrada: ", 0
	labelOutput			db	"Saida: ", 0
	labelTension		db	"Tensao: ", 0

	warnInputFile		db	"O arquivo a.in sera utilizado para essa execucao", CR, LF, 0
	warnOutputFile		db	"O arquivo a.out sera utilizado para essa execucao", CR, LF, 0
	warnTensionValue	db	"O valor de tensao 127 sera utilizado para essa execucao", CR, LF, 0

	erroOpen			db	"O arquivo de entrada informado nao existe", CR, LF, 0
	erroCreate			db	"O arquivo de saida nao pode ser criado", CR, LF, 0
	arquivoAbriu		db	"Arquivo de entrada carregado", CR, LF, 0
	arquivoCriado		db	"Arquivo de saida foi criado", CR, LF, 0
	linha				db	"Linha ", 0
	invalida 			db	" invalida: ", 0
	tempo 				db	"Tempo com tensao de qualidade: ",0
	timerSemTensao		db	"Tempo sem tensao nenhuma: ",0
	timerTotal			db	"Tempo total: ",0
	doisPontos			db	" : ",0
	;========================================================
	; Dado o enunciado, essas mensagens vão estar no programa, PORÉM
	; deixo **EXPLÍCITO** aqui a incoerência do mesmo, que na primeira página de instruções
	; indica que devem ser utilizadas informações padrão se os parâmetros não existirem
	; e na terceira página indica que essas mensagens devem ser informadas.
	;========================================================
	inputWithoutParameter		db "Opcao [-i] sem parametro", CR, LF, 0
	ouputWithoutParameter		db "Opcao [-o] sem parametro", CR, LF, 0
	tensionWithoutParameter		db "Opcao [-v] sem parametro", CR, LF, 0
	invalidTensionWarning		db "Parametro da opcao [-v] deve ser 127 ou 220", CR, LF, 0
	;========================================================
	
	handlerInputFile	dw 	0			; Handler do arquivo de entrada
	fileInputPtr		dw	0
	handlerOutputFile	dw 	0			; Handler do arquivo de saída

	cmdLine 			db 	256 dup (?)	; A string do CMD
	filenameInputFile	db 	256 dup (?) ; Nome do arquivo passado por parâmetro para busca de dados
	filenameOutputFile	db 	256 dup (?) ; Nome do arquivo passado por parâmetro para saída de dados
	tensionString		db 	128 dup (?) ; Valor de tensão que o usuário passou que ainda vai ser convertido
	lineBuffer			db	1024 dup (?) ; Buffer que armazena a linha a cada iteração de leitura
	tensionIntHex		dw 	0
	contaLinha			dw	0

	; Esses negócio são usados para guardar as informações dos fios a cada iteração
	char				db	10 dup (?)
	wireStr				db 	10 dup (?)
	wireOne				dw	-1
	wireTwo				dw	-1
	wireThree			dw	-1

	String				db	10 dup (?)
	sw_n				dw	0
	sw_f				db	0
	sw_m				dw	0

	lineError			dw	0
	seconds				dw	0 
	minutes				dw	0
	hours				dw	0

	seconds_noTension	dw	0
	minutes_noTension	dw	0
	hours_noTension		dw	0

	total_seconds		dw	0
	total_minutes		dw	0
	total_hours			dw	0
	
	;========================================================
	; Flags de verificação:
	;========================================================
	inputFlag			dw	0			; Flag que indica que existe arquivo de entrada informado por CMD
	outputFlag			dw	0			; Flag que indica que existe arquivo de saída informado por CMD
	tensionFlag			dw	0			; Aqui é pra já estar subentendido
	fimFlag				dw	0

	cmdLineSize			dw	0			; Tamanho da string de entrada no CMD

.code
.STARTUP
	call 	GetCommandLine					; Cata a string da command line
	call 	CommandLineSizeProcessing		; Processa ela :D

	cmp		tensionFlag, 0					; Se a flag estiver zerada, significa a tensão é o valor padrão
	je		skipTensionCheck				; Aí pula a verificação da tensão

	; Verifica a tensão dada pelo usuário, pois pode ser um valor inválido
	;--------------------------------------------------------------
	lea 	bx, tensionString
	call 	atoi
	call 	VerifyTension					; A verificação de tensão depende do retorno do atoi
	cmp 	ax, 0
	je		encerrarPrograma				; A tensão não é válida
	;--------------------------------------------------------------

skipTensionCheck:
	call	FopenInputFile		; Tenta abrir o arquivo de entrada
	cmp cx, 1					; Verifica a flag de erro
	je encerrarPrograma			; Se houve erro encerra.

	call ProcInputFile
	cmp lineError, 1
	je encerrarPrograma

	call 	DebugFunction
	
	call	FileCreateOutput	; Cria um arquivo de saída
	cmp cx, 1					; Testa se houve erro
	je encerrarPrograma			; Encerra

encerrarPrograma:
	.EXIT 0

;;============================================
; ProcInputFile();
;;============================================
ProcInputFile proc near
	proc_nextLine:
		lea di, lineBuffer			; Carrega o offset da linha do buffer

	loop_readFile:
		mov ah, 3fh					; Leitura de Arquivo
		mov bx, handlerInputFile	; Handle em BX
		mov cx, 1					; 1 byte por leitura
		lea dx, char				; Coloca o buffer como endereço de escrita
		int 21H						; Interrupt

		cmp ax, 1					; Verifica se copiou algo
		je	checkByteData			; Verifica o dado lido

		cmp ax, 0					; Indica EOF
		je	end_readFile			; Encerra a leitura por EOF

	checkByteData:
		mov al, char				; Cópia de char para al

		cmp 	al, CR			; - Achou um CR em Windows
		je		loop_readFile	; Faz isso para pular para o LF e cair no caso de baixo
		cmp 	al, LF			; - Unix-Sys / Windows, ao encontrar, envia para futuro processamento
		je		ProcessLine		; Processamento
		cmp 	al, "	"		; - Skip leituras com tab
		je		loop_readFile	; Estou ignorando o caso de haver um tab entre os números.
		cmp 	al, " "			; - Skip leituras com espaço
		je		loop_readFile	; Ignora espaço entre números
		cmp 	al, "f"			; - Se encontrar um f qualquer eu vou encerrar o programa
		je		end_ProcInput	;----------------------
		cmp 	al, "F"			; Insensível ao caso
		je		end_ProcInput	;----------------------

		; Caso padrão, onde alguma coisa é copiada para o buffer de arquivo e depois processada
		mov [di], al			; Copia o valor lido do arquivo para o buffer
		inc di					; Atualiza o ponteiro

		jmp loop_readFile		; Vai para a próxima leitura

		ProcessLine:
			inc contaLinha
			mov [di], al				; Manda o LF para o buffer
			call BufferProcess			; Chama outra função para processar o buffer
			inc di						; Atualiza o ponteiro

			jmp proc_nextLine

	end_readFile:
		inc contaLinha
		call BufferProcess			; Chama outra função para processar o buffer
	end_ProcInput:
		;lea		bx, lineBuffer
		;call 	printf

		mov		bx, handlerInputFile 	; Manda o handle para BX
		mov		ah, 3eh					; Fecha o handle
		int 	21H						; Interrupt

		ret
ProcInputFile endp

;;============================================
; BufferLineProcessing();
;;============================================
BufferProcess proc near
	lea si, lineBuffer

	next_iteration:
		lea bx, wireStr

	loop_copy:
		mov al, [si] 		; Manda o primeiro byte de CX para o al

		cmp al, ","			; strtok
		je	convertVal		; Envia para o atoi realizar a conversão

		cmp al, LF			; Após o terceiro valor, temos uma quebra de linha.
		je convertVal		; O valor ainda precisa ser convertido

		cmp al, 0			; Após o terceiro valor, pode ter um EOF.
		je convertVal		; O valor ainda precisa ser convertido

		mov [bx], al		; Manda o al para o bx
		inc bx				; Atualiza bx
		inc si				; Atualiza cx
		jmp loop_copy

	convertVal:
		mov	byte ptr [bx],0

		lea bx, wireStr
		call atoi

		cmp wireOne, -1
		je primeiroFio

		cmp wireTwo, -1
		je segundoFio

		cmp wireThree, -1
		je terceiroFio

		jmp end_BufferProcessing
	
	primeiroFio:
		mov wireOne, ax 		; Manda ax para o fio
		inc si					; Pula a virgula
		jmp next_iteration

	segundoFio:
		mov wireTwo, ax 		; Manda ax para o fio
		inc si					; Pula a virgula
		jmp next_iteration

	terceiroFio:
		mov wireThree, ax 		; Manda ax para o fio
		inc si

	call VerifyTensionValidation
	cmp cx, 0
	je end_BufferProcessing

	;==========================
	lea bx, linha
	call printf

	mov ax, contaLinha	; Linha atual
	lea bx, string		; String buffer de sprintf
	call sprintf_w		; Conversão

	lea bx, string
	call printf

	lea bx, invalida
	call printf

	lea bx, lineBuffer
	call printf

	mov lineError, 1
	;==========================

	end_BufferProcessing:
		mov wireOne, -1
		mov wireTwo, -1
		mov wireThree, -1

	ret

BufferProcess endp


VerifyTensionValidation proc near
	mov cx, 0

	VerificaValidadeFioUm:
		cmp wireOne, 0		; Comparação com zero
		jl invalidLine		; Sem valor ou valor negativo, sem tensão ou inválido
		cmp wireOne, 499	; Comparação com o máximo
		jg invalidLine		; Valor acima do esperado

	VerificaValidadeFioDois:
		cmp wireTwo, 0		; Comparação com zero
		jl invalidLine		; Sem valor ou valor negativo, sem tensão ou inválido
		cmp wireTwo, 499	; Comparação com o máximo
		jg invalidLine		; Valor acima do esperado

	VerificaValidadeFioTres:
		cmp wireThree, 0	; Comparação com zero
		jl invalidLine		; Sem valor ou valor negativo, sem tensão ou inválido
		cmp wireThree, 499	; Comparação com o máximo
		jg invalidLine		; Valor acima do esperado

	semTensaoFioUm:
		cmp wireOne, 10
		jg	withTension
	
	semTensaoFioDois:
		cmp wireTwo, 10
		jg	withTension
	
	semTensaoFioTres:
		cmp wireThree, 10
		jg	withTension

		jmp noTensionUpdate

	withTension:
		cmp tensionIntHex, LOW_TENSION
		jne _highTension

	; Verifica se a tensão é de qualidade nos fios
	TensaoBaixaFioUm:
		cmp wireOne, 117
		jl	redirect
		cmp wireOne, 137
		jg	redirect
	
	TensaoBaixaFioDois:
		cmp wireTwo, 117
		jl	redirect
		cmp wireTwo, 137
		jg	redirect
	
	TensaoBaixaFioTres:
		cmp wireThree, 117
		jl	redirect
		cmp wireThree, 137
		jg	redirect

		jmp validLine_withTension

	_highTension:
		TensaoAltaFioUm:
			cmp wireOne, 210
			jl	redirect
			cmp wireOne, 230
			jg	redirect
	
		TensaoAltaFioDois:
			cmp wireTwo, 210
			jl	redirect
			cmp wireTwo, 230
			jg	redirect
		
		TensaoAltaFioTres:
			cmp wireThree, 210
			jl	redirect
			cmp wireThree, 230
			jg	redirect

			jmp validLine_withTension

	noTensionUpdate:
	; Clock without tension
		inc seconds_noTension
		cmp seconds_noTension, 60
		jne redirect

	skipMinutes_noTension_Update:
		inc minutes_noTension
		mov seconds_noTension, 0
		cmp minutes_noTension, 60
		jne	redirect

	skipHours_noTension_Update:
		inc hours_noTension
		mov minutes_noTension, 0
		jmp redirect
	
	; Atualiza o clock
	validLine_withTension:
		inc seconds
		cmp seconds, 60
		jne redirect

	skipMinutesUpdate:
		inc minutes
		mov seconds, 0
		cmp minutes, 60
		jne	redirect

	skipHoursUpdate:
		inc hours
		mov minutes, 0
		jmp redirect

	redirect:
	; Atualiza o clock total de tensão
	updateTotalTimer_sec:
		inc total_seconds
		cmp total_seconds, 60
		jne validLine

	updateTotalTimer_min:
		inc total_minutes
		mov total_seconds, 0
		cmp total_minutes, 60
		jne	validLine

	updateTotalTimer_hour:
		inc total_hours
		mov total_minutes, 0
		jmp validLine

	invalidLine:
		mov cx, 1

	validLine:
		ret

VerifyTensionValidation endp

;;============================================
; CommandLineSizeProcessing();
;	Armazena o tamanho da string presente em cmdLine
;	e envia para o processamento de parâmetros
;;============================================
CommandLineSizeProcessing proc near
	mov	cx, 0                ; Tamanho da string
	lea si, cmdLine			 ; Inicializa o ponteiro na string dada por CMD

	loop_CommandLineProc:
		cmp BYTE PTR [SI], 0	 		; Procura pelo '\0'
		je  loop_CommandLineProc_end	; Se encontrou o '\0', pula para próxima função                            
		inc CX                  		; Aumenta o tamanho em 1
		inc SI                   		; Atualiza o ponteiro
		jmp loop_CommandLineProc 		; Faz novamente

	loop_CommandLineProc_end:
		mov     cmdLineSize, cx						; Guarda o tamanho da string
		call    CommandLineProcessing_Second_Phase  ; Subrotina de processamento de linha de comando
		ret											; Retorno

CommandLineSizeProcessing endp

;;============================================
; CommandLineProcessing_Second_Phase()
;	Após pegar a linha de comando, processa ela da seguinte forma:
;		Procura por traço -> Verifica opção -> Procura mais traços
;	-i <nome_de_um_arquivo_de_entrada>
;	-o <nome_de_um_arquivo_de_saida>
;	-v <valor_inteiro_de_tensao>
;;============================================
CommandLineProcessing_Second_Phase proc near
	lea     di, cmdLine		; Inicializa a entrada DI
	mov     cx, cmdLineSize ; Coloca o tamanho em CX
	
	ProcuraParametro:
        mov     ah, 0
        mov     al, '-'			; Busca por '-' na string 

        repne   scasb           ; Repete o processo até encontrar ou acabar o tamanho de entrada
        je      ProcessaParametro  ; Se encontrar, envia para o processamento de parâmetro

        jmp     fim_processamento

	ProcessaParametro:	; Compara o byte a seguir do identificador com um dos valores válidos
        mov al, [di]                                                   
        cmp al, 'i'
        je  inputName    				; -i INPUT_FILE_NAME

		cmp al, 'o'
		je	outputName					; -o OUTPUT_FILE_NAME

		cmp al, 'v'
		je	tensionValue				; -v TENSION_VALUE

        jmp  fim_processamento          ; Sem parâmetros, termina a sub-rotina

		;===========================================
		; Tratamento de cada opção:
		; 	Todas retornam uma string para algum lugar reservado
		; na memória
		;===========================================
		inputName:
			mov inputFlag, 1
			mov si, di                  ; Move o ponteiro de entrada para SI
			add si, 2                   ; Soma 2 em SI para pular o espaço
			lea di, filenameInputFile   ; Inicializa ponteiro na string de nome de arquivo
			cld							; Limpa a flag DF, operações de string com ESI e/ou EDI fazem inc.
			jmp loop_ParameterTreatment	; Pula para o trecho de processamento

		outputName:						; Faz as mesmas coisas que a de cima, mas para a saída
			mov outputFlag, 1
			mov si, di                  
			add si, 2              
			lea di, filenameOutputFile  
			cld
			jmp loop_ParameterTreatment
		
		tensionValue:					; Recupera uma versão "string" da tensão que for dada por parâmetro
			mov tensionFlag, 1			; Informa que tem um valor de tensão passado por parâmetro
			mov si, di
			add si, 2
			lea di, tensionString
			cld
			jmp loop_ParameterTreatment

		loop_ParameterTreatment:
			cmp     byte PTR [si], 0        	; compara se chegou ao final da string Entrada
			je      loop_fileName_END
			cmp     byte PTR [si], '-'      	; compara se achou outro '-'
			je      loop_ParameterTreatment_2                             
			movsb                           	; move um byte da si para di, incrementando os dois
			jmp     loop_ParameterTreatment 	; continua ate cais em um dos casos acima
		
		loop_ParameterTreatment_2:                	; Se encontrou outro '-'
			dec     di                      ; Decrementa um de di
			mov	byte ptr [di],0             ; Termina a string com '\0'
			inc     si                      ; Incrementa 1 em si (para a próxima iteração)
			mov     di, si                  ; Troca si com di
			jmp     ProcessaParametro       ; Processa o próximo parâmetro presente
		
		loop_fileName_END:                  ; Não encontrou outro '-'
			mov	byte ptr [di],0             ; Termina a string com '\0'
			jmp     fim_processamento       ; Retorna da subrotina

	fim_processamento:
		cmp 	tensionFlag, 1				; O usuário informou uma tensão (não importa se é válida aqui)
		je		fim_processamento_2			; Retorna

		mov		tensionIntHex, 7fh			; Ele não informou, isso aqui vai rodar e depois retornar.
		;Dessa forma, o valor é modificado para o padrão direto no final da verificação, serve para organizar

	fim_processamento_2: 					; POG -> Programação Orientada a Gambiarra
		ret

CommandLineProcessing_Second_Phase    endp

;;============================================
; VerificaTensão(ax);
;	Verifica se a tensão é válida, se não for, informa.
;	ax -> Valor inteiro em hexadecimal referente a tensão
;;============================================
VerifyTension proc near
	cmp ax, LOW_TENSION					; CMP ax com 127
	je	validTension

	cmp ax, HIGH_TENSION				; CMP ax com 220
	je validTension

	jmp invalidTension					; Nenhum dos CMP foi válido

	validTension:
		mov tensionIntHex, ax			; Armazena o valor de ax na variável
		ret								; A tensão é válida e pode prosseguir com o programa
	
	invalidTension:
		lea bx, invalidTensionWarning	; Informa no console que o usuário escreveu bobagem
		call printf

		mov ax, 0
		ret								; O zero em AX informa que o programa DEVE encerrar após o ret

VerifyTension endp





;;============================================================================================================
;; Daqui para baixo, tem algumas funções eu peguei da cadeira (ARQUITETURA DE COMPUTADORES I) no moodle do INF
;; Elas não são comentadas (em maior parte) porque a ideia é simples e trivial se você já chegou até aqui.
;; Printf (Print format)
;; Atoi   (Ascii to Integer)
;; GetCommandLine (Self-explanatory)
;; sprintf_w()
;;------------
;; Função de Debugging do código (Essa aqui não foi do moodle)
;; FopenInputFile()
;; FileCreateOutput()
;;===========================================================================================================



;;============================================
; Printf(bx);
;	Dada uma string, imprime ela no console.
;	bx -> char*
;;============================================
printf proc near
	mov	dl,[bx]
	cmp	dl,0
	je	ps_1

	push bx
	mov	ah,2
	int	21H
	pop	bx

	inc	bx
	
	jmp	printf
ps_1:
	ret

printf    endp

;;============================================
; ax Atoi(bx);
;	Conversão de um ASCII decimal para Hexadecimal
;	bx -> char*
;	ax -> int (hex)
;;============================================
atoi proc near
	mov ax, 0 ; Zera a saída

	atoi_2:
		cmp byte ptr[bx], 0 ; Verifica se chegou ao fim da string
		jz atoi_1

		; Trecho de conversão:
		mov cx, 10
		mul cx

		mov ch, 0
		mov cl, [bx]
		add ax, cx

		sub ax, '0'
		
		; Atualiza o ponteiro:
		inc bx

		jmp atoi_2
	
	atoi_1:
		ret

atoi endp

;;============================================
;; GetCommandLine();
;; Salva a linha de comando para processamento
;;============================================
GetCommandLine proc near
	push ds       
	push es
	
	mov ax,ds           
	mov bx,es                  
	mov ds,bx                  
	mov es,ax
	
	mov si,80h              
	mov ch,0
	mov cl,[si]
	
	mov si, 81h        
	lea di, cmdLine    

	rep movsb
	
	mov	byte ptr es:[di],0
	
	pop es             
	pop ds

	mov	ax,ds
	mov	es,ax

	ret
	
GetCommandLine endp

;;============================================
; FopenInputFile();
;	Abre um arquivo e verifica a validade dele
;	Preenche o handle de arquivo de entrada
;;============================================
FopenInputFile proc near
	cmp 	inputFlag, 1		; O usuário deu nome na chamada do programa?
	je		userInputFile		; Sim, ele deu...

	std_FileProcess: ; Não, ele não deu :c
		mov 	al, 0
		lea 	dx, stdInputFile
		mov		ah, 3dh
		int		21H
		jnc		fileOpened

		lea 	bx, erroOpen		; Informa que não foi possível abrir o arquivo
		call	printf				; --------------------------------------------
		mov		cx, 1				; Sinal de erro
		jmp		end_fopen			; Retorna

	userInputFile:
		mov 	al, 0
		lea 	dx, filenameInputFile
		mov		ah, 3dh
		int		21H
		jnc		fileOpened

		lea 	bx, erroOpen		; Informa que não foi possível abrir o arquivo
		call	printf				; --------------------------------------------
		mov		cx, 1				; Sinal de erro
		jmp		end_fopen			; Retorna

		fileOpened:
			mov		handlerInputFile, ax 	; Manda o handle... pro handle, pra onde mais iria?
			lea 	bx, arquivoAbriu		; Informa que abriu o arquivo pra mim não ter um surto
			call	printf					; --------------------------------------------
			mov cx, 0						; Sem erro
	
	end_fopen:
		ret
	
FopenInputFile endp

;;============================================
; FileCreateOutput();
;	Cria um arquivo de relatório de saída.
;	Preenche o handle do arquivo de saída
;;============================================
FileCreateOutput proc near
	cmp 	outputFlag, 1			; Verifica se o usuário passou o nome do arquivo
	je		userOutputFile			; Se ele passou envia para outra parte da função

	std_FileCreate:
		lea dx, stdOutputFile		; Cria um arquivo com nome padrão
		mov ah, 3ch
		int		21H
		jnc fileCreated

		lea 	bx, erroCreate		; Informa que não foi possível criar o arquivo
		call	printf				; --------------------------------------------
		mov		cx, 1				; Sinal de erro
		jmp		end_createFile		; Retorna

	userOutputFile:
		lea dx, filenameOutputFile	; Cria um arquivo com o nome dado pelo usuário
		mov ah, 3ch
		int		21H
		jnc fileCreated

		lea 	bx, erroCreate		; Informa que não foi possível criar o arquivo
		call	printf				; --------------------------------------------
		mov		cx, 1				; Sinal de erro
		jmp		end_createFile		; Retorna

		fileCreated:
			mov handlerOutputFile, ax
			lea 	bx, arquivoCriado		; Informa que criou o arquivo
			call	printf					; --------------------------------------------
			mov		cx, 0					; Sem erro
	
	end_createFile:
		ret

FileCreateOutput endp

;--------------------------------------------------------------------
;Associa��o de variaveis com registradores e mem�ria
;	string	-> bx
;	k		-> cx
;	m		-> sw_m dw
;	f		-> sw_f db
;	n		-> sw_n	dw
;--------------------------------------------------------------------

sprintf_w	proc	near

;void sprintf_w(char *string, WORD n) {
	mov		sw_n,ax

;	k=5;
	mov		cx,5
	
;	m=10000;
	mov		sw_m,10000
	
;	f=0;
	mov		sw_f,0
	
;	do {
sw_do:

;		quociente = n / m : resto = n % m;	// Usar instru��o DIV
	mov		dx,0
	mov		ax,sw_n
	div		sw_m
	
;		if (quociente || f) {
;			*string++ = quociente+'0'
;			f = 1;
;		}
	cmp		al,0
	jne		sw_store
	cmp		sw_f,0
	je		sw_continue
sw_store:
	add		al,'0'
	mov		[bx],al
	inc		bx
	
	mov		sw_f,1
sw_continue:
	
;		n = resto;
	mov		sw_n,dx
	
;		m = m/10;
	mov		dx,0
	mov		ax,sw_m
	mov		bp,10
	div		bp
	mov		sw_m,ax
	
;		--k;
	dec		cx
	
;	} while(k);
	cmp		cx,0
	jnz		sw_do

;	if (!f)
;		*string++ = '0';
	cmp		sw_f,0
	jnz		sw_continua2
	mov		[bx],'0'
	inc		bx
sw_continua2:


;	*string = '\0';
	mov		byte ptr[bx],0
		
;}
	ret
		
sprintf_w	endp


;;============================================
;; DebugFunction();
;; Informações importantes da memória que eu só consigo
;; ver aqui porque o DEBUG da microsoft não rodou
;; -- *sad music playing on the background* --
;;============================================
DebugFunction proc near
	lea bx, breakLine
	call printf
	; A lógica é idêntica em todos os passos, então segue a explicação base:
	;==============
	; Compara se foi informado por CMD algum parâmetro para a opção correspondente
	; Se foi, imprime no console a informação que foi recebida. (com uma identificação do que é)
	; Senão, informa que não tem parâmetro e que para a execução atual será utilizado
	; o valor padrão (dado pelo enunciado)
	;==============
	beginDebug:								; Verificação de InputFileName
		cmp 	inputFlag, 1					
		je 		informaNomeEntrada

		lea		bx, inputWithoutParameter 	
		call	printf
		lea 	bx, warnInputFile
		call 	printf
		lea 	bx, breakLine
		call 	printf
		jmp		checkOutputFlag

	informaNomeEntrada:						; Imprime InputFileName se ele existe
		lea 	bx, labelInput
		call 	printf
		lea		bx, filenameInputFile
		call 	printf

		lea 	bx, breakLine
		call 	printf

	checkOutputFlag:						; Verificação de OutputFileName
		cmp 	outputFlag, 1
		je 		informaNomeSaida

		lea		bx, ouputWithoutParameter
		call	printf
		lea 	bx, warnOutputFile
		call 	printf
		lea 	bx, breakLine
		call 	printf
		jmp 	checkTensionFlag
		
	informaNomeSaida:						; Imprime OutputFileName se ele existe
		lea 	bx, labelOutput
		call 	printf
		lea		bx, filenameOutputFile
		call	printf

		lea 	bx, breakLine
		call 	printf

	checkTensionFlag:						; Verificação de Tensão
		cmp 	tensionFlag, 1
		je 		informaTensao

		lea		bx, tensionWithoutParameter
		call	printf
		lea 	bx, warnTensionValue
		call 	printf
		lea 	bx, breakLine
		call 	printf
		jmp 	end_debug

	informaTensao:							; Imprime a tensão se ela existe
		lea 	bx, labelTension
		call 	printf
		lea 	bx, tensionString
		call 	printf
		lea 	bx, breakLine
		call 	printf

	lea bx, breakLine
	call printf

	lea bx, tempo
	call printf

	mov ax, hours		; Tempo com tensão (h)
	lea bx, string	
	call sprintf_w	
	lea bx, string
	call printf
	lea bx, doisPontos
	call printf

	mov ax, minutes		; Tempo com tensão (min)
	lea bx, string	; String buffer de sprintf
	call sprintf_w	; Conversão
	lea bx, string
	call printf
	lea bx, doisPontos
	call printf

	mov ax, seconds		; Tempo com tensão (sec)
	lea bx, string	; String buffer de sprintf
	call sprintf_w	; Conversão
	lea bx, string
	call printf

	lea bx, breakLine
	call printf

	; Tempo sem Tensão:
	lea bx, timerSemTensao
	call printf

	mov ax, hours_noTension		; Tempo sem tensão (h)
	lea bx, string
	call sprintf_w
	lea bx, string
	call printf
	lea bx, doisPontos
	call printf

	mov ax, minutes_noTension	; Tempo sem tensão (min)
	lea bx, string
	call sprintf_w
	lea bx, string
	call printf
	lea bx, doisPontos
	call printf

	mov ax, seconds_noTension	; Tempo sem tensão (sec)
	lea bx, string
	call sprintf_w
	lea bx, string
	call printf

	lea bx, breakLine
	call printf

	; Tempo total de tensão:
	lea bx, timerTotal
	call printf

	mov ax, total_hours		; Tempo total (h)
	lea bx, string
	call sprintf_w
	lea bx, string
	call printf
	lea bx, doisPontos
	call printf

	mov ax, total_minutes	; Tempo total (min)
	lea bx, string
	call sprintf_w
	lea bx, string
	call printf
	lea bx, doisPontos
	call printf

	mov ax, total_seconds	; Tempo total (sec)
	lea bx, string
	call sprintf_w
	lea bx, string
	call printf

	lea bx, breakLine
	call printf

	end_debug:
		ret									; Retorna da função

DebugFunction endp

END