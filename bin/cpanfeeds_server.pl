#!/usr/bin/perl

use strictures;

package cpanfeeds;

use Test::InDistDir;
use WWW::CPAN::Feeds;
use DB::Skip ( pkgs => [qw( Sub::Quote Sub::Defer Method::Generate::Constructor Method::Generate::Accessor warnings strict constant integer Moo::_Utils )] );

WWW::CPAN::Feeds->run_if_script;
