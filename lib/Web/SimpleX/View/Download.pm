use strictures;

package Web::SimpleX::View::Download;

use Sub::Exporter::Simple qw( render_download action_error_download view_error_download );

use Try::Tiny;

use lib 'libs/ph_libs/';
use lib '../../../ph_libs/';
use XMLPage;

sub render_download {
    my ( $self, $result ) = @_;

    $result->{filename} ||= 'download';
    $result->{type}     ||= 'application/octet-stream';

    return [
        200,
        [ "Content-Disposition" => "attachment; filename=$result->{filename}", "Content-Type" => $result->{type} ],
        [ $result->{content} ]
    ];
}

sub action_error_download {
    [ "handle_uri_error.xml", {}, 500 ];
}

sub view_error_download {
    warn $_[1];
    [ 500, [ "Content-Type" => "text/html; charset=utf-8" ], ["An error happened during rendering of the page."] ];
}

1;
