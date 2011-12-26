use strictures;

package WWW::CPAN::Feeds::Role::Config;

use Moo::Role;

use File::HomeDir;

has config => ( is => 'ro', default => sub { { dir => '.cpanfeeds/' } } );

1;
