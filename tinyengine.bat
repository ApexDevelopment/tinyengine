@echo off
setlocal enableDelayedExpansion
REM Lua version

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
set contents=!contents!!terminator!

REM Count the bytes in the file, as well as store them in variables.
set tmpcopy=!contents!
set /a len=0
REM Essentially a do/while loop, or repeat/until, whatever you like
:count
	REM Shift out first character.
	set char=!tmpcopy:~0,1!
	set tmpcopy=!tmpcopy:~1!

	REM Convert the byte, which is in character form, into its ASCII decimal representation.
	REM Calls into CharLib.bat, which is slow, so we do it in the pre-execution step.
	call CharLib asc char 0 ascbyte

	REM Save it for execution.
	set code!len!=!ascbyte!

	REM Increase length counter.
	set /a len+=1

REM Test if we have reached the end.
if not "!tmpcopy!"=="!terminator!" goto count

REM Get the index of the last byte in the file.
set /a last=!len!-1

echo Interpreting...

REM Time to do bytecode interpreting. Index is essentialy the program counter.
set /a index=0

REM TEMPORARY BRAINF--K STYLE VM
set /a ptr=0
set /a retptr=-1
set /a skipping=0
set /a passed=0

:exec
	REM Do a double expansion here to get the byte to interpret.
	REM This is a little slow, but this is a prototype, so...
	call set commd=%%code!index!%%

	REM Now we interpret the byte.
	set /a "opcode=63&!commd!"
	
	REM Check if we are fast-forwarding to a corresponding loop close.
	if "!skipping!" EQU "0" (
		goto code!opcode!
	) else (
		if "!opcode!" EQU "4" (
			set /a passed+=1
		)

		if "!opcode!" EQU "5" (
			set /a passed-=1
		)

		if "!passed!" EQU "-1" (
			set /a skipping=0
		)
	)
	:back
	call set value=%%mem!ptr!%%
	
	REM For debugging the machine state
	REM echo !opcode!, !ptr!, !value!

	set /a index+=1
if !index! LEQ !last! goto exec

echo Done.
goto end

REM Brainf--k commands, for now
:code0
	set /a mem!ptr!+=1
goto back

:code1
	if not defined mem!ptr! (
		set /a mem!ptr!=255
	) else (
		call set value=%%mem!ptr!%%
		if "!value!" EQU "0" (
			set /a mem!ptr!=255
		) else (
			set /a mem!ptr!-=1
		)
	)
goto back

:code2
	set /a ptr+=1
	if "!ptr!" EQU "30000" (
		set /a ptr=0
	)
goto back

:code3
	set /a ptr-=1
	if "!ptr!" EQU "-1" (
		set /a ptr=29999
	)
goto back

:code4
	call set value=%%mem!ptr!%%
	if "!value!" EQU "0" (
		REM Skip to corresponding loop close
		set /a skipping=1
	) else (
		REM Push the current position onto the return stack
		set /a retptr+=1
		set /a "retstack!retptr!=!index!-1"
	)
goto back

:code5
	REM Check for the corresponding loop start to jump to
	if "!retptr!" GEQ "0" (
		REM Only jump to it if the current cell is not zero
		call set value=%%mem!ptr!%%
		if "!value!" NEQ "0" (
			call set /a index=%%retstack!retptr!%%
			set /a retptr-=1
		)
		goto back
	) else (
		echo Return stack underflow (too many loop closes)
		exit /b 1
	)
goto back

:code6
	call set value=%%mem!ptr!%%
	call CharLib chr !value! outputchr
	echo Script output: !outputchr!
	REM echo !value!
goto back

:end
REM echo Exiting.
exit /b 0