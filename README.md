![version](https://img.shields.io/badge/version-19%2B-5682DF)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-ical-v4)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-ical-v4/total)

# 4d-plugin-ical-v4

iCal API with notification support

See [v3 documentation](https://github.com/miyako/4d-plugin-ical-v3) for basic information.

## Notification

```4d
iCal SET NOTIFICATION METHOD($method)
$method:=iCal Get notification method()
```

|Parameter|Type|Description|
|:-:|:-:|:-:|
|method|TEXT|callback method name|

The callback method receives no parameters. You can perform a query to get the latest events.

Example:

```4d
$options:=New object


$options.startDate:=Add to date(Current date; 0; 0; -1)
$options.endDate:=Add to date(Current date; 0; 0; 1)

/*
	optinally pass in $options.calendars
	a. collection of calendar names
	b. collection of objects where .uid == calendar ID
*/

$status:=iCal QUERY EVENT($options)

If ($status.success)
	
	$uid:=$status.events.extract("uid")
	
End if 
```
