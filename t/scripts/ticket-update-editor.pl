#!/usr/bin/perl -i

# perl script to trick Proc::InvokeEditor with for the ticket update command

while (<>) {
     s/^summary:.*$/summary: summary changed/;
     s/^owner:.*//;
     print;
     print "We can create a comment at the same time.\n" if /^===/;
}

