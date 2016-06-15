#!/usr/bin/perl -w
# server_restarter.pl -- SRCDS server checker and restarter
#
# Copyright (C) 2016 Alexander Trost
# All rights reserved.
#
# This software may be modified and distributed under the terms
# of the MIT license.  See the LICENSE file for details.

use strict;
use warnings;
use diagnostics;

use Net::SRCDS::Queries;
use Socket;
use Term::Encoding qw(term_encoding);

# SRCDS Server inforatmion
my $serverPath = "PATH_TO_YOUR_SERVER_FOLDER"; # The path to your server folder
my $serverStatusFilename = ".server_status";
my $addr = "127.0.0.1"; # Reachable server address
my $port = 27015; # SRCDS port
my $restartCommand = "";
my $restartWorkDirectory = "";
my $resetAfterLines = 216000;
my $queryTimeout = 12;
my $maxUnreachCount = 3;
# </Configuration END>

my $encoding = term_encoding;
$serverPath =~ s/\/$//g;
if ($restartWorkDirectory eq "") {
    $restartWorkDirectory = $serverPath;
}

my $q = Net::SRCDS::Queries->new(
    encoding => $encoding, # set encoding to convert from utf8
    timeout  => int($queryTimeout),
);
$q->add_server($addr, $port);
my $result = $q->get_all;

if (not defined $result) {
    isNotReachable();
}
elsif (ref $result eq "HASH") {
    isReachable();
} else {
    print STDERR "=> Unknown response from SRCDS::Queries object received.\n";
    exit(1);
}

resetFile();
exit(0);

sub runCMD {
  my ($command) = @_;
  my @output = `$command`;
  return @output, $? >> 8;
}
sub isNotReachable {
    my @output = runCMD("echo `date` unreachable >> \"" . $serverPath . "/" . $serverStatusFilename . "\";tail -n 5 \"" . $serverPath . "/" . $serverStatusFilename . "\" | grep \'unreachable\' \"" . $serverPath . "/" . $serverStatusFilename . "\" | wc -l");
    my $unreachCount = $output[0];
    if (pop(@output) > 0) {
        print STDERR "=> There was an error, getting the \'unreachable\' count. Please check the \"" . $serverPath . "/" . $serverStatusFilename ."\" file.\n";
        exit(1);
    }
    $unreachCount =~ s/^\s+|\s+$//g;
    if ($unreachCount == $maxUnreachCount) {
        print STDERR "=> Server was five times unreachable, forcing server restart.\n";
        my @restartOutput = runCMD("cd \"" . $restartWorkDirectory . "\"; " . $restartCommand);
        if (pop(@restartOutput) > 0) {
            print STDERR "=> There was an error restarting the server.\n";
            exit(1);
        }
        else {
            print STDERR "=> Server restart successfull! Hibernating till next check.\n";
        }
    }
}
sub isReachable {
    print("=> Server reachable.\n");
    my @output = runCMD("echo `date` reachable >> \"" . $serverPath . "/" . $serverStatusFilename . "\"");
    if (pop(@output) > 0) {
        print STDERR "=> Error while resetting the \"" . $serverPath . "/" . $serverStatusFilename . "\" file.\n";
        exit(1);
    }
}

sub resetFile {
    my @output = runCMD("wc -l \"" . $serverPath . "/" . $serverStatusFilename . "\"");
    if (pop(@output) > 0) {
        my @lines = split(/\s+/, $output[0]);
        if (not defined $lines[0]) {
            print STDERR "=> Error getting the wc line count of the server status file.\n";
            exit(1);
        }
        my $lineCount = $lines[0];
        if ($lineCount >= $resetAfterLines) {
            @output = runCMD("tail -n 15 \"" . $serverPath . "/" . $serverStatusFilename);
            if (pop(@output) > 0) {
                print STDERR "=> Error tailing the last 15 lines.\n";
                exit(1);
            }
            my $first = 1;
            foreach my $line (@output) {
                my $redir = ">";
                if ($first) {
                    $first = 0;
                    $redir .= ">";
                }
                my @out = runCMD("echo " . $line . " " . $redir . " \"" . $serverPath . "/" . $serverStatusFilename);
                if (pop(@out) > 0) {
                    print STDERR "=> Error resetting file.\n";
                    exit(1);
                }
            }
        }
    }
}
