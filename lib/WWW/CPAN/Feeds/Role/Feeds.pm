use strictures;

package WWW::CPAN::Feeds::Role::Feeds;

use Moo::Role;

use File::Slurp qw' write_file read_file ';
use JSON qw' from_json to_json ';
use File::Path 'make_path';
use File::Basename 'dirname';
use DateTime;
sub feed_dir { $_[0]->config->{dir}.'/feeds' }

sub load_feed {
    my ( $self, $name ) = @_;

    my $file = $self->feed_file( $name );
    my $feed = $self->load_feed_file( $file );

    return $feed;
}

sub load_feed_file {
    my ( $self, $file ) = @_;

    my $feed = eval { read_file $file, binmode => 'utf8' };
    return if !$feed;

    $feed = from_json $feed;
    return $feed;
}

sub save_feed {
    my ( $self, $feed ) = @_;

    $feed->{updated} = DateTime->now->_stringify;

    my $file = $self->feed_file( $feed->{name} );

    make_path dirname $file;
    write_file $file, { binmode => 'utf8' }, to_json $feed;

    return;
}

sub feed_file {
    my ( $self, $name ) = @_;

    ( my $stripped_name = $name ) =~ s@/@@g;
    my @parts = map substr( $stripped_name, 0, $_ ), 1, 2;
    my $file = join '/', $self->feed_dir, @parts, $name;
    return $file;
}

1;
