//%attributes = {}
$status:=iCal Request permission

If ($status.success)
	
	$options:=New object:C1471("title"; "TEST3")
	
	$status:=iCal Remove calendar($options)
	
End if 

