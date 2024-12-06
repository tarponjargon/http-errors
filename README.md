# Overview

This is an old and simple perl CGI script that accepts errors from a site, and saves to a database.
A separate script reports/alerts. It's stood the test of time and saved me a from having to subscribe
to server error monitoring services.

`http_errors.pl` - accepts errors via HTTP (`X-AUTH` key needs to be in the header, and `site` and `error` parameters must exist)
`report_errors.pl` - reports/alerts errors (triggered by cron)

## Installation

You'll need Apache set up with CGI support, and a publicly-accessible URL with a cgi-bin. You'll also need access to MySQL.

0.  Set up an alert instance on ntfy.sh (free)
1.  Install the perl modules noted at the top of that script.
2.  Modify the parts of http_errors.pl denoted by `CHANGE THIS`
3.  Set proper permissions:

`chmod 755 http_errors.pl`
`chmod 755 report_errors.pl`

4.  Import the db schema:

`mysql -u YOURUSER -p YOURDB < error_logger.sql`

5.  Set up a cronjob to run the alerts:

`*/5 * * * * /home/YOURUSER/bin/report_errors.pl > /home/YOURUSER/logs/report_errors_fails.log 2>&1`

## Usage

It will accept POST or GET requests from anywhere, but only if the X-AUTH header is set to the correct key (noted in the script itself).

example request:

`curl -X POST -H "X-AUTH: p5dAAHNK7HenGyk8ZGWwJ2VRtmFY" -d "site=mysite.com&error=Internal Server Error" http://YOURSERVER.com/cgi-bin/http_errors.pl`

if running an application service you would configure your error logger to send the error to this script.

[example](https://dev.to/salemzii/writing-custom-log-handlers-in-python-58bi)
