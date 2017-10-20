################################################################
#
# パフォーマンス カウンターをメンバーサーバーに展開
# (DeployCore.ps1 が Invoke-Command するスクリプト)
#
################################################################
param ( $DriveLetter )

### 戻り値
$G_FAIL = "Return FAIL"
$G_ERROR = "Return ERROR"
$G_OK = "Return OK"


if( $DriveLetter -eq $null ){
	return $G_FAIL
}

if( ($DriveLetter -ne "e:") -and ($DriveLetter -ne "d:") -and ($DriveLetter -ne "c:") ){
	return $G_FAIL
}

# ディレクトリー構造
$G_RootPath = Join-Path $DriveLetter "\Counter2"
$G_LogPath = Join-Path $G_RootPath "\Log"


$G_LogName = "DeployMe"
##########################################################################
#
# ログ出力
#
# グローバル変数 $G_LogName にログファイル名をセットする
#
##########################################################################
function Log(
			$LogString
			){


	$Now = Get-Date

	$Log = "{0:0000}-{1:00}-{2:00} " -f $Now.Year, $Now.Month, $Now.Day
	$Log += "{0:00}:{1:00}:{2:00}.{3:000} " -f $Now.Hour, $Now.Minute, $Now.Second, $Now.Millisecond
	$Log += $LogString

	if( $G_LogName -eq $null ){
		$G_LogName = "LOG"
	}

	$LogFile = $G_LogName +"_{0:0000}-{1:00}-{2:00}.log" -f $Now.Year, $Now.Month, $Now.Day

	# ログフォルダーがなかったら作成
	if( -not (Test-Path $G_LogPath) ) {
		New-Item $G_LogPath -Type Directory
	}

	$LogFileName = Join-Path $G_LogPath $LogFile

	Write-Output $Log | Out-File -FilePath $LogFileName -Encoding Default -append
	return $Log
}

##########################################################################
# 強制終了
##########################################################################
function Abort( $Message ){
	Log $Message
	$ErrorActionPreference = "Stop"
	throw $Message
}


################################################################
#
# Main
#
################################################################
Log "[INFO] ============== セットアップ開始 =============="

$CounterName = "AP_Server_Loging"
C:\Windows\System32\logman query $CounterName
if( $LastExitCode -eq 0 ){
	Log "[INFO] カウンター停止"
	C:\Windows\System32\logman stop $CounterName
	if( $LastExitCode -ne 0 ){
		Log "[ERROR] カウンター停止失敗(既に止まっていた?)"
	}

	Log "[INFO] カウンター削除"
	C:\Windows\System32\logman delete $CounterName
	if( $LastExitCode -ne 0 ){
		Abort "[ERROR] カウンター削除失敗"
		exit
	}
}
else{
	Log "[INFO] 新規インストール"
}


# 出力するファイル名
$NewFileName = Join-Path $G_RootPath "AP_Server_LOG.xml"

if( Test-Path $NewFileName ){
	Log "[INFO] $NewFileName があったので削除"
	del $NewFileName
}

$OutputFile = $NewFileName
$InputFile = Join-Path $G_RootPath "AP_Server_LOG_ORG.xml"
if( -not (Test-Path $InputFile)){
	Abort "[FAIL] $InputFile not found !!"
	exit
}

Log "[INFO] ノード別に文字列置き換え : $InputFile → $OutputFile"
$NodelData = $(Get-Content $InputFile ) -replace "##DriveLetter##", $DriveLetter

Try{
	Write-Output $NodelData | Out-File -FilePath $OutputFile -Force
	Log "[INFO] ノード設定ファイル($OutputFile)出力成功"
} catch [Exception] {
	Log "[FAIL] ノード設定ファイル($OutputFile)出力失敗"
	Abort "[FAIL] ●○●○ 処理異常終了 ●○●○"
	exit
}


$hostname = hostname

$Now = Get-Date

$YYYYMMDD = [String]"{0:0000}{1:00}{2:00}" -f $Now.Year, $Now.Month, $Now.Day

$OrgFileName = $DriveLetter + "\Perform_log\" + $hostname + "_AP_Server_Log_" + $YYYYMMDD + ".blg"
$ChkFileName = $DriveLetter + "\Perform_log\" + $hostname + "_AP_Server_Log_" + $YYYYMMDD + "-old.blg"

$NewFileName = $hostname + "_AP_Server_Log_" + $YYYYMMDD + "-old.blg"

if(test-path $OrgFileName){
	# リネームターゲットが存在していなかったら(リネームターゲットが既に存在していたら skip)
	if( -not (test-path $ChkFileName) ){
		Log "[INFO] File Rename $OrgFileName $NewFileName"
		Rename-Item $OrgFileName $NewFileName
	}
	else{
		Log "[INFO] $ChkFileName が存在していたのでrenameせず処理続行"
	}
}

$CounterXML = Join-Path $G_RootPath "AP_Server_LOG.xml"
C:\Windows\System32\logman import $CounterName -xml $CounterXML
if( $LastExitCode -ne 0 ){
	Abort "[ERROR] カウンター登録失敗"
	exit
}
else{
	Log "[INFO] カウンター登録成功"
}


C:\Windows\System32\logman start $CounterName
if( $LastExitCode -ne 0 ){
	Abort "[ERROR] カウンター起動失敗"
	exit
}
else{
	Log "[INFO] カウンター起動成功"
}

$TaskName = "\gloops\AP_Server\MoveLog"
schtasks /query /TN $TaskName
if( $LastExitCode -eq 0 ){
	schtasks /Delete /TN $TaskName /F
	if( $LastExitCode -ne 0 ){
		Abort "[ERROR] スケジュール : $TaskName 削除失敗"
		exit
	}
	else{
		Log "[INFO] スケジュール : $TaskName 削除成功"
	}
}
else{
	"[INFO] スケジュール : $TaskName はまだ登録されていない"
}

$Script = Join-Path $G_RootPath "MoveLog.ps1"

if( Test-Path $Script ){
	$TaskPath = "\gloops\AP_Server"
	$TaskName = "MoveLog"
	$RunTime = "01:00"
	$RunDay = "2"

	$NewTask = "$TaskPath" + "\" + $TaskName
	SCHTASKS /Create /tn $NewTask /tr "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe $Script" /ru "SYSTEM" /sc MONTHLY /d $RunDay /st $RunTime
	if($LastExitCode -ne 0){
		Log "[FAIL] スケジュール : $NewTask 登録失敗"
		Abort "[FAIL] ●○●○ 処理異常終了 ●○●○"
		exit
	}
	else{
		Log "[INFO] スケジュール : $NewTask 登録成功"
	}
}
else{
	Abort "[FAIL] $MoveScript が存在しない"
	exit
}

$TaskName = "\gloops\AP_Server\LogRotate"
schtasks /query /TN $TaskName
if( $LastExitCode -eq 0 ){
	schtasks /Delete /TN $TaskName /F
	if( $LastExitCode -ne 0 ){
		Abort "[ERROR] スケジュール : $TaskName 削除失敗"
		exit
	}
	else{
		Log "[INFO] スケジュール : $TaskName 削除成功"
	}
}
else{
	Log "[INFO] スケジュール : $TaskName はまだ登録されていない"
}



$TaskPath = "\gloops\AP_Server"
$TaskName = "LogRotate"
$RunTime = "00:00"
$Script = Join-Path $G_RootPath "LogRotateSchedule.ps1"
$FullTaskName = $TaskPath + "\" + $TaskName

if( Test-Path $Script ){
	SCHTASKS /Create /tn $FullTaskName /tr "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe $Script" /ru "SYSTEM" /sc daily /st $RunTime
	if($LastExitCode -ne 0){
		Log "[FAIL] スケジュール : $FullTaskName 登録失敗"
		Abort "[FAIL] ●○●○ 処理異常終了 ●○●○"
		exit
	}
	else{
		Log "[INFO] スケジュール : $FullTaskName 登録成功"
	}
}
else{
	Abort "[FAIL] $Script が存在しない"
	exit
}

Log "[INFO] ============== セットアップ終了 =============="
