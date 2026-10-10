function element(strScope_a, strElement_a)
{
	var objResult  = null;
	var strElement = strElement_a;
	var strScope   = strScope_a;

	if (strElement === undefined)
	{
		objResult = $(strScope);
	}
	else
	{
		objResult = $(strElement, strScope);
	}

	return objResult;
}

// prefix added because mysql doesn't like certain patterns of GUIDs for field names
// eg: 6e4 gets confused by mysql as a standard form number
function getGUID(strPrefix_a)
{
	var strPrefix = strPrefix_a;
	if (strPrefix == undefined) { strPrefix = ''; }

	return strPrefix + 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(strChar)
	{
		var intR = Math.random() * 16 | 0,
		intV = strChar == 'x' ? intR : (intR & 0x3 | 0x8);
		return intV.toString(16);
	});
}

function htmlEncode(strValue_a)
{
    return String(strValue_a || '').
        replace(/&/g, '&amp;').
        replace(/</g, '&lt;').
        replace(/>/g, '&gt;');
}
