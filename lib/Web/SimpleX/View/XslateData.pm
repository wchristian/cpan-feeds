use strictures;

package Web::SimpleX::View::XslateData;

use Sub::Exporter::Simple map "$_\_xslate_data", qw( render action_error view_error process );

use Data::Section::Simple 'get_data_section';
use Text::Xslate;
use Encode 'encode_utf8';

sub render_xslate_data {
    my ( $self, $result ) = @_;

    my ( $content, $statuscode ) = $self->process_xslate_data( @{$result} );

    return [ $statuscode, [ "Content-Type" => "text/html; charset=utf-8" ], [$content] ];
}

sub process_xslate_data {
    my ( $self, $template, $params, $statuscode ) = @_;

    my $vpath = Data::Section::Simple->new( ref $self )->get_data_section();

    for my $name ( keys %{$vpath} ) {
        next if $name !~ /\.tx$/;
        next if $name =~ /^(header|footer)\.tx$/;
        $vpath->{$name} = ":include header\n$vpath->{$name}\n:include footer";
    }

    my $content = Text::Xslate->new( path => [$vpath] )->render( $template, $params );
    $content = encode_utf8 $content;

    $statuscode ||= 200;
    return ( $content, $statuscode ) if wantarray;
    return $content;
}

sub action_error_xslate_data {
    warn $_[1];
    [ "action_error.tx", { error => $_[1] }, 500 ];
}

sub view_error_xslate_data {
    warn $_[1];
    [ 500, [ "Content-Type" => "text/html; charset=utf-8" ],
        ["An error happened during rendering of the page: $_[1]"] ];
}

1;
