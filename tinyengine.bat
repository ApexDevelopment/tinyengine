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
echo sizek !sizek!

REM Read in constants
echo Parsing constants.
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
echo Parsing code.
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
REM setlocal
	set "char=!tmpcopy:~0,1!"
	set "tmpcopy=!tmpcopy:~1!"
	set "%~1=!char!"
REM endlocal & set "%~1=!char!"
exit /b 0

:nextbyte

	set "char=!tmpcopy:~0,1!"
	set "tmpcopy=!tmpcopy:~1!"

	REM Convert the byte, which is in character form, into its ASCII decimal representation.
	REM Calls into CharLib.bat, which is slow, so we do it in the pre-execution step.
	call CharLib asc char 0 retval
	set /a "%~1=!retval!&63"
REM call echo outside setlocal %%%~1%%
exit /b 0

:nextint24
	set /a num=0
	for /l %%x in (0, 1, 3) do (
		call :nextbyte numbyte
		set /a "shift=%%x*6"
		set /a "numbyte=!numbyte!<<(%%x*6)"
		set /a "num|=!numbyte!"
	)
	set /a "%~1=!num!"
exit /b 0

REM Opcodes
:code0
	set argA=%~1
	set argB=%~2
	REM echo COPY !argB! to !argA!
	call set "val=%%mem!argB!%%"
	set "mem!argA!=!val!"
	REM call echo %%mem!argA!%%
exit /b 0

:code1
	set argA=%~1
	set argB=%~2
	REM echo LOAD constant !argB! to !argA!
	call set "val=%%const!argB!%%" 
	set "mem!argA!=!val!"
	REM call echo %%mem!argA!%%
exit /b 0

:code2
	REM Temporarily the "call" opcode
	set argA=%~1
	set argB=%~2
	set argC=%~3
	set /a begin=!argA!+1
	set /a end=!argA!+!argB!-1
	call set func=%%mem!argA!%%
	REM echo CALL !argA! !func!
	set functype=!func:~0,1!
	set func=!func:~1!

	if "!functype!"=="S" (
		REM echo Builtin function called.
		call :B!func! !begin! !end!
	)

	if "!functype!"=="C" (
		echo Script function called. This is not supported yet.
	)
exit /b 0

:code3
exit /b 0

:code4
exit /b 0

:code5
exit /b 0

:code6
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

:end
REM echo Exiting.
exit /b 0