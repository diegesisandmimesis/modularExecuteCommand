#charset "us-ascii"
//
// sample.t
// Version 1.0
// Copyright 2022 Diegesis & Mimesis
//
// This is a very simple demonstration "game" for the modularExecuteCommand
// library.  It is designed to exercise basic parser functionality, running
// non-interactively from a script.
//
// It can be compiled via the included makefile with
//
//	# t3make -f makefile.t3m
//
// ...or the equivalent, depending on what TADS development environment
// you're using.
//
// This "game" is distributed under the MIT License, see LICENSE.txt
// for details.
//
#include <adv3.h>
#include <en_us.h>

#include "modularExecuteCommand.h"

// This isn't actually needed and is only here to demonstrate that the
// regression testing logic will work in parallel with an existing game world.
startRoom: Room 'Void' "This is a featureless void. ";
+me: Person;

versionInfo: GameID;
gameMain: GameMainDef initialPlayerChar = me;
