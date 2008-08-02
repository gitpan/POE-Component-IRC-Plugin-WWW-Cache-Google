#!/usr/bin/env perl

use Test::More tests => 3;

BEGIN {
    use_ok('POE::Component::IRC::Plugin::BasePoCoWrap');
    use_ok('POE::Component::WWW::Cache::Google');
	use_ok( 'POE::Component::IRC::Plugin::WWW::Cache::Google' );
}

diag( "Testing POE::Component::IRC::Plugin::WWW::Cache::Google $POE::Component::IRC::Plugin::WWW::Cache::Google::VERSION, Perl $], $^X" );
