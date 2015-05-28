use strict;
use warnings;
use Test::More 0.96 import => ['!pass'];

use File::Temp 0.19; # newdir
use LWP::UserAgent;
use JSON;
use Test::TCP;

test_tcp(
  client => sub {
    my $port = shift;
    my $url  = "http://localhost:$port/";

    my $ua  = LWP::UserAgent->new( cookie_jar => {} );
    my $ua2 = LWP::UserAgent->new( cookie_jar => {} );

    # first request
    my $first = eval { from_json( $ua->get($url)->content ) };
    diag $@ if $@;
    is(
      $first->{request},
      $first->{request_copy},
      "request scope preserved in request"
    );
    isnt( $first->{fresh}, $first->{fresh_copy},
      "no-scope services vary within request" );

    # second request, same session
    my $second = eval { from_json( $ua->get($url)->content ) };
    diag $@ if $@;
    is( $first->{singleton}, $second->{singleton},
      "singleton scope preserved across requests" );
    isnt( $first->{request}, $second->{request},
      "request scope varies across requests" );

    # third request, different session
    my $third = eval { from_json( $ua2->get($url)->content ) };
    diag $@ if $@;
    is( $first->{singleton}, $third->{singleton},
      "singleton scope preserved across sessions" );

  },

  server => sub {
    my $port = shift;

    use Dancer2;
    use Dancer2::Plugin::Adapter;

    set confdir => '.';
    set port    => $port, startup_info => 0;

    set show_errors => 1;
    set serializer  => 'JSON';
    set session => 'Simple';

    set plugins => {
      Adapter => {
        singleton_tempdir => {
          class       => 'File::Temp',
          constructor => 'newdir',
          scope       => 'singleton',
        },
        request_tempdir => {
          class       => 'File::Temp',
          constructor => 'newdir',
          scope       => 'request',
        },
        none_tempdir => {
          class       => 'File::Temp',
          constructor => 'newdir',
          scope       => 'none',
        },
      },
    };

    get '/' => sub {
      return {
        singleton    => "" . service("singleton_tempdir"),
        request      => "" . service("request_tempdir"),
        request_copy => "" . service("request_tempdir"),
        fresh        => "" . service("none_tempdir"),
        fresh_copy   => "" . service("none_tempdir"),
      };
    };

    Dancer2->runner->server->port($port);
    start;
  },
);

done_testing;
#
# This file is part of Dancer2-Plugin-Adapter
#
# This software is Copyright (c) 2012 by David Golden.
#
# This is free software, licensed under:
#
#   The Apache License, Version 2.0, January 2004
#
