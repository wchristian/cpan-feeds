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

    my $reader = Data::Section::Simple->new( ref $self );
    $template = $reader->get_data_section( $template );

    if(!$params->{xslate_plain}) {
        my $header = $reader->get_data_section( "header" );
        my $footer = $reader->get_data_section( "footer" );
        $template = "$header$template" if $header;
        $template = "$template$footer" if $footer;
    }

    my $content = Text::Xslate->new->render_string( $template, $params );
    $content = encode_utf8 $content;

    $statuscode ||= 200;
    return ( $content, $statuscode ) if wantarray;
    return $content;
}

sub action_error_xslate_data {
    [ "action_error", { error => $_[1] }, 500 ];
}

sub view_error_xslate_data {
    warn $_[1];
    [ 500, [ "Content-Type" => "text/html; charset=utf-8" ],
        ["An error happened during rendering of the page: $_[1]"] ];
}

1;
