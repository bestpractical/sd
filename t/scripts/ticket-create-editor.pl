#!/usr/bin/perl -i

# perl script to trick Proc::InvokeEditor with for the ticket create command

while (<>) {
     s/^summary:.*$/summary: creating tickets with an editor is totally awesome/;
     print;
     print "We can create a comment at the same time.\n" if /^===/;
}

