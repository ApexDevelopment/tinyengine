@echo off
setlocal enableDelayedExpansion

if not exist "CharLib.bat" (
	echo CharLib is required - please download it and place it in the same directory as this script.
	exit /b 1
)

set "filepath=%~f1"

if "!filepath!"=="" (
	echo Please provide a file to execute.
	exit /b 1
)

if not exist "!filepath!" (
	echo File not found - !filepath!
	exit /b 1
)

REM Read in the code from the supplied file.
echo Reading file...
set /p contents=<!filepath!
set terminator=END_SCRIPT
set "contents=!contents!!terminator!"

REM Time to interpret the file structure.
set "tmpcopy=!contents!"

REM Check the header
setlocal
	set sig=!tmpcopy:~0,4!
	
	if not "!sig!"=="TINY" (
		echo Script is not valid - wrong signature.
		exit /b 1
	)
endlocal
set tmpcopy=!tmpcopy:~4!

REM Get number of constants (max 16,777,215 or 0xFFFFFF, INT24 max due to Batch limitations)
call :nextint24 sizek

REM Read in constants
echo Parsing !sizek! constants...
for /l %%i in (1, 1, !sizek!) do (
	set /a kIndex=%%i-1
	
	REM Read in byte
	call :nextchar char

	REM Constant is a boolean
	if "!char!"=="@" (
		REM echo boolean
		call :nextbyte bool
		set "const!kIndex!=B!bool!"
	)
	
	if "!char!"=="A" (
		REM echo num
		REM Constant is a 24-bit number HELP
		call :nextint24 num
		set "const!kIndex!=N!num!"
	)
	
	if "!char!"=="B" (
		REM echo str
		REM Constant is a string, again max length is INT24 max
		call :nextint24 strlen
		call set "const!kIndex!=S%%tmpcopy:~0,!strlen!%%"
		call set "tmpcopy=%%tmpcopy:~!strlen!%%"
	)

	REM call echo %%const!kIndex!%%
)

REM Constants are parsed, time to parse the code.

REM Essentially a do/while loop, or repeat/until, whatever you like
echo Parsing code...
set /a len=0
:count
	call :nextbyte opcode
	REM if "!opcode!" LEQ "10" (
	REM
	REM )

	call :nextbyte argA
	call :nextbyte argB
	call :nextbyte argC

	REM echo op !opcode! !argA! !argB! !argC!

	REM Save it for execution.
	set code!len!=!opcode!
	set code!len!A=!argA!
	set code!len!B=!argB!
	set code!len!C=!argC!

	REM Increase length counter.
	set /a len+=1

REM Test if we have reached the end.
if not "!tmpcopy!"=="!terminator!" goto count
REM exit /b 0

REM Get the index of the last byte in the file.
set /a last=!len!-1

echo Interpreting...

REM Time to do bytecode interpreting.
REM Index is essentialy the program counter. Retptr is the return stack pointer.
set /a index=0
set /a retptr=-1

:exec
	REM Do a double expansion here to get the byte to interpret.
	REM This is a little slow, but this is a prototype, so...
	call set commd=%%code!index!%%
	call set argA=%%code!index!A%%
	call set argB=%%code!index!B%%
	call set argC=%%code!index!C%%
	
	REM Execute the opcode.
	call :code!commd! !argA! !argB! !argC!
	
	REM For debugging the machine state
	REM echo !opcode!, !ptr!, !value!
set /a index+=1
if !index! LEQ !last! goto exec

echo Done.
goto end

:nextchar
setlocal
	REM Get next character
	set "chr=!tmpcopy:~0,1!"
endlocal & set "%~1=%chr%"
REM Shift out the character
set "tmpcopy=!tmpcopy:~1!"
exit /b 0

:nextbyte
setlocal
	REM Get next byte
	set "chr=!tmpcopy:~0,1!"

	REM Convert the byte, which is in character form, into its ASCII decimal representation.
	REM Calls into CharLib.bat, which is slow.
	call CharLib asc chr 0 retval
	set /a "retval=!retval!&63"
endlocal & set "%~1=%retval%"
REM Shift out the byte
set "tmpcopy=!tmpcopy:~1!"
exit /b 0

:nextint24
setlocal
	set /a num=0
	for /l %%x in (0, 1, 3) do (
		call :nextbyte numbyte
		set /a "shift=%%x*6"
		set /a "numbyte=!numbyte!<<(%%x*6)"
		set /a "finalnum|=!numbyte!"
	)
endlocal & set "%~1=%finalnum%"
REM We have to do this ourselves because the call to nextbyte was localized
set "tmpcopy=!tmpcopy:~4!"
exit /b 0

REM Opcodes
:code0
setlocal
	REM MOV
	set argB=%~2
	call set "val=%%mem!argB!%%"
	REM set "mem!argA!=!val!"
endlocal & set "mem%~1=%val%"
exit /b 0

:code1
setlocal
	REM LOADK
	set argB=%~2
	call set "val=%%const!argB!%%" 
	REM set "mem!argA!=!val!"
endlocal & set "mem%~1=%val%"
exit /b 0

:code2
	REM CALL
	set argA=%~1
	set argB=%~2
	set argC=%~3
	set /a begin=!argA!+1
	set /a end=!argA!+!argB!-1
	call set func=%%mem!argA!%%
	REM echo CALL !argA! !func!
	set vtype=!func:~0,1!
	set func=!func:~1!

	if "!vtype!"=="S" (
		REM echo Builtin function called.
		call :B!func! !begin! !end!
	)

	if "!vtype!"=="C" (
		echo Script function called. This is not supported yet.
	)
exit /b 0

:code3
	REM UNM
	set argA=%~1
	set argB=%~2
	call set "val=%%mem!argB!%%"
	set vtype=!val:~0,1!
	
	if "!vtype!"=="N" (
		set /a "val=-!val:~1!"
		set "mem!argA!=N!val!"
	) else (
		echo Attempted to negate a non-number value.
		exit /b 1
	)
exit /b 0

:code4
	REM NOT
	set argA=%~1
	set argB=%~2
	call set "val=%%mem!argB!%%"
	set vtype=!val:~0,1!

	if "!vtype!"=="B" (
		set /a "val=!val:~1!"
		set /a "val=!val!^1"
		set "mem!argA!=B!val!"
	) else (
		echo Attempted to flip a non-boolean value.
		exit /b 1
	)
exit /b 0

:code5
	REM LEN
	set argA=%~1
	set argB=%~2
	call set "val=%%mem!argB!%%"
	set vtype=!val:~0,1!

	if "!vtype!"=="S" (
		set "val=!val:~1!"
		REM Get the length of the string using CharLib
		call CharLib StrLen val retval
		set "mem!argA!=N!retval!"
	) else (
		echo Attempted to get the length of a non-string value.
		exit /b 1
	)
exit /b 0

:code6
	REM ADD
	set argA=%~1
	set argB=%~2
	set argC=%~3
	call set "valA=%%mem!argB!%%"
	call set "valB=%%mem!argC!%%"
	set vtypeA=!valA:~0,1!
	set vtypeB=!valB:~0,1!

	if "!vtypeA!"=="N" (
		if "!vtypeB!"=="N" (
			set /a "valA=!valA:~1!"
			set /a "valB=!valB:~1!"
			set /a "valA+=!valB!"
			set "mem!argA!=N!valA!"
		) else (
			echo Attempted to add a non-number value (right).
			exit /b 1
		)
	) else (
		echo Attempted to add a non-number value (left).
		exit /b 1
	)
exit /b 0

:code7
	REM SUB
	set argA=%~1
	set argB=%~2
	set argC=%~3
	call set "valA=%%mem!argB!%%"
	call set "valB=%%mem!argC!%%"
	set vtypeA=!valA:~0,1!
	set vtypeB=!valB:~0,1!

	if "!vtypeA!"=="N" (
		if "!vtypeB!"=="N" (
			set /a "valA=!valA:~1!"
			set /a "valB=!valB:~1!"
			set /a "valA-=!valB!"
			set "mem!argA!=N!valA!"
		) else (
			echo Attempted to subtract a non-number value (right).
			exit /b 1
		)
	) else (
		echo Attempted to subtract a non-number value (left).
		exit /b 1
	)
exit /b 0

:code8
	REM MUL
	set argA=%~1
	set argB=%~2
	set argC=%~3
	call set "valA=%%mem!argB!%%"
	call set "valB=%%mem!argC!%%"
	set vtypeA=!valA:~0,1!
	set vtypeB=!valB:~0,1!

	if "!vtypeA!"=="N" (
		if "!vtypeB!"=="N" (
			set /a "valA=!valA:~1!"
			set /a "valB=!valB:~1!"
			set /a "valA*=!valB!"
			set "mem!argA!=N!valA!"
		) else (
			echo Attempted to multiply a non-number value (right).
			exit /b 1
		)
	) else (
		echo Attempted to multiply a non-number value (left).
		exit /b 1
	)
exit /b 0

:code9
	REM DIV
	set argA=%~1
	set argB=%~2
	set argC=%~3
	call set "valA=%%mem!argB!%%"
	call set "valB=%%mem!argC!%%"
	set vtypeA=!valA:~0,1!
	set vtypeB=!valB:~0,1!

	if "!vtypeA!"=="N" (
		if "!vtypeB!"=="N" (
			set /a "valA=!valA:~1!"
			set /a "valB=!valB:~1!"
			set /a "valA*=!valB!"
			set "mem!argA!=N!valA!"
		) else (
			echo Attempted to divide a non-number value (right).
			exit /b 1
		)
	) else (
		echo Attempted to divide a non-number value (left).
		exit /b 1
	)
exit /b 0

:code10
	REM MOD
	set argA=%~1
	set argB=%~2
	set argC=%~3
	call set "valA=%%mem!argB!%%"
	call set "valB=%%mem!argC!%%"
	set vtypeA=!valA:~0,1!
	set vtypeB=!valB:~0,1!

	if "!vtypeA!"=="N" (
		if "!vtypeB!"=="N" (
			set /a "valA=!valA:~1!"
			set /a "valB=!valB:~1!"
			set /a "valA%%=!valB!"
			set "mem!argA!=N!valA!"
		) else (
			echo Attempted to mod a non-number value (right).
			exit /b 1
		)
	) else (
		echo Attempted to mod a non-number value (left).
		exit /b 1
	)
exit /b 0

:code11
	REM EQ
	set argA=%~1
	set argB=%~2
	set argC=%~3
	call set "valA=%%mem!argB!%%"
	call set "valB=%%mem!argC!%%"
	set vtypeA=!valA:~0,1!
	set vtypeB=!valB:~0,1!

	if "!vtypeA!"=="!vtypeB!" (
		set /a "valA=!valA:~1!"
		set /a "valB=!valB:~1!"
		if "!valA!"=="!valB!" (
			set "mem!argA!=B1"
		) else (
			set "mem!argA!=B0"
		)
	) else (
		echo Attempted to compare two different value types.
		exit /b 1
	)
exit /b 0

:code12
	REM LT
	set argA=%~1
	set argB=%~2
	set argC=%~3
	call set "valA=%%mem!argB!%%"
	call set "valB=%%mem!argC!%%"
	set vtypeA=!valA:~0,1!
	set vtypeB=!valB:~0,1!

	if "!vtypeA!"=="N" (
		if "!vtypeB!"=="N" (
			set /a "valA=!valA:~1!"
			set /a "valB=!valB:~1!"
			if "!valA!"<"!valB!" (
				set "mem!argA!=B1"
			) else (
				set "mem!argA!=B0"
			)
		) else (
			echo Attempted to compare a non-number value (right).
			exit /b 1
		)
	) else (
		echo Attempted to compare a non-number value (left).
		exit /b 1
	)
exit /b 0

REM Builtin functions
:Bprint
setlocal
	for /l %%x in (%~1, 1, %~2) do (
		set argidx=%%x
		call set "arg=%%mem!argidx!%%"
		set argtype=!arg:~0,1!
		set "arg=!arg:~1!"

		set "outpt=!outpt! !arg!"
	)
	set "outpt=!outpt:~1!"
	echo [SCRIPT] !outpt!
endlocal
exit /b 0

:Binput
REM setlocal
	REM Can only store input in a pre-defined location.
	set argidx=%~1
	set /p "input=>> "
	set "mem!argidx!=S!input!"
REM endlocal & set "mem!argidx!=S!input!"
exit /b 0

:Bstoi
	REM Convert a string to an integer.
	set argidx=%~1
	call set "arg=%%mem!argidx!%%"
	set argtype=!arg:~0,1!
	set "arg=!arg:~1!"

	if "!argtype!"=="S" (
		REM Evaluate the string as an integer.
		set /a "arg=!arg!"
		set "mem!argidx!=N!arg!"
	) else (
		echo Attempted to convert a non-string value to an integer.
		exit /b 1
	)
exit /b 0

:end
REM echo Exiting.
exit /b 0