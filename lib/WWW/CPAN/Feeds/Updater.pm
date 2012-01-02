use strictures;

package WWW::CPAN::Feeds::Updater;

use Moo;

BEGIN { require Mouse }

{
    use JSON ();
    my $old_encode = \&JSON::to_json;
    no warnings 'redefine';
    *JSON::to_json = sub ($@) {
        my ( @args ) = @_;
        $args[1] ||= {};
        $args[1]{canonical} ||= 1;
        return $old_encode->( @args );
    };
}

use MetaCPAN::API;

use DateTime;
use DateTime::Format::ISO8601;

with "WWW::CPAN::Feeds::Role::$_" for qw( Config Releases );

__PACKAGE__->new->run unless caller;

sub run {
    my ( $self ) = @_;

    $self->remove_old_releases;
    $self->add_new_releases;
    $self->save_releases;

    return;
}

sub remove_old_releases {
    my ( $self ) = @_;

    my $releases = $self->releases;
    for my $rel ( keys %{ $releases->{data} } ) {
        next if DateTime::Format::ISO8601->parse_datetime( $releases->{data}{$rel}{date} ) > $self->month_ago;
        delete $releases->{data}{$rel};
    }

    return;
}

sub add_new_releases {
    my ( $self ) = @_;

    my $releases = $self->releases;
    my $from_date =
      DateTime::Format::ISO8601->parse_datetime( $releases->{last_updated} )->subtract( minutes => 5 )->_stringify;

    my %new_releases = $self->get_new_releases( $from_date );
    $releases->{data} = { %{ $releases->{data} }, %new_releases };
    $releases->{last_updated} = $self->now->_stringify;

    return;
}

sub get_new_releases {
    my ( $self, $from ) = @_;

    my $request = {
        "query" => {
            "match_all" => {},
            "range"     => { "release.date" => { "from" => $from, "to" => $self->now->_stringify } },
        }
    };
    my $result = MetaCPAN::API->new->post( 'release/_search?size=10000', $request );

    my %new_releases = map { $_->{_source}{name} => $_->{_source} } @{ $result->{hits}{hits} };

    return %new_releases;
}

1;
