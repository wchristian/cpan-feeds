#!/usr/bin/perl

use strictures;

package cpanfeeds;

use WWW::CPAN::Feeds;

WWW::CPAN::Feeds->run_if_script;
