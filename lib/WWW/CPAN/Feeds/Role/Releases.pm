use strictures;

package WWW::CPAN::Feeds::Role::Releases;

use Moo::Role;

use JSON qw' from_json to_json ';
use File::Slurp qw' read_file write_file ';
use File::Path 'make_path';

has $_ => ( is => 'ro', lazy => 1, builder => "_build_$_" ) for qw( now month_ago );
has $_ => ( is => 'rw', lazy => 1, builder => "_build_$_" ) for qw( releases );

sub _build_now { DateTime->now }

sub _build_month_ago { $_[0]->now->clone->subtract( days => 30 ); }

sub _build_releases {
    my ( $self ) = @_;

    my $releases = eval { from_json read_file $self->config->{dir} . 'releases.json', binmode => ':utf8' };
    $releases ||= { data => {}, last_updated => $self->month_ago->_stringify };

    return $releases;
}

sub save_releases {
    my ( $self ) = @_;

    make_path $self->config->{dir};
    write_file $self->config->{dir} . 'releases.json', { binmode => ':utf8' }, to_json $self->releases;

    return;
}

sub refresh_releases {
    my ( $self ) = @_;
    $self->releases( $self->_build_releases );
    return;
}

1;
