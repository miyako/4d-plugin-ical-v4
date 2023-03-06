//%attributes = {}
$status:=iCal Request permisson

If ($status.success)
	
	iCal SET NOTIFICATION METHOD("EKEventStoreChangedNotification")
	$method:=iCal Get notification method
	
End if 