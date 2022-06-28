#NoEnv
#SingleInstance force
SetBatchLines -1
SetWorkingDir %A_ScriptDir%

ProgName := "REAPER SETUP"

SelectedFile = %1%
    If !SelectedFile {
        GoTo GetSelectedFile
        }
        Else {
            ;GoTo Print
            GoTo Make
            }
;_____________ Выбрать файл _____________
GetSelectedFile:
FileSelectFile, SelectedFile, 3, %A_ScriptFullPath%, Открыть файл, Скрипт (*.ReaperKeyMap)
    SplitPath SelectedFile, FileName, FileDir, FileExt, FileNoExt, FileDrive
        ;symlink_name := RegExReplace(FileNoExt, "i)(.+)(\s)(Installer)", "$1", Count,,1) ; Оставляем только 1 слово (SymLink Installer.cmd = SymLink.cmd)
        ;symlink_name := RegExReplace(FileNoExt, "i)(!!)(.+)", "!$2", Count,,1) ; Убераем (!) знак в имени файла.
            If !SelectedFile {
                MsgBox 0x40024, % ProgName, Файл не выбран!`n`nПовторить?
                        IfMsgBox Yes, {
                            GoTo GetSelectedFile
                            }
                        IfMsgBox No, {
                            ExitApp
                            }
                    }

Print:
    SplashTextOn 400, 100, % ProgName, `nСоздание файла`n %FileName% `nзавершено!
    Sleep 2000
    SplashTextOff
;___________________________________________
;_____________ НАЧАЛО ИНСТАЛЛА _____________
Make:
;__________________________________
parse_file = %FileNoExt%.%FileExt%
output_file = %FileNoExt% FIX.%FileExt%
;__________________________________
FileRead, inp, %parse_file%
vText := ""
Loop, parse, inp, `n
{
    pattern := "(SCR\s\d+\s(\d+)\s)(RS\w+)\s(""\w+:\s)(.+?""\s)?("".+?"")?" ; Новый вариант

    RegExMatch(A_LoopField, "iO)" . pattern, match)
    substr := match[5]

    substr := RegExReplace(substr, "(\s)", "_")
    substr := RegExReplace(substr, "(\.\w{3}""?\w?)", "")
    ;substr := RegExReplace(substr, "[\.\,\(\)\[\]\+\-\']", "")
    substr := RegExReplace(substr, "[\.\,\(\)\[\]\+\']", "")
    substr := RegExReplace(substr, "(_-_)", "-")
    substr := RegExReplace(substr, "(.+)?", "$L0")

    idstr := match[2]
    idstr := RegExReplace(idstr, "32060", "_me")
    idstr := RegExReplace(idstr, "32062", "_mie")
    idstr := RegExReplace(idstr, "^0$", "")

    ;vText .= RegExReplace(A_LoopField, pattern, "$1" . substr . A_Space . "$4$5$6") . "`n" ; Старый вариант
    vText .= RegExReplace(A_LoopField, pattern, "$1" . substr . idstr . A_Space . "$4$5$6") . "`n" ; Новый вариант
}

;vText := RegExReplace(vText, "im)^ACT\s\d+\s\d+\s""\w+""\s""custom:\s(arpeggio|chord|scale)(.+)?$", "") ;Убираем строчки!
;vText := RegExReplace(vText, "im)^(.*)(\r?\n\1)+$", "$1") ;Убираем дублируещиеся строчки!
;vText := RegExReplace(vText, "(`r`n){3,}", "`r`n`r`n") ; Убираем больше 1-й пустой строчки
;MsgBox, % vText
FileDelete, %output_file%
FileAppend % vText, %output_file%
Sleep, 100
;__________________________________
parse_file1 = %FileNoExt%.%FileExt%
parse_file2 = %FileNoExt%-menu.%FileExt%-
parse_file3 = %output_file%
array_file = %FileNoExt%-menu-array.%FileExt%.txt
output_file1 = %FileNoExt%-menu.%FileExt%
;__________________________________
FileDelete, %array_file%
FileDelete, %output_file1%
;__________________________________
List := {}
List := Object()
FileRead, inp1, %parse_file1%
vText1 := ""
Loop, Parse, inp1, `n
{
		vText1 := RegExMatch(A_LoopField, "i)(SCR\s\d+\s(\d+)\s)(RS\w+)\s(""\w+:\s)(.+?""\s)?("".+?"")?", m) ; Новый вариант
		substr := m5
		substr := RegExReplace(substr, "(\s)", "_")
    	substr := RegExReplace(substr, "(\.\w{3}""?\w?)", "")
    	substr := RegExReplace(substr, "[\.\,\(\)\[\]\+\']", "")
		substr := RegExReplace(substr, "(_-_)", "-")
		substr := RegExReplace(substr, "(.+)?", "$L0")
		idstr := m2
    	idstr := RegExReplace(idstr, "32060", "_me")
    	idstr := RegExReplace(idstr, "32062", "_mie")
    	idstr := RegExReplace(idstr, "^0$", "")
		IfEqual, vText1, 0
			ErrorLevel =
		Else
		{
			key	:= m3
			List[key] .= substr . idstr
			for key, value in Object
			{
			;newstr .= "" . m2 . "`," . substr . "`n"
		}
			;FileAppend % "" . m3 . "`," . substr . "`n", %array_file% ; Старый вариант
			FileAppend % "" . m3 . "`," . substr . idstr . "`n", %array_file% ; Новый вариант
	}
}
Sleep, 100
;__________________________________
FileRead, inp2, %parse_file2%
vText2 := ""
Loop, parse, inp2, `n
{
	pattern := "(\w+?_\d+?=_)(RS\w+)\s(.+)?"

	RegExMatch(A_LoopField, "iO)" . pattern, match)
	submatch := match[2]

	if List.HasKey(submatch)
	submatch := List[submatch]

	vText2 .= RegExReplace(A_LoopField, pattern, "$1" . submatch . A_Space . "$3") . "`n"
}
FileDelete, %output_file1%
FileAppend % vText2, %output_file1%
Sleep, 100
;__________________________________
FileRead, inp3, %parse_file3%
vText3 := ""
Loop, parse, inp3, `n
{
	pattern := "(KEY\s\d+\s\d+\s_)(RS\w+)\s(.+)?"

	RegExMatch(A_LoopField, "O)" . pattern, match)
	submatch := match[2]

	if List.HasKey(submatch)
	submatch := List[submatch]

	vText3 .= RegExReplace(A_LoopField, pattern, "$1" . submatch . A_Space . "$3") . "`n"
}

FileDelete, %output_file1%
FileDelete, %parse_file3%
FileAppend % vText3, %parse_file3%
Sleep, 100
ExitApp