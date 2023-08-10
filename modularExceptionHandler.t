#charset "us-ascii"
//
// modularExceptionHandler.t
//
//	Exception handlers declarations.
//
//	Instead of hardcoding exception handlers in a static try/catch
//	block, we define a ModularExceptionHandler class.  At preinit,
//	the module iterates through each declared instance of this
//	class and adds it to the list of exception handlers it'll
//	use when an exception is thrown in the main parse loop.
//
#include <adv3.h>
#include <en_us.h>

// The follow values can be returned by a handler's handle() method.
// mehReturn means that the caller should immediately return.
// mehContinue means that command evaluation should continue.
enum mehReturn, mehContinue;

class ModularExceptionHandler: ModularExecuteCommandObject
	modularExecuteCommandID = 'ModularExceptionHandler'

	// The type of exception this handler is for.  Should probably
	// always be the name of an Exception class.
	type = nil

	execState = modularExecuteCommand
	clearExecState() { execState.clearExecState(); }

	// The handler method.  Should be overwritten by each handler
	// to do whatever the handler is supposed to do.
	handle(ex) { return(mehReturn); }
;

mehParseFailure: ModularExceptionHandler
	type = ParseFailureException
	handle(rfExc) {
		_debug('===ParseFailureException===');
		rfExc.notifyActor(execState.dstActor, execState.srcActor);
		clearExecState();
		return(mehReturn);
	}
;

mehCancelCommandLine: ModularExceptionHandler
	type = CancelCommandLineException
	handle(ccExc) {
		_debug('===CancelCommandLineException===');
		if(execState.nextCommandTokens != nil)
			execState.dstActor.getParserMessageObj().
				explainCancelCommandLine();
		clearExecState();
		return(mehReturn);
	}
;

mehTerminateCommand: ModularExceptionHandler
	type = TerminateCommandException
	handle(tcExc) {
		_debug('===TerminateCommandException===');
		clearExecState();
		return(mehReturn);
	}
;

mehRetryCommandTokens: ModularExceptionHandler
	type = RetryCommandTokensException
	handle(rctExc) {
		_debug('===RetryCommandTokensException===');
		execState.toks = rctExc.newTokens_ + execState.extraTokens;
		//r = true;
		return(mehContinue);
	}
;

mehReplacementCommandString: ModularExceptionHandler
	type = ReplacementCommandStringException
	handle(rcsExc) {
		local str;

		_debug('===ReplacementCommandStringException===');
		str = rcsExc.newCommand_;
		if(str == nil)
			return(mehReturn);
		execState.toks = cmdTokenizer.tokenize(str);
		execState.first = true;
		execState.srcActor = rcsExc.issuingActor_;
		execState.dstActor = rcsExc.targetActor_;
		execState.dstActor.addPendingCommand(true, execState.srcActor,
			execState.toks);
		clearExecState();
		//return;
		return(mehReturn);
	}
;
