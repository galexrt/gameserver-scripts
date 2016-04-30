#!/usr/bin/perl -w
# This script has been written by Alexander Trost <galexrt@googlemail.com>

use strict;
use warnings;
use diagnostics;

use Net::SRCDS::Queries;
use Socket;
use Term::Encoding qw(term_encoding);

# SRCDS is listening on local server, local address
my $serverPath = "PATH_TO_YOUR_SERVER_FOLDER"; # The path to your server folder
$serverPath =~ s/\/$//g;
my $restartCommand = "";
my $restartWorkDirectory = "";
if ($restartWorkDirectory eq "") {
    $restartWorkDirectory = $serverPath;
}
my $addr= "127.0.0.1";
my $port = 27015;
my $encoding = term_encoding;

my $q = Net::SRCDS::Queries->new(
    encoding => $encoding, # set encoding to convert from utf8
    timeout  => 10, # change timeout. default is 3 seconds
);
$q->add_server($addr, $port);
my $result = $q->get_all;

if (not defined $result) {
    print("Server unreachable.\n");
    my @output = runCMD("echo 'unreachable' >> \'" . $serverPath . "/.server_status'; grep \'unreachable\' \'" . $serverPath . "/.server_status\' | wc -l");
    my $unreachCount = $output[0];
    if ($output[1]) {
        print("=> There was an error, getting the \'unreachable\' count. Please check the \'" . $serverPath . "/.server_status\' file.");
        exit(2);
    }
    $unreachCount =~ s/^\s+|\s+$//g;
    if ($unreachCount == 5) {
        print("* Server was now unreachable, since 5 tries.\n");
        print("=> Forcing server restart.\n");
        my @restartOutput = runCMD("cd " . $restartWorkDirectory . "; " . $restartCommand);
        if (pop(@restartOutput) > 0) {
            print("=> There was an error restarting the server.\n");
            exit(1);
        }
        else {
            print("=> Server restart successfull! Hibernating till next check.\n");
            exit(0);
        }
    }
}
elsif (ref $result eq "HASH") {
    print("Server reachable.\n");
    my @output = runCMD("echo '' > " . $serverPath . "/.server_status");
    if (pop(@output) > 0) {
        print("=> Error while resetting the \'" . $serverPath . "/server_status\' file.\n");
        exit(1);
    }
    exit(0);
} else {
    print("=> Unknonw response from SRCDS::Queries object received.\n");
    exit(1);
}

sub runCMD {
  my ($command) = @_;
  my @output = `$command`;
  return @output, $? >> 8;
}
