use strictures;
use warnings;

package cpanfeeds_starman;

exec "PERL5LIB=~/cpan-feeds/lib starman cpan-feeds/bin/cpanfeeds_server.pl --error-log ./cpanfeeds_error_log";
