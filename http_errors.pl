#!/usr/bin/perl

# A simple perl CGI script that accepts errors from a site, alerts, and saves to a database.  See README.md for more info.

use DBI;
use CGI; #(-debug);
use strict;
use warnings;
use URI::Encode qw(uri_decode);
use Capture::Tiny ':all';
use POSIX qw(strftime);

my $scriptname = 'http_errors';
my $date = get_date();
my $timestamp = strftime("%Y%m%d",localtime(time));
my $logdir = '/home/YOUR USER/logs'; # CHANGE THIS AND CREATE THE DIR
my $logfile = $logdir . '/' . $scriptname . '_' . $timestamp . '.txt';
my $delete_after = 30;
my @errors;
my $http_key = 'p5dAAHNK7HenGyk8ZGWwJ2VRtmFY'; # CHANGE THIS
my $alert_service = 'ntfy.sh/RGjum2rJEcCsp6'; # CHANGE THIS AND SET UP THE SERVICE AT ntfy.sh (free)

# db conn info
my $host = 'localhost';
my $database = 'YOUR DATABASE'; # CHANGE THIS
my $user = 'YOUR DB USER'; # CHANGE THIS
my $mysqlpassword = 'YOUR DB PASSWORD'; # CHANGE THIS

my $query = new CGI;

my $site = scalar $query->param('site');
my $error_msg = scalar $query->param('error');

if (!$query->http('X-AUTH') || $query->http('X-AUTH') ne $http_key) {
  print $query->header(-status => '401 Unauthorized', -type => 'application/json');
  print '{ "error": "Unauthorized" }';
  exit 0;
}

if (!$error_msg || !$site) {
  print $query->header(-status => '400 Bad Request', -type => 'application/json');
  print '{ "error": "Bad Request" }';
  exit 0;
}

open(LOG,">>$logfile") || die "cannot open log";

print $query->header(-status => '200', -type => 'application/json');
logger("ERROR (" . $site . "):" . $error_msg);

# insert into the db
my $dbh = DBI->connect("DBI:mysql:database=$database;host=$host","$user","$mysqlpassword",{'RaiseError'=>1});
eval {
  my $sql = "INSERT INTO error_logger SET `site` = ?, `error` = ?";
  my $sth = $dbh->prepare($sql);
  $sth->execute($site, $error_msg);
};
if ($@) { logger("SQL error: ". $@); }

$dbh->disconnect();

# if this is a 500, notify
if ($error_msg =~ /Internal Server Error/) {
  my $error_text = "Error 500 reported on ${site}";
  my ($stdout, $stderr, $exit) = capture {
    my $cmd = "/usr/bin/curl -d \"$error_text\" $alert_service";
    system($cmd);
  }
}

# return response data
print '{ "error": false }';

######################## SUBS ##########################

sub logger {
	my $message = shift;
	print LOG "${date}\t$message\n";
}

sub system_call {
	my ($cmd, $skipsafe) = @_;
	if (!$skipsafe) {
		$cmd =~ s/;//g; # bit of extra safety
		$cmd =~ s/\|//g;
	}
	#logger("system call: " . $cmd);
	my ($stdout, $stderr, $exit) = capture {
		system($cmd);
	};
	if ($exit == 1) {
		my $error = "problem with system call";
		push(@errors,$error);
		logger("ERROR: in system_call sub got error exit status, stderr is: ". $stderr);
	}
	return $stdout;
}

sub get_date {
	my $cmd = "/bin/date";
	my $date = system_call($cmd);
  $date =~ s/\n//g;
	return $date;
}

sub rotate_logs {
	my ($delete_after) = shift;
	if (!$delete_after) { $delete_after = 1; }
	my $cmd = "/usr/bin/find $logdir -maxdepth 1 -type f -name '${scriptname}_*.txt' -mtime +$delete_after -exec rm '{}' \\; -print";
	system_call($cmd);
}

close(LOG);
