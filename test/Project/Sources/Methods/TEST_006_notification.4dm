//%attributes = {}
$status:=iCal Request permission

If ($status.success)
	
	iCal SET NOTIFICATION METHOD("EKEventStoreChangedNotification")
	$method:=iCal Get notification method
	
End if 