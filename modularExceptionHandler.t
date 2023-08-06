#charset "us-ascii"
//
// modularExceptionHandler.t
//
#include <adv3.h>
#include <en_us.h>

// The follow values can be returned by a handler's handle() method.
// mehReturn means that the caller should immediately return.
// mehContinue means that command evaluation should continue.
enum mehReturn, mehContinue;

class ModularExceptionHandler: ModularExecuteCommandObject
	modularExecuteCommandID = 'ModularExceptionHandler'
	execState = modularExecuteCommand

	clearExecState() { execState.clearExecState(); }
	handle(ex) { return(mehReturn); }
;

mehParseFailure: ModularExceptionHandler
	handle(rfExc) {
		_debug('===ParseFailureException===');
		rfExc.notifyActor(execState.dstActor, execState.srcActor);
		clearExecState();
		return(mehReturn);
	}
;

mehCancelCommandLine: ModularExceptionHandler
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
	handle(tcExc) {
		_debug('===TerminateCommandException===');
		clearExecState();
		return(mehReturn);
	}
;

mehRetryCommandTokens: ModularExceptionHandler
	handle(rctExc) {
		_debug('===RetryCommandTokensException===');
		execState.toks = rctExc.newTokens_ + execState.extraTokens;
		//r = true;
		return(mehContinue);
	}
;

mehReplacementCommandString: ModularExceptionHandler
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
