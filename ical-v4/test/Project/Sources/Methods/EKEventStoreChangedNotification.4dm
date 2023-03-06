//%attributes = {}
#DECLARE($info : Text)

$message:=Split string:C1554($info; "\t")

ALERT:C41("URI:"+$message[0]+"\rUID:"+$message[1])