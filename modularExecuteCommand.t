#charset "us-ascii"
//
// modularExecuteCommand.t
//
#include <adv3.h>
#include <en_us.h>

// Module ID for the library
modularExecuteCommandModuleID: ModuleID {
        name = 'Modular executeCommand() Library'
        byline = 'Diegesis & Mimesis'
        version = '1.0'
        listingOrder = 99
}

class ModularExecuteCommandObject: object
	modularExecuteCommandID = nil
	_debug(msg?) {}
	_debugList(lst) {}
	_debugObject(obj, lbl?) {}
;

// The only place that calls executeCommand() is
// PendingCommandToks.executePending(), so instead of replacing executeCommand()
// outright, we implement our own and just call our bespoke version first.
// This is done in the belief that what we're here for (handling bare noun
// phrases on the command line) is more straightforward than general command
// parsing, so we prefer using the stock version instead of our own when
// possible (because we might have missed some weird corner cases).
modify PendingCommandToks
	executePending(targetActor) {
		modularExecuteCommand.execCommand(targetActor, issuer_,
			tokens_, startOfSentence_);
	}
;

// Our executeCommand() replacement is a singleton with a bunch of methods.
modularExecuteCommand: ModularExecuteCommandObject, PreinitObject
	// Debugging identifier
	modularExecuteCommandID = 'modularExecuteCommand'

	// All the properties are variables from the native executeCommand(),
	// which we save as properties just to avoid having messy
	// calling semantics on all of the methods.  We set most of them
	// when we're called and clean up when we're done (to avoid dangling
	// reference problems) but otherwise we don't worry too much about
	// for example trying to pretend we're writing thread-safe code.
	//
	// The first four properties are the arguments to executeCommand()
	srcActor = nil
	dstActor = nil
	toks = nil
	first = nil
	//
	// The remainder of these props are bookkeeping for multi-command
	// inputs.
	extraIdx = nil
	extraTokens = nil
	nextCommandTokens = nil
	nextIdx = nil
	//
	// Used when a command is addressed at an actor other than the one
	// issuing the command.
	actorPhrase = nil
	actorSpecified = nil

	// General parsing settings.  Used as defaults.
	// Most things will never have to touch these.
	//
	// The command dictionary.
	dict = cmdDict
	//
	// The grammatical production for the first command in an input.
	firstPhrase = firstCommandPhrase
	//
	// The grammatical production for subsequent commands in an input.
	otherPhrase = commandPhrase

	// Set automagically at preinit.
	_exceptionHandlers = nil

	// Do preinit setup.
	execute() {
		// Create our list of exception handlers.
		_initExceptionHandlers();
	}

	// Go through all instances of ModularExceptionHandler and remember
	// them.
	_initExceptionHandlers() {
		_exceptionHandlers = new Vector();
		forEachInstance(ModularExceptionHandler, function(o) {
			_exceptionHandlers.append(o);
		});
	}

	// Clear out all of our properties.
	clearState() {
		srcActor = nil;
		dstActor = nil;
		toks = nil;
		first = nil;

		extraIdx = nil;
		extraTokens = nil;
		nextCommandTokens = nil;
		nextIdx = nil;

		actorPhrase = nil;
		actorSpecified = nil;
	}

	// Remember the arguments to executeCommand()
	setArgs(dst, src, t, fst) {
		srcActor = src;
		dstActor = dst;
		toks = t;
		first = fst;
	}

	// Drop-in replacement for adv3's executeCommand().
	// Should only be called from PendingCommandToks.executePending().
	execCommand(dst, src, t, fst) {
		local r;

		// Start from scratch every time we're called.
		clearState();

		// Remember our arguments.
		setArgs(dst, src, t, fst);

		libGlobal.enableSenseCache();
		setSenseContext();

		// More or less equivalent to the parseTokenLoop: loop
		// from executeCommand().  We loop through the tokens
		// until we're done or something throws an exception.
		r = true;
		while(r) {
			try {
				r = parseLoop();
			}
			// One of the reasons we bothered to re-implement
			// executeCommand().  Here we catch the custom
			// exception we might have thrown elsewhere.  If
			// we get this, it means we're not going to handle
			// a keyword action, so we punt things off to
			// the stock executeCommand().
			catch(Exception ex) {
				// See if we have a handler for this
				// kind of exception.  
				switch(exceptionHandler(ex)) {
					// Go through the parse loop again.
					case mehContinue:
						r = true;
						break;
					// Immediately return.
					case mehReturn:
						return;
					// We got an exception we didn't know
					// how to handle, re-throw it.
					// IMPORTANT:  We HAVE to do this,
					// 	because some commands, like
					//	>QUIT, function by throwing
					//	an exception that is caught
					//	elsewhere.
					default:
						throw ex;
				}
			}
		}
	}

	// Main parse loop.  More or less equivalent to the labelled loop
	// inside the native executeCommand().
	parseLoop() {
		local action, lst, match, rankings;

		// Clear the extra tokens list.
		extraTokens = [];

		// Make sure we can obtain a command list. 
		if((lst = getCommandList()) == nil)
			return(nil);

		_debug('getCommandList() returned
			<<toString(lst.length())>> candidates');

		// Pick a match from the list.
		rankings = getRankings(lst);
		match = getMatch(rankings);
		dbgShowGrammarWithCaption('Winner', match);

		// Bookkeeping for multi-command inputs.
		updateTokens(match);

		// Get the action from our chosen match.
		action = getFirstAction(match);

		if(match.hasTargetActor())
			return(handleActorMatch(match));

		if(rankings[1].unknownWordCount != 0) {
			_debug('===unknownWordCount===');
			match.resolveNouns(srcActor, dstActor,
				new OopsResults(srcActor, dstActor));
		}

		updateSenseContext(action);

		runCommand(action);

		cleanup(match);

		return(nil);
	}

	// Generic exception handler method.
	// The argument is the exception, as caught by catch() above.
	exceptionHandler(ex) {
		local i, o;

		for(i = 1; i <= _exceptionHandlers.length(); i++) {
			o = _exceptionHandlers[i];

			// If we have a handler that handles the
			// type of exception we have, we're done.
			// Call it, and return its return value.
			if((o.type != nil) && ex.ofKind(o.type))
				return(o.handle(ex));
		}

		// Nope, we didn't have any matching handlers, fail.
		return(nil);
	}

	// Set the sense context, if necessary.  This happens at the
	// start of the parsing loop, before the input tokens are resolved
	// into an action.  For setting sense context AFTER action resolution,
	// see updateSenseContext() below.
	setSenseContext() {
		if(first && (srcActor != dstActor)
			&& srcActor.revertTargetActorAtEndOfSentence) {
			dstActor = srcActor;
			senseContext.setSenseContext(srcActor, sight);
		}
	}

	// Update the sense context.  This happens after action resolution,
	// immediately before executing the action.
	updateSenseContext(action) {
		if((action != nil) && action.isConversational(srcActor)) {
			senseContext.setSenseContext(srcActor, sight);
		} else if(actorSpecified && (srcActor != dstActor)) {
			senseContext.setSenseContext(dstActor, sight);
		}
	}


	// Returns the list of candidate commands from parseTokens(), if
	// any.
	callParseTokens() {
		local lst, prod;

		// Figure out which production to use.
		prod = (first ? firstPhrase : otherPhrase);

		lst = prod.parseTokens(toks, dict);

		_debug('\tparseTokens() returned <<toString(lst.length)>>
			actions');

		lst = lst.subset({ x: x.resolveFirstAction(srcActor, dstActor) != nil });

		_debug('\tresolveFirstAction() returned <<toString(lst.length)>>
			actions');

		_debugList(lst);
		dbgShowGrammarList(lst);

		return(lst);
	}

	// See if we can obtain a command list from parseTokens().
	getCommandList() {
		local lst;

		lst = callParseTokens();
		if(lst.length() == 0) {
			handleEmptyActionList();
			return(nil);
		}

		return(lst);
	}

	// Sort the candidate commands by ranking.
	getRankings(lst) {
		return(CommandRanking.sortByRanking(lst, srcActor, dstActor));
	}

	// Pick a winner from the list of candidate commands.
	getMatch(rankings) {
		return(rankings[1].match);
	}

	updateTokens(match) {
		nextIdx = match.getNextCommandIndex();
		nextCommandTokens = toks.sublist(nextIdx);

		if(nextCommandTokens.length() == 0)
			nextCommandTokens = nil;

		extraIdx = match.tokenList.length() + 1;
		extraTokens = toks.sublist(extraIdx);
	}

	// Get the action from the highest-ranked command match.
	getFirstAction(match) {
		return(match.resolveFirstAction(srcActor, dstActor));
	}

	// Here's where we actually attempt to execute the resolved action.
	runCommand(action) {
		withCommandTranscript(CommandTranscript, function() {
			_debug('===executeAction start===');
			executeAction(dstActor, actorPhrase, srcActor,
				(actorSpecified && (srcActor != dstActor)),
				action);
			_debug('===executeAction end===');
		});
	}

	// End-of-parse-loop bookkeeping.
	cleanup(match) {
		cleanupNextCommandTokens(match);
		cleanupIssuedCommand();
	}

	// Bookkeeping for multi-command inputs.
	cleanupNextCommandTokens(match) {
		if(nextCommandTokens != nil) {
			dstActor.addFirstPendingCommand(match.isEndOfSentence(),
				srcActor, nextCommandTokens);
		}
	}

	// Bookkeeping for commands issued to another actor.
	cleanupIssuedCommand() {
		if(actorSpecified && (srcActor != dstActor))
			srcActor.waitForIssuedCommand(dstActor);
	}

	handleActorMatch(match) {
		local actorResults;

		if(!actorSpecified && (srcActor != dstActor)) {
			if(!srcActor.issueCommandsSynchronously) {
				senseContext.setSenseContext(nil, sight);
				srcActor.getParserMessageObj()
					.cannotChangeActor();
				return(nil);
			}
			srcActor.addFirstPendingCommand(first, srcActor, toks);
			return(nil);
		}

		actorResults = new ActorResolveResults();
		actorResults.setActors(dstActor, srcActor);

		match.resolveNouns(srcActor, dstActor, actorResults);
		dstActor = match.getTargetActor();
		actorPhrase = match.getActorPhrase();

		dstActor.copyPronounAntecedentsFrom(srcActor);
		match.execActorPhrase(srcActor);
		if(!dstActor.acceptCommand(srcActor))
			return(nil);
		actorSpecified = true;
		toks = match.getCommandTokens();
		first = nil;

		return(true);
	}

	handleEmptyActionList() {
		local i, lst;

		if(first) {
			lst = actorBadCommandPhrase.parseTokens(toks, cmdDict);
			lst = lst.mapAll({
				x: x.resolveNouns(srcActor, srcActor,
					new TryAsActorResolveResults())
			});
			if((lst.length() == 0)
				&& (i = lst.indexWhich({
					x: x[1].obj_.ofKind(Actor)
				}) != nil)) {
				targetActor = lst[i][1].obj_;
			}
		}
		tryOops(toks, srcActor, dstActor, 1, toks, rmcCommand);
		if(specialTopicHistory.checkHistory(toks)) {
			dstActor.notifyParseFailure(srcActor,
				&specialTopicInactive, []);
		} else {
			dstActor.notifyParseFailure(srcActor,
				&commandNotUnderstood, []);
		}
	}
;
