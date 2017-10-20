################################################################
#
# イベントログチェックを展開するためのTM 初期セットアップ
# (便宜上 github に上げているが、事前に pull したものを実行)
#
#  1.00 2014/11/21 S.Murashima
#
################################################################
#
# 手順
#	0.新版イベントログチェックがインストールされている(前提)
#	1.このスクリプト(InitSetupTM.ps1)を適当なフォルダーにコピーして実行
#	2.展開された E:\Counter2\Deploy.ps1 実行
#
################################################################
# インストールリポジトリー
$G_InitInstallRepository = "git@github.com:SyuichiMurashima/recordapserverperformancecounter.git"

$G_ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$DriveLetter = Split-Path $G_ScriptDir -Qualifier


# ディレクトリー構造
$G_RootPath = Join-Path $DriveLetter "\Counter2"
$G_LogPath = Join-Path $G_RootPath "\Log"

# ファイルサーバー
if( Test-Path "\\172.24.3.72\Shares" ){
	$FileServer = "\\172.24.3.72"
}
elseif(Test-Path "\\d03713-fsa.common.gloops.local\Shares"){
	$FileServer = "\\d03713-fsa.common.gloops.local"
}
elseif(Test-Path "\\d03713-fsa\Shares"){
	$FileServer = "\\d03713-fsa"
}
else{
	echo "[FAIL] file server アクセス不能"
	exit
}

$SourceScriptDir = "\Shares\03-1_インフラ\20_サーバ関係\10_コンテンツ用サーバ\InflaAgentKit"
$SourcePasswordFileDir = "\InfraBackup\Credential"

$DestinationDir = $G_RootPath

# 認証
$AuthenticationDir = "C:\Authentication"


$G_LogName = "InitSetupTM"
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

	$BatchLogDir = $G_LogPath

	$Now = Get-Date

	$Log = "{0:0000}-{1:00}-{2:00} " -f $Now.Year, $Now.Month, $Now.Day
	$Log += "{0:00}:{1:00}:{2:00}.{3:000} " -f $Now.Hour, $Now.Minute, $Now.Second, $Now.Millisecond
	$Log += $LogString

	if( $G_LogName -eq $null ){
		$G_LogName = "LOG"
	}

	$LogFile = $G_LogName +"_{0:0000}-{1:00}-{2:00}.log" -f $Now.Year, $Now.Month, $Now.Day

	# ログフォルダーがなかったら作成
	if( -not (Test-Path $BatchLogDir) ) {
		New-Item $BatchLogDir -Type Directory
	}

	$LogFileName = Join-Path $BatchLogDir $LogFile

	Write-Output $Log | Out-File -FilePath $LogFileName -Encoding Default -append
	return $Log
}

################################################################
#
# Main
#
################################################################

Log "[INFO] ============== セットアップ開始 =============="
if (-not(([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))) {
	Log "実行には管理権限が必要です"
	exit
}

# ドライブ構成確認
#if( -not(Test-Path "e:\" )){
#	echo "[FAIL] E: ドライブが存在しない"
#	exit
#}

if( -not (Test-Path $AuthenticationDir)){
	Log "[FAIL] 証明書がインストールされていない"
	exit
}

$CopyFile = $FileServer + $SourcePasswordFileDir + "\ApLogmanager.txt"
if( test-path $CopyFile ){
	Log "[INFO] CopyFile : $CopyFile"
	copy $CopyFile $AuthenticationDir -Force
}
else{
	Log "[FAIL] $CopyFile not found!!"
	exit
}

#--------------------
Log "[INFO] Git for Windows インストール確認"

$GitCommand = "C:\Program Files\Git\bin\git.exe"
if( -not (test-path $GitCommand) ){
	Log "[FAIL] Git for Windows インストール されていない"
	exit
}

#--------------------
Log "[INFO] Git 環境構築"
$sshDir = Join-Path $G_RootPath "\.ssh"

if( -not(test-path $DestinationDir )){
	Log "[INFO] $DestinationDir 作成"
	md $DestinationDir
}

if(-not(test-path $sshDir)){
	Log "[INFO] $sshDir 作成"
	md $sshDir
}


$CopyFile = $FileServer + $SourceScriptDir + "\config"
if( test-path $CopyFile ){
	Log "[INFO] CopyFile : $CopyFile"
	copy $CopyFile $sshDir -Force
}
else{
	Log "[FAIL] $CopyFile not found!!"
	exit
}

$CopyFile = $FileServer + $SourceScriptDir + "\id_rsa"
if( test-path $CopyFile ){
	Log "[INFO] CopyFile : $CopyFile"
	copy $CopyFile $sshDir -Force
}
else{
	Log "[FAIL] $CopyFile not found!!"
	exit
}

Log "[INFO] 環境変数登録"
$env:home = $G_RootPath
$env:path += ";C:\Program Files\Git\bin"

#---------------------
Log "[INFO] インストーラー pull"
if(-not(test-path $G_RootPath)){
	md $G_RootPath
	Log "[INFO] $G_RootPath 作成"
}

cd $G_RootPath

$GitInitedChk = Join-Path $G_RootPath ".git"
if( -not(test-path $GitInitedChk) ){
	git init
}

git pull $G_InitInstallRepository
if( $LastExitCode -eq 0 ){
	Log "[INFO] インストーラー pull 成功"
}
else{
	Log "[FAIL] インストーラー pull 失敗"
	exit
}

Log "[INFO] ============== セットアップ終了 =============="
