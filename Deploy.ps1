param ( [String]$Terget = $null )

$G_TergetDir = "\Counter2"

$G_ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$DriveLetter = Split-Path $G_ScriptDir -Qualifier

# ディレクトリー構造
$G_RootPath = Join-Path $DriveLetter "\CheckEventlog2"
$G_CommonPath = Join-Path $G_RootPath "\Core"
$G_ProjectPath = Join-Path $G_RootPath "\Project"
$G_InstallerPath = Join-Path $G_RootPath "\Install"
$G_DeployFiles = Join-Path $G_RootPath "\DeployFiles"
$G_LogPath = Join-Path $G_RootPath "\Log"

# for PS v3
if( $PSVersionTable.PSVersion.Major -ge 3 ){
	echo "Data from `$PSScriptRoot"
	$ScriptDir = $PSScriptRoot
}
# for PS v2
else{
	echo "Data from `$MyInvocation.MyCommand.Path"
	$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
}


# 変数 Include
$Include = Join-Path $G_CommonPath "CommonConfig.ps1"
if( -not(Test-Path $Include)){
	Log "[FAIL] 環境異常 $Include が無い"
	exit
}
. $Include

$Include = Join-Path $G_ProjectPath "ProjectConfig.ps1"
if( -not(Test-Path $Include)){
	Log "[FAIL] 環境異常 $Include が無い"
	exit
}
. $Include

# 処理ルーチン
$G_LogName = "DeployPerformanceCounter"
$Include = Join-Path $G_CommonPath "f_Log.ps1"
if( -not(Test-Path $Include)){
	Log "[FAIL] 環境異常 $Include が無い"
	exit
}
. $Include

$Include = Join-Path $G_CommonPath "f_encrypt.ps1"
if( -not(Test-Path $Include)){
	Log "[FAIL] 環境異常 $Include が無い"
	exit
}
. $Include

### 戻り値
$G_FAIL = "Return FAIL"
$G_ERROR = "Return ERROR"
$G_OK = "Return OK"


# ホスト設定ファイル
$HostRoleCSV = $C_ServerInformation


##########################################################################
# 強制終了
##########################################################################
function Abort( $Message ){
	Log $Message
	$ErrorActionPreference = "Stop"
	throw $Message
}


##########################################################################
# server存在確認
##########################################################################
function IsExist( $IPAddress ){
	$Results = ping -w 1000 -n 1 $IPAddress | Out-String
	if( $Results -match "ms" ){
			Return $true
	}
	else{
		Return $false
	}
}

##########################################################################
# server存在確認(5回回す)
##########################################################################
function IsExist5Times( $IPAddress ){
	# 存在確認(5回まで ping 飛ばす)
	$i = 0
	while( $true ){
		$Rtn = @(IsExist $IPAddress)
		$State = $Rtn[$Rtn.Length - 1]
		if( $State -eq $true ){
			return $true
		}

		# 5回失敗した時
		if( $i -ge 5 ){
			return $false
		}
		$i++
	}
}

#######################################################
# Credential 作成
#######################################################
function MakePSCredential( $ID, $Credential ){
	$Password = ConvertTo-SecureString –String $Credential –AsPlainText -Force
	$RetrunCredential = New-Object System.Management.Automation.PSCredential($ID, $Password)
	Return $RetrunCredential
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

if( $Terget -eq [String]$null ){
	# ホスト設定ファイルを読む
	if( Test-Path $HostRoleCSV ){

		Log "[INFO]  ノード設定情報 $HostRoleCSV Read"
		$Nodes = Import-Csv $HostRoleCSV | ? {($_.IsAPServer -ne "") -and ($_.IsAPServer -ne $null) -and ($_.Role -ne "TM") }
	}
	else{
		Log "[FAIL] ●○●○ $HostRoleCSV なし ●○●○"
		exit
	}
}
else{
	$Nodes = @($Terget)
}


Log "[INFO] 資格情報取得"
$APCredential = Encrypt $C_ThumbprintFile $C_APServerCredential
if( $APCredential -eq $null ){
	Log "[FAIL] AP 資格情報取得失敗"
	exit
}

foreach( $Node in $Nodes ){
	if( $Terget -eq [String]$null ){
		$IPaddress = $Node.IPAddress
	}
	else{
		$IPaddress = $Node
	}

	Log "[INFO] -------< $IPaddress >---------------"

	Log "[INFO] 接続解除"
	net use /delete * /yes

	Log "[INFO] $IPaddress の存在確認"
	$Rtn = @(IsExist5Times $IPaddress)
	$State = $Rtn[$Rtn.Length - 1]
	if( $State -eq $false ){
		Log "[ERROR] $IPaddress が存在しない"
		continue
	}

	$TergetHost = "\\" + $IPaddress
	$ConnectUser = $IPaddress + "\administrator"

	$Credential = MakePSCredential $ConnectUser $APCredential

	net use $TergetHost $APCredential /user:$ConnectUser
	if( $LastExitCode -ne 0 ){
		Log "[ERROR] $IPaddress net use 失敗"
		continue
	}
	else{
		Log "[INFO] $IPaddress 接続"
	}


	$RemoteE = $TergetHost + "\E$\"
	$RemoteD = $TergetHost + "\D$\"
	$RemoteC = $TergetHost + "\C$\"

	# E: がある
	if( test-path $RemoteE ){
		Log "[INFO] Terget Drive E:"
		$TergetDir = Join-Path $RemoteE $G_TergetDir
		$TergetDriveLetter = "e:"
	}
	# E: がない
	else{
		if(test-path $RemoteD){
			Log "[INFO] Terget Drive D:"
			$TergetDir = Join-Path $RemoteD $G_TergetDir
			$TergetDriveLetter = "d:"
		}
		else{
			Log "[WARNING] ○●○●○● $IPaddress は AP だが E: D: が無いので C: にインストールする ○●○●○●"
			$TergetDir = Join-Path $RemoteC $G_TergetDir
			$TergetDriveLetter = "c:"
		}
	}

	Log "[INFO] Install to $TergetDir"


	if( -not(Test-Path $TergetDir )){
		Log "[INFO] $TergetDir が存在しないので作成"
		md $TergetDir
	}

	$SourceFile = Join-Path $ScriptDir "AP_Server_LOG_ORG.xml"
	if( -not(Test-Path $SourceFile)){
		Log "[FAIL] $SourceFile が存在しない"
		exit
	}
	Try{
		copy $SourceFile $TergetDir -force
	} catch [Exception] {
		Log "●○●○ コピー失敗(Copy to $TergetDir) : $TergetHost ●○●○"
		continue
	}

	$SourceFile = Join-Path $ScriptDir "LogRotateSchedule.ps1"
	if( -not(Test-Path $SourceFile)){
		Log "[FAIL] $SourceFile が存在しない"
		exit
	}
	Try{
		copy $SourceFile $TergetDir -force
	} catch [Exception] {
		Log "●○●○ コピー失敗(Copy to $TergetDir) : $TergetHost ●○●○"
		continue
	}

	$SourceFile = Join-Path $ScriptDir "MoveLog.ps1"
	if( -not(Test-Path $SourceFile)){
		Log "[FAIL] $SourceFile が存在しない"
		exit
	}
	Try{
		copy $SourceFile $TergetDir -force
	} catch [Exception] {
		Log "●○●○ コピー失敗(Copy to $TergetDir) : $TergetHost ●○●○"
		continue
	}

	$ExecScript = Join-Path $ScriptDir "DeployCore.ps1"
	$Rtn = Invoke-Command -ComputerName $IPaddress -Credential $Credential -FilePath $ExecScript -ArgumentList $TergetDriveLetter -AsJob
}

Log "[INFO] 接続解除"
net use /delete * /yes

Log "[INFO] +-+-+-+-+-+-+-+-+ インストールジョブ投入終了 +-+-+-+-+-+-+-+-+"

# -AsJob 投入した ジョブの状態確認
do{
	$RunningJobs = get-job | ?{ $_.State -eq "Running"}
	$CompletedJobs = get-job | ?{ $_.State -eq "Completed"}
	if( $CompletedJobs -ne $null ){
		foreach( $Job in $CompletedJobs ){
			$Location = $Job.Location
			Log "[INFO] $Location Completed"
			Remove-Job -Id $Job.Id
		}
	}
	$AllJobs = get-job
	if( $AllJobs -ne $null ){
		$Now = Get-Date
		$Message = "未処理ジョブ " + $Now
		echo $Message
		$AllJobs | Format-Table -Property Id,Name,State,Location -AutoSize | Out-Host
		echo ""
		echo ""
		echo ""
		sleep 5
	}
}
while( $RunningJobs -ne $null )

# コケたジョブ
$FailedJobs = get-job | ?{ $_.State -eq "Failed"}
if( $FailedJobs -ne $null ){
	# 一覧表示
	echo "Fail Job"
	$FailedJobs | Format-Table -Property Id,Name,State,Location -AutoSize | Out-Host
	echo ""
	foreach( $Job in $FailedJobs ){
		$Location = $Job.Location

		Log "[ERROR] $Location Failed"
		Log "[ERROR] ------------ $Location Log Start ------------"
		$FailLogs = Receive-Job -Id $Job.Id
		if( $FailLogs -ne $null ){
			foreach( $FailLog in $FailLogs ){
				Log $FailLog
			}
		}
		Log "[ERROR] ------------ $Location Log End ------------"
		Remove-Job -Id $Job.Id
	}
}


Log "[INFO] ============== セットアップ終了 =============="