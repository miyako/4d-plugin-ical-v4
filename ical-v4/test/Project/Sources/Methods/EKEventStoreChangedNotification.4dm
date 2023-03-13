//%attributes = {}
/*

callback received no parameters

*/

$options:=New object:C1471


$options.startDate:=Add to date:C393(Current date:C33; 0; 0; -1)
$options.endDate:=Add to date:C393(Current date:C33; 0; 0; 1)

/*
optinally pass in $options.calendars
a. collection of calendar names
b. collection of objects where .uid == calendar ID
*/

$status:=iCal QUERY EVENT($options)

If ($status.success)
	
	$uid:=$status.events.extract("uid")
	
End if 
