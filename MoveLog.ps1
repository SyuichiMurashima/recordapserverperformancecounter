#############################################################
#
# 前月分の log を月別フォルダー(YYYY-MM)に移動する
#
#	MoveLog.ps1
#
# 想定実施日
#  毎月2日 00:00 AM
#
#############################################################
param ( $Year, $Month )

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

$DriveLetter = Split-Path -Qualifier $ScriptDir

# ログフォルダーの Full Path
$LogPath = Join-Path $DriveLetter "\Perform_log"

if( $Year -eq $null -or $Month -eq $null)
{
	# 前月の年月を求める
	$Date = (Get-Date).AddMonths(-1)
	$LastYYYYMM = "{0:0000}{1:00}" -f $Date.Year, $Date.Month
}
else
{
	# 指定年月をセットする
	$LastYYYYMM = "{0:0000}{1:00}" -f $Year, $Month
}

# Syslog 移動先の full path
$NewPath = $LogPath + "\" + $LastYYYYMM

# 移動するファイル名
$MoveFiles = $LogPath + "\" + $Env:COMPUTERNAME + "_AP_Server_Log_" + $LastYYYYMM + "*.blg"

# 移動先フォルダーが作成されていない時のみ移動先フォルダー作成(rerun 対応)
if(-not(Test-Path $NewPath)){
	New-Item -path $LogPath -name $LastYYYYMM -type directory
}


# syslog 移動
Move-Item $MoveFiles $NewPath -force

# 3ヶ月前のログを削除する
$DeleteDate = (Get-Date).AddMonths(-3)
$DeleteYYYYMM = "{0:0000}{1:00}" -f $DeleteDate.Year, $DeleteDate.Month

$DeletePath = $LogPath + "\" + $DeleteYYYYMM

# 対象フォルダーが存在していたら削除
if(Test-Path $DeletePath){
	Remove-Item -path $DeletePath -recurse -force
}


