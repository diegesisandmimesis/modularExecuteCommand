#charset "us-ascii"
//
// modularExecuteCommandDebug.t
//
//	Debugging methods for the modularExecuteCommand stuff.
//
#include <adv3.h>
#include <en_us.h>

#ifdef __DEBUG_MODULAR_EXECUTE_COMMAND

#include <reflect.t>

modify ModularExecuteCommandObject
	// Log the passed message.  Prefixes the value of the
	// object's modularExecuteCommandID, if set.
	_debug(msg?) {
		aioSay('\n<<(modularExecuteCommandID
			? '<<modularExecuteCommandID>>: '
			: '')>><<msg>>\n ');
	}

	// Debug a list.
	_debugList(lst) {
		local l;

		if(lst == nil) {
			_debug('_debugList():  nil list');
			return;
		}
		_debug('=====_debugList() start=====');
		_debug('lst.length = <<toString(lst.length)>>');

		lst.forEach(function(obj) {
			if(obj == nil) {
				_debug('object is nil');
				return;
			}
			_debug(reflectionServices.valToSymbol(obj));
			if((l = obj.getPropList()) == nil) {
				_debug('no properties');
				return;
			}
			l.forEach(function(o) {
				if(!obj.propDefined(o, PropDefAny))
					return;
				_debug('\t'
					+ reflectionServices.valToSymbol(o)
					+ ' = '
					+ reflectionServices.valToSymbol(
						obj.(o)));
			});
		});
		_debug('=====_debugList() end=====');
	}

	// Debug an object, shallowly.
	_debugObject(obj, lbl?) {
		_debug((lbl ? lbl : '')
			+ '<<reflectionServices.valToSymbol(obj)>>');
	}

	// Debug an object, fully.
	_debugObjectFull(obj) {
		local l;

		if(obj == nil) {
			_debug('nil object');
			return;
		}

		if((l = obj.getPropList()) == nil) {
			_debug('\t[no properties]\n ');
			return;
		}
		l.forEach(function(o) {
			if(!obj.propDefined(o, PropDefAny))
				return;
			_debug('\t' + reflectionServices.valToSymbol(o) + ' = '
				+ reflectionServices.valToSymbol(obj.(o)));
		});
	}
;

#endif // __DEBUG_MODULAR_EXECUTE_COMMAND
