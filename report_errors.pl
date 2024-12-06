#!/usr/bin/perl

# reports errors from the error_logger table in the database.  See readme.

use DBI;
use strict;
use warnings;
use Capture::Tiny ':all';
use POSIX qw(strftime);

my $scriptname = 'report_errors';
my $outfile = '/home/twr/tmp/emailed_error_report.txt';
my $email = 'YOUR EMAIL'; # CHANGE THIS
my $interval_min = 5;
my $notification_threshold = 15;
my $alert_service = 'ntfy.sh/RGjum2rJEcCsp6'; # CHANGE THIS AND SET UP THE SERVICE AT ntfy.sh (free)

# db conn info
my $host = 'localhost';
my $database = 'YOUR DATABASE'; # CHANGE THIS
my $user = 'YOUR USER'; # CHANGE THIS
my $mysqlpassword = 'YOUR PASSWORD'; # CHANGE THIS

my $instances = check_alive($scriptname);
if ($instances > 1) {
	print "instance already running\n";
	exit 1;
}

open(LOG,">$outfile") || die "cannot open log";
my $errors = 0;
my $dbh = DBI->connect("DBI:mysql:database=$database;host=$host","$user","$mysqlpassword",{'RaiseError'=>1});
my $sql = "SELECT site,error,timestamp FROM error_logger WHERE timestamp >= DATE_SUB(NOW(), INTERVAL $interval_min MINUTE)";
my $sth = db_query($sql);
while (my $ref = $sth->fetchrow_hashref) {
  $errors++;
  print LOG "SITE: $ref->{'site'}\n";
  print LOG "TIMESTAMP: $ref->{'timestamp'}\n";
  print LOG "ERROR: $ref->{'error'}\n";
  print LOG "\n\n----------------------------------------------------------------------------------------------\n\n";
}
$dbh->disconnect();
close(LOG);

if ($errors) {
  print "Reporting app failures\n";
  my $error_text = "$errors App Failures in the last $interval_min minutes";
  my $cmd = "/usr/bin/cat ${outfile} | /usr/bin/mail -s \"$error_text\" ${email}";
	my ($stdout, $stderr, $exit) = capture {
		system($cmd);
	};

  if ($errors >= $notification_threshold) {
    my ($stdout2, $stderr2, $exit2) = capture {
      my $cmd2 = "/usr/bin/curl -d \"$error_text\" $alert_service";
      system($cmd2);
    }
  }
}

# delete some old entries
my $sth2 = db_query("DELETE FROM error_logger WHERE timestamp < DATE_SUB(NOW(), INTERVAL 30 DAY)");


######################## SUBS ##########################

sub db_query {

	my $query = shift;
	my $sth = $dbh->prepare("$query");
	#print $query;
	$sth->execute;
	#print $dbh->err;
	my $err = $dbh->err;
	my $errstr = $dbh->errstr;
	return $sth;

} # end sub db_query

sub check_alive {
	# gets the PID of the process that matches a SINGLE criteria

	my ($text) = shift;
	my $return_pid = "";
	my $count = 0;
	my $return_count = 0;

  my $who = `whoami`;
  $who =~ s/\s+//g;
	my $pidgetter = "/bin/ps axo pid,user:20,comm | grep '$who' | grep '$text' | grep -v 'grep' | grep -v 'sh -c'";
	#print "checking for running program with $pidgetter\n";
	my @raw_pids = `$pidgetter`;
	chomp(@raw_pids);

	foreach my $raw_pid (@raw_pids) {
		$count++;
		#print "RAW $count: $raw_pid\n";
		$raw_pid =~ s/^\s+//;
		$raw_pid =~ /^(\d+)\s/;
		$raw_pid = $1;
		$raw_pid =~ s/\D//g;
		#print "STRIPPED $count: $raw_pid\n";
		my $pid = $raw_pid;
		my $exists = kill("0",$pid);
		if ($exists) {
			$return_count++;
			my $message = "checking for any program operating on $text. I found one with pid ${pid}. ";
			#print "$message\n";
			$return_pid = $pid
		}
	} # end foreach

	return ($return_count);

} # end sub checkAlive