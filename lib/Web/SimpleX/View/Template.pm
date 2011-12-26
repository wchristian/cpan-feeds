use strictures;

package Web::SimpleX::View::Template;

use Sub::Exporter::Simple qw( render_template action_error_template view_error_template process_template );

use Try::Tiny;

use lib 'libs/ph_libs/';
use lib '../../../ph_libs/';
use XMLPage;

sub render_template {
    my ( $self, $result ) = @_;

    my ( $content, $statuscode ) = $self->process_template( @{$result} );

    # print header and content
    return [ $statuscode, [ "Content-Type" => "text/html; charset=utf-8" ], [$content] ];
}

sub process_template {
    my ( $self, $xml_filename, $params, $statuscode ) = @_;

    $params ||= {};

    # generate the page object
    my $page = XMLPage->new(
        tmpldir  => 'tmpl/',
        xmldir   => 'seiten/',
        filename => $xml_filename,
        cgi      => $self->req,
        params   => { baseurl => $self->base_url, %{$params} }
    );

    $statuscode ||= 200;

    # parse XML Page
    $statuscode = try {

        # dies when page does not exist
        $page->parsexml;

        return $statuscode;
    }
    catch {

        # handle errors in XML parsing
        warn $self->req->address . ": $_";

        # print the startpage
        $page->uri( "/" );

        # render index page and show 404
        $page->parsexml;

        return 500;
    };

    # render the given template and xml
    $page->rendertemplate;

    my $content = $page->getcontent;

    return ( $content, $statuscode ) if wantarray;
    return $content;
}

sub action_error_template {
    [ "handle_uri_error.xml", {}, 500 ];
}

sub view_error_template {
    warn $_[1];
    [ 500, [ "Content-Type" => "text/html; charset=utf-8" ], ["An error happened during rendering of the page."] ];
}

1;
