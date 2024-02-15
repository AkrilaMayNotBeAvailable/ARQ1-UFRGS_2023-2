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

	erroOpen			db	"Erro na abertura do arquivo.", CR, LF, 0
	arquivoAbriu		db	"Arquivo de entrada carregado", CR, LF, 0

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
	handlerOutputFile	dw 	0			; Handler do arquivo de saída

	cmdLine 			db 	256 dup (?)	; A string do CMD
	filenameInputFile	db 	256 dup (?) ; Nome do arquivo passado por parâmetro para busca de dados
	filenameOutputFile	db 	256 dup (?) ; Nome do arquivo passado por parâmetro para saída de dados
	tensionString		db 	128 dup (?) ; Valor de tensão que o usuário passou que ainda vai ser convertido

	tensionIntHex		dw 	0
	
	;========================================================
	; Flags de verificação:
	;========================================================
	inputFlag			dw	0			; Flag que indica que existe arquivo de entrada informado por CMD
	outputFlag			dw	0			; Flag que indica que existe arquivo de saída informado por CMD
	tensionFlag			dw	0			; Aqui é pra já estar subentendido

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
	call 	DebugFunction
	call 	FileProcessing
encerrarPrograma:
	.EXIT 0

;;============================================
; FileProcessing();
;	Pega o arquivo e esbagaça ele na porrada
;;============================================
FileProcessing proc near
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
		jmp		finishProcessing	; Retorna

	userInputFile:
		mov 	al, 0
		lea 	dx, filenameInputFile
		mov		ah, 3dh
		int		21H
		jnc		fileOpened

		lea 	bx, erroOpen		; Informa que não foi possível abrir o arquivo
		call	printf				; --------------------------------------------
		jmp		finishProcessing	; Retorna

		fileOpened:
			lea 	bx, arquivoAbriu		; Informa que abriu o arquivo pra mim não ter um surto
			call	printf					; --------------------------------------------
			mov		handlerInputFile, ax 	; Manda o handle... pro handle, pra onde mais iria?
			mov		bx, handlerInputFile 	; Manda o handle para BX
			mov		ah, 3eh					; Fecha o handle
			int 	21H						; Interrupt

	finishProcessing:
		ret

FileProcessing endp

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
;;------------
;; Função de Debugging do código (Essa aqui não foi do moodle)
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
;; DebugFunction();
;; Informações importantes da memória que eu só consigo
;; ver aqui porque o DEBUG da microsoft não rodou
;; -- *sad music playing on the background* --
;;============================================
DebugFunction proc near
	;; Print de um Header de debug
	;;==========================
	lea 	bx, linhaDeEquals
	call	printf
	lea	bx, debugNotes
	call	printf
	lea 	bx, linhaDeEquals
	call	printf
	;;==========================

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

	end_debug:
		ret									; Retorna da função

DebugFunction endp

END