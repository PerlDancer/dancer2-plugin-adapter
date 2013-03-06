use strict;
use warnings;
use Test::More 0.96 import => ['!pass'];

use File::Temp 0.19; # newdir
use HTTP::Tiny;
use Test::TCP;

test_tcp(
  client => sub {
    my $port = shift;
    my $url  = "http://localhost:$port/";

    my $ua  = HTTP::Tiny->new;
    my $res = $ua->get($url);
    ok( $res->{success}, "Request success" );
    like $res->{content}, qr/Hello World/i, "Request content correct";
  },

  server => sub {
    use Dancer2;
    use Dancer2::Plugin::Adapter;

    my $port = shift;

    set confdir => '.';
    set port => $port, startup_info => 0;

    set show_errors => 0;

    set plugins => {
      Adapter => {
        tempdir => {
          class      => 'File::Temp',
          constructor => 'newdir',
        },
      },
    };

    get '/' => sub {
      if ( -d service("tempdir") ) {
        return 'Hello World';
      }
      else {
        return "Goodbye World";
      }
    };

    Dancer2->runner->server->port($port);
    start;
  },
);

done_testing;
# COPYRIGHT
