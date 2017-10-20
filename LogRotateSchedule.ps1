#############################################################
#
# AP Server のパフォーマンスカウンターをローテートするために記録を一時停止する
#
# 想定実施日時
#  毎日 00:00 AM
#
#############################################################

C:\Windows\System32\logman.exe stop AP_Server_Loging
C:\Windows\System32\logman.exe start AP_Server_Loging
