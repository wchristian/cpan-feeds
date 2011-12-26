use strictures;

package Web::SimpleX::View::JSON;

use Sub::Exporter::Simple qw( render_json action_error_json view_error_json );

use JSON;

sub render_json {
    my ( $self, $json ) = @_;

    return [
        200,
        [
            'Cache-Control' => 'no-cache',
            'Pragma'        => 'no-cache',
            'Expires'       => 0,
            'Content-Type'  => 'application/json; charset=utf-8'
        ],
        [ to_json $json ]
    ];
}

sub action_error_json { { error => "unknown" } }

sub view_error_json {
    return [
        200,
        [
            'Cache-Control' => 'no-cache',
            'Pragma'        => 'no-cache',
            'Expires'       => 0,
            'Content-Type'  => 'application/json; charset=utf-8'
        ],
        ['{ error : "unknown" }']
    ];
}

1;
