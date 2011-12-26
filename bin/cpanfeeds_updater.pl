#!/usr/bin/perl

use strictures;

package cpanfeeds_updater;

use Test::InDistDir;
use WWW::CPAN::Feeds::Updater;

WWW::CPAN::Feeds::Updater->new->run;
