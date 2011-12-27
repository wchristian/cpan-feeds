use strictures;

package WWW::CPAN::Feeds;

use Web::Simple;

use utf8;
use Web::SimpleX::Helper::ActionWithRender 'action';
use Web::SimpleX::View::XslateData map "$_\_xslate_data", qw( render action_error view_error process );
use Crypt::Eksblowfish::Bcrypt qw'en_base64 bcrypt';
use String::Random;
use Plack::Response;
use Plack::Middleware::Session;
use XML::Feed;
use DateTime::Format::ISO8601;

sub {
    with "WWW::CPAN::Feeds::Role::$_" for qw( Config Releases Feeds );
    has env => ( is => 'rw' );
  }
  ->();

sub default_view { 'xslate_data' }

sub dispatch_request {
    my ( $self, $env ) = @_;

    $self->env( $env );

    disp(
        ''    => sub { Plack::Middleware::Session->new( store => 'Plack::Session::Store::File' ) },
        'GET' => disp(
            '/'              => action( 'root_page' ),
            '/feeds'         => action( 'list_feeds' ),
            '/feeds/xml/**'  => action( 'xml_feed' ),
            '/feeds/show/**' => action( 'show_feed' ),
            '/feeds/edit'    => action( 'edit_feed' ),
            '/feeds/edit/**' => action( 'edit_feed' ),
        ),
        'POST' => disp(
            '/feeds/save + %name~&password~&regexes~' => action( 'create_or_edit_feed' ),    #
        ),
    );
}

sub disp {
    my ( @args ) = @_;
    return sub { @args };
}

sub root_page {
    my ( $self ) = @_;

    my @feeds = $self->recent_feeds;

    return [ 'root', { feeds => \@feeds } ];
}

sub list_feeds {
    my ( $self ) = @_;

    my @feeds = $self->all_feeds;

    return [ 'root', { feeds => \@feeds } ];
}

sub xml_feed {
    my ( $self, $name ) = @_;

    my ( $feed, $releases ) = $self->apply_feed( $name );

    my $atom = XML::Feed->new( 'Atom' );
    $atom->title( "CPAN::Feeds - $feed->{name}" );
    $atom->id( "/feeds/show/$feed->{name}" );
    $atom->link( "/feeds/show/$feed->{name}" );
    $atom->self_link( "/feeds/xml/$feed->{name}" );
    $atom->modified( DateTime->now );

    for my $rel ( @{$releases} ) {
        my $entry = XML::Feed::Entry->new;
        $entry->id( "https://metacpan.org/release/$rel->{author}/$rel->{name}/" );
        $entry->link( "/feeds/show/$feed->{name}" );
        $entry->title( $rel->{name} );
        $entry->summary( $rel->{name} );
        $entry->content( $rel->{name} );
        $entry->issued( DateTime::Format::ISO8601->parse_datetime( "$rel->{date}Z" ) );
        $entry->modified( DateTime::Format::ISO8601->parse_datetime( "$rel->{date}Z" ) );
        $entry->author( $rel->{author} );
        $atom->add_entry( $entry );
    }

    return Plack::Response->new(
        200,    #
        [ "Content-Type" => "application/atom+xml; charset=utf-8" ],
        [ $atom->as_xml ]
    );
}

sub show_feed {
    my ( $self, $name ) = @_;

    my ( $feed, $releases ) = $self->apply_feed( $name );

    my %args = ( feed => $feed, releases => $releases );
    my $new_passes = $self->session->{new_passes} ||= {};
    $args{new_pass} = delete $new_passes->{$name} if $new_passes->{$name};

    return [ 'show', \%args ];
}

sub apply_feed {
    my ( $self, $name ) = @_;

    my $feed = $self->load_feed( $name );

    my @releases = values %{ $self->releases->{data} };

    my @regexes = split '\n', $feed->{regexes};
    my %matched_releases;
    for my $re ( @regexes ) {
        my @matches = grep { $_->{distribution} =~ /$re/ } @releases;
        $matched_releases{ $_->{name} } = $_ for @matches;
    }

    my @matches = values %matched_releases;
    @matches = reverse sort { $a->{date} cmp $b->{date} } @matches;

    return ( $feed, \@matches );
}

sub edit_feed {
    my ( $self, $name ) = @_;
    my $feed = $self->load_feed( $name );
    return [ 'edit', { feed => $feed } ];
}

sub create_or_edit_feed {
    my ( $self, $name, $password, $regexes ) = @_;

    die "No patterns specified." if !$regexes;

    $name ||= $self->available_random_name;

    die "Name must be more than 3 characters." if length $name < 3;

    my $valid_chars = $self->valid_name_chars;
    my ( @invalid_chars ) = ( $name =~ /([^$valid_chars])/g );
    die "Name can only contain these characters: $valid_chars Please remove these chars: @invalid_chars"
      if @invalid_chars;

    my $feed = $self->load_feed( $name );

    $password ||= $self->random;

    $feed ||= {
        name     => $name,
        password => $self->hash_password( $name, $password ),
        created  => DateTime->now->_stringify,
    };

    die "Password not correct." if $feed->{password} ne bcrypt( $password, $feed->{password} );

    $feed->{regexes} = $regexes;

    $self->save_feed( $feed );

    return $self->redirect( "/feeds/show/$name" );
}

sub redirect {
    my ( $self, $url ) = @_;
    my $res = Plack::Response->new;
    $res->redirect( $url );
    return $res;
}

sub random {
    my ( $self ) = @_;
    my $valid_chars = $self->valid_name_chars;
    $valid_chars =~ s@/@@;
    return String::Random->new->randregex( "[$valid_chars]" x 10 );
}

sub available_random_name {
    my ( $self ) = @_;

    my $name = "r/" . $self->random;
    while ( -e $self->feed_file( $name ) ) {
        $name = "r/" . $self->random;
    }

    return $name;
}

sub hash_password {
    my ( $self, $name, $password ) = @_;

    my $salt = $name;
    $salt = substr $salt, 0, 16;
    $salt .= ' ' x ( 16 - length $salt );
    $salt = en_base64( $salt );
    my $settings = "\$2a\$08\$$salt";

    my $hash = bcrypt( $password, $settings );

    $self->session->{new_passes}{$name} = $password;

    return $hash;
}

sub session { $_[0]->env->{"psgix.session"} }

sub valid_name_chars { "a-zA-Z0-9/_" }

1;

__DATA__

@@ root
            <table>
                <: for $feeds -> $feed { :>
                    <tr>
                        <td><: $feed.updated :></td>
                        <td><a href="/feeds/show/<: $feed.name :>"><: $feed.name :></a></td>
                    </tr>
                <: } :>
            </table>


@@ show
            <h1>Feed [ <: $feed.name :> ]</h1>

            <a href="/feeds/edit/<: $feed.name :>">Edit</a>
            -
            <a href="/feeds/xml/<: $feed.name :>">Atom</a>

            <hr />

            <: if $new_pass { :>
                This is your new password: <pre><: $new_pass :></pre>

                <hr />
            <: } :>

            <pre style="background-color: #EEE; padding: 1em;"><: $feed.regexes :></pre>

            <: for $releases -> $rel { :>
            <: $rel.date :> - <: $rel.name :><br />
            <: } :>

@@ edit
            <form method="POST" action="/feeds/save">
                <table id="edit">
                    <tr>
                        <th>Name</th>
                        <td><input type="text" name="name" value="<: $feed.name :>" /></td>
                    </tr>
                    <tr>
                        <th>Password</th>
                        <td><input type="password" name="password" /></td>
                    </tr>
                    <tr>
                        <th>Regexes</th>
                        <td><textarea id="regexes" name="regexes" /><: $feed.regexes :></textarea></td>
                    </tr>
                </table>
                <input type="submit" value="Save" />
            </form>


@@ save
            <: $name :>
            <br />
            <: $file :>
            <br />
            <: $password :>
            <br />
            <: $regexes :>
            <br />
            <: $file :>

@@ action_error
            An error occured: <: $error :>


@@ header
<html>
    <html>
        <title>CPAN::Feeds</title>
        <link rel="icon" type="image/gif" href="/cpanfeeds.png">
        <link rel="SHORTCUT ICON" type="image/gif" href="/cpanfeeds.png">
        <link type="text/css" href="/cpanfeeds.css" rel="stylesheet" media="screen" />
    </html>
    <body>
        <table id="head">
            <tr>
                <td id="spacer_left"></td>
                <td id="icon"><img src="/cpanfeeds.png" /></td>
                <td id="homelink" ><a href="/">CPAN::Feeds</a></td>
                <td><a href="/feeds/edit">New</a></td>
                <td><a href="/feeds">Feeds</a></td>
                <td id="spacer_center"></td>
                <td><a href="/help">Help</a></td>
                <td><a href="/about">About</a></td>
                <td id="spacer_right"></td>
            </tr>
        </table>
        <div id="container">
            <div id="content">


@@ footer
            </div>
            <div id="left">
                <a href="/about">Source</a><br />
                <a href="/about">Bugs</a><br />
                <br />
                Powered by:<br />
                <a href="http://www.perl.org">Perl</a><br />
                <a href="https://metacpan.org/module/Web::Simple">Web::Simple</a><br />
                <a href="https://metacpan.org/module/Text::Xslate">Text::Xslate</a><br />
                <a href="https://metacpan.org/module/MetaCPAN::API">MetaCPAN::API</a><br />
                <br />
                Created by:<br />
                <a href="https://metacpan.org/author/MITHALDU">Christian Walde</a><br />
            </div>
        </div>
    </body>
</html>
