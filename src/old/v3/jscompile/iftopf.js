// Developed by Julian Cassin. 2019-2020.
//
// 2026 fixes (shunting yard):
//	- pops every operator that binds tighter or equal, not just one
//	- operators on the same level share one precedence (* / %, + -, etc)
//	- ** and assignments are right to left
//
function IFtoPF(str_a, arrFunctions_a)
{
	var arrResultStack = [];
	var arrOperatorStack = [];
	var blnElementComplete = false;
	var blnEndBrace = false;
	var blnInIdentifier = false;
	var blnInOperator = false;
	var blnOpenBrace = false;
	var blnProceed = true;
	var blnSpecialChars = false;
	var lngI = 0;
	var strChar = '';
	var strElement = '';
	var strOperand = '';
	var strOperator = '';
	var strTopOperator = '';
	var strResult = '';

	// operators in precedence order
	var OPERATORS = ['_NEW_', '_!_', '_~_', '_++_', '_--_', '_**_', '_*_', '_/_', '_%_', '_+_', '_-_', '_<<_', '_>>_', '_>>>_', '_<_', '_<=_', '_>_', '_>=_', '_==_', '_!=_', '_===_', '_!==_', '_&_', '_^_', '_|_', '_&&_', '_||_', '_+=_', '_-=_', '_**=_', '_*=_', '_/=_', '_%=_', '_<<=_', '_>>=_', '_>>>=_', '_&=_', '_^=_', '_|=_']; // -x, TYPEOF, DELETE, IN, INSTANCEOF, ++x, --x unsupported, = treated special

	// utils
	function doNothing()
	{
		var todo = 'this function is just to stop lint errors where we dont want to do anything';
	}

	function todo()
	{
		var todo = 'this function is just to stop lint errors where we things to do';
	}

	strElement = '';
	strOperand = '';
	lngI = 0;
	while (lngI <= str_a.length)
	{
		blnEndBrace = false;
		blnElementComplete = false;
		blnOpenBrace = false;
		blnProceed = true;
		blnSpecialChars = false;
		if (lngI < str_a.length)
		{
			strChar = str_a.substr(lngI, 1);
		}
		else
		{
			strChar = '';
		}

		if (blnInIdentifier)
		{
			if (maybeIdentifier(strChar))
			{
				strElement += strChar;
			}
			else
			{
				blnElementComplete = true;
				blnInIdentifier = false;
				blnProceed = false;
			}
		}
		else if (blnInOperator)
		{
			if (maybeOperator(strChar))
			{
				strElement += strChar;
			}
			else
			{
				blnElementComplete = true;
				blnInOperator = false;
				blnProceed = false;
			}
		}
		else
		{
			if (maybeIdentifier(strChar))
			{
				strElement += strChar;
				blnInIdentifier = true;
			}
			else if (maybeOperator(strChar))
			{
				strElement += strChar;
				blnInOperator = true;
			}
			else
			{
				blnSpecialChars = true;
			}
		}

		// special characters
		if (blnSpecialChars)
		{
			if (strChar === '')
			{
				// do nothing
				doNothing();
			}
			else if (strChar === ' ')
			{
				strChar = ''; // whitespace becomes nothing
			}
			else if (strChar === ';')
			{
				blnElementComplete = true;
				strChar = '';
			}
			else if (strChar === '(')
			{
				blnElementComplete = true;
				blnOpenBrace = true;
			}
			else if (strChar === ')')
			{
				blnElementComplete = true;
				blnEndBrace = true;
			}
		}

		// end of line hanlding
		if (lngI == str_a.length)
		{
			if (!blnElementComplete)
			{
				strElement = strElement + strChar;
				blnElementComplete = true;
			}
		}

		if (blnElementComplete)
		{
			if (isOperator(OPERATORS, strElement)) // word operator
			{
				strOperator = strElement;
				strElement = '';
				//alert('operator:' + strOperator);
			}
			else if (isIdentifier(strElement))
			{
				// todo
				todo();
			}
			else if (isFunction(arrFunctions_a, strElement))
			{
				// todo
				todo();
			}
			else
			{
				strOperand = strElement;
				strElement = '';
				//alert('operand:' + strOperand);
			}

			if (strOperand.length > 0)
			{
				arrResultStack.push(strOperand);
			}

			if (strOperator.length > 0)
			{
				// pop every operator that binds tighter, or the same and left to right
				while (arrOperatorStack.length > 0)
				{
					strTopOperator = arrOperatorStack[arrOperatorStack.length - 1];
					if ((strTopOperator === '(') ||
						(precedence(OPERATORS, strTopOperator) > precedence(OPERATORS, strOperator)) ||
						((precedence(OPERATORS, strTopOperator) === precedence(OPERATORS, strOperator)) && isRightToLeft(strOperator)))
					{
						break;
					}
					arrResultStack.push(arrOperatorStack.pop());
				}
				arrOperatorStack.push(strOperator);
			}

			strOperand = '';
			strOperator = '';

			if (blnOpenBrace)
			{
				arrOperatorStack.push(strChar);
			}

			if (blnEndBrace)
			{
				strOperator = '';
				while ((arrOperatorStack.length > 0) && (strOperator != '('))
				{
					strOperator = arrOperatorStack.pop();
					if (strOperator != '(')
					{
						arrResultStack.push(strOperator);
					}
				}
				strOperator = '';
			}
		}

		if (blnProceed)
		{
			lngI++;
		}
	}

	while (arrOperatorStack.length > 0)
	{
		strOperator = arrOperatorStack.pop();
		if (strOperator != '(')
		{
			arrResultStack.push(strOperator);
		}
	}

	while (arrResultStack.length > 0)
	{
		strOperand = arrResultStack.pop();
		strResult = strOperand + ' ' + strResult;
	}

	//alert(str_a + ":" + strResult);
	return strResult;
}

function isFunction(arrFunctions_a, str_a)
{
	return false;	// todo look up arrFunctions_a
}

function isIdentifier(str_a)
{
	return false;
}

function isOperator(arrOperators_a, strOperator_a)
{
	return (arrOperators_a.indexOf('_' + strOperator_a + '_') > -1);
}

function isRightToLeft(strOperator_a)
{
	return ((strOperator_a === '**') || (strOperator_a.substr(strOperator_a.length - 1, 1) === '=') && (precedence([], strOperator_a) === 13));
}

function maybeIdentifier(str_a)
{
	return ("abcdefghijklmnopqrstuvwxyz1234567890_".indexOf(str_a.toLowerCase()) > -1);
}

function maybeOperator(str_a)
{
	return ("!~+-*/%<>=&^|%".indexOf(str_a.toLowerCase()) > -1);
}

// lower binds tighter, operators on the same level share a number
function precedence(arrOperators_a, strOperator_a)
{
	var PRECEDENCE = {
		'NEW': 0,
		'!': 1, '~': 1, '++': 1, '--': 1,
		'**': 2,
		'*': 3, '/': 3, '%': 3,
		'+': 4, '-': 4,
		'<<': 5, '>>': 5, '>>>': 5,
		'<': 6, '<=': 6, '>': 6, '>=': 6,
		'==': 7, '!=': 7, '===': 7, '!==': 7,
		'&': 8,
		'^': 9,
		'|': 10,
		'&&': 11,
		'||': 12,
		'+=': 13, '-=': 13, '**=': 13, '*=': 13, '/=': 13, '%=': 13, '<<=': 13, '>>=': 13, '>>>=': 13, '&=': 13, '^=': 13, '|=': 13
	};
	var intResult = -1;

	if (PRECEDENCE[strOperator_a] !== undefined)
	{
		intResult = PRECEDENCE[strOperator_a];
	}

	return intResult;
}
