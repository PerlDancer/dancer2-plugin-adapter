use 5.008001;
use strict;
use warnings;

package Dancer2::Plugin::Adapter;
# ABSTRACT: Wrap any simple class as a service for Dancer2

use Dancer2::Plugin2;

use Class::Load qw/try_load_class/;

has singletons => (
  is => 'ro',
  default => sub { {} },
);

# called with ($dsl, $name, $object)
my %save_by_scope = (
  singleton => sub { $_[0]->singletons->{ $_[1] } = $_[2] },
  request   => sub {
    my $plugin = shift;
    my $hr = $plugin->app->request->var("_dpa") || {};
    $hr->{ $_[0] } = $_[1];
    $plugin->app->request->var( "_dpa", $hr );
  },
  none      => sub { },
);

# called with ($dsl, $name)
my %fetch_by_scope = (
  singleton => sub { $_[0]->singletons->{ $_[1] } },
  request   => sub { my $hr = $_[0]->app->request->var("_dpa") || {}; $hr->{ $_[1] }; },
  none      => sub { },
);

plugin_keywords 'service';

sub service {
  my ( $plugin, $name ) = @_;

  die "Dancer2::Plugin::Adapter::service() requires a name argument"
    unless $name;

  my $conf = $plugin->config;

  # ensure service is defined
  my $object_conf = $conf->{$name}
    or die "No configuration for Adapter '$name'";

  # set scope, but default to 'request' if not set
  my $scope = $conf->{$name}{scope} || 'request';
  unless ( $fetch_by_scope{$scope} ) {
    die "Scope '$scope' is invalid";
  }

  # return cached object if already created
  my $cached = $fetch_by_scope{$scope}->($plugin, $name);
  return $cached if defined $cached;

  # otherwise, instantiate the object from config settings
  my $class = $object_conf->{class}
    or die "No class specified for Adapter '$name'";

  try_load_class($class)
    or die "Module '$class' could not be loaded";

  my $new = $object_conf->{constructor} || 'new';
  my $options = $object_conf->{options};

  my @options =
      ref($options) eq 'HASH'  ? %$options
    : ref($options) eq 'ARRAY' ? @$options
    : defined($options) ? $options
    :                     ();

  my $object = eval { $class->$new(@options) }
    or die "Could not create $class object: $@";

  # cache by scope
  $save_by_scope{$scope}->( $plugin, $name, $object );
  return $object;
};

1;

__END__

=head1 SYNOPSIS

  # in config.yml

  plugins:
    Adapter:
      ua:
        class: HTTP::Tiny
        scope: request
        options:
          max_redirect: 3

  # in your app

  use Dancer2::Plugin::Adapter;

  get '/proxy/:url' => sub {
    my $res = service('ua')->get( params->{'url'} );
    if ( $res->{success} ) {
      return $res->{content};
    }
    else {
      template 'error' => { response => $res };
    }
  };

=head1 DESCRIPTION

The problem: you want to use some perl class in your Dancer2 app, but there's
no plugin for it.

The solution: as long as the class needs only static data to construct an
object, then C<Dancer2::Plugin::Adaptor> can do the wrapping for you.  Think
of it as a "just-in-time" plugin (or maybe a poor-man's L<Bread::Board>).

Here's another example: you want to send emails via
L<Postmark|http://postmarkapp.com> using L<WWW::Postmark>.

In your config.yml, you put this:

  plugins:
    Adapter:
      postmark:
        class: WWW::Postmark
        scope: singleton
        options: POSTMARK_API_TEST

In your production config.yml, you can replace 'POSTMARK_API_TEST' with your
real Postmark API key.

Then, in your application, here's how you use it:

    get '/' => sub {
      eval {
        service("postmark")->send(
          from    => 'me@domain.tld',
          to      => 'you@domain.tld, them@domain.tld',
          subject => 'an email message',
          body    => "hi guys, what's up?"
        );
      };

      return $@ ? "Error: $@" : "Mail sent";
    };

C<Dancer2::Plugin::Adapter> takes care of constructing and caching the
L<WWW::Postmark> object based on the configuration data, and lets you access
the object with the C<service()> function.

=head1 CONFIGURATION

One or more objects are defined by C<< NAME => HASHREF >> pairs.  The hash
reference for each NAME must contain a 'class' key, whose value is the class
to wrap.

The 'scope' key determines how long the generated object persists.  The choice
of scope will depend on whether the object holds onto any state that should not
last across requests.  The following scope values are allowed:

=over

=item C<request> 

(default) the object persists in the C<vars> hash for the duration of the request

=item C<singleton> 

the objects persists in a private, lexical hash for the duration of the process


=item C<none> 

the object is not cached; a fresh object is created on each call

=back

If the hash reference contains an 'options' key, its value will be dereferenced
(if it is a hash or array reference) and passed to C<new()> when the object is
created.  Note that if the class requires a reference for the constructor,
you have to wrap it in an extra array.  E.g.

  # config.yml:
  plugins:
    Adapter:
      foo:
        class: Foo::Bar
        scope: request 
        options:
          -
            wibble: wobble
            biff: boff

  # constructor called as:
  Foo::Bar->new( { wibble => wobble, biff => boff } );

If the class does not use 'new' as the name of its constructor, an alternate
can be specified with the 'constructor' key.

  # config.yml:
  plugins:
    Adapter:
      tmpdir:
        class: File::Temp
        constructor: newdir

  # constructor called as:
  File::Temp->newdir()

When caching under C<request> scope, Dancer2::Plugin::Adaptor uses
the key C<_dpa> in the C<vars>.

=head1 USAGE

=head2 service

  $object = service($name);

This function returns the object corresponding to the name defined in the
configuration file.  The object is created on demand and may be cached for
future use based on its C<scope> configuration option.

=head1 ACKNOWLEDGMENTS

Thank you to Matt S. Trout for suggesting the 'scope' controls.

=cut

# vim: ts=2 sts=2 sw=2 et:
