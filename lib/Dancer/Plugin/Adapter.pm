use 5.008001;
use strict;
use warnings;

package Dancer::Plugin::Adapter;
# ABSTRACT: Wrap any simple class as a service for Dancer
# VERSION

use Dancer::Plugin;
use Class::Load qw/try_load_class/;

my %objects;
my $conf;

register service => sub {
  my ( $self, $name ) = plugin_args(@_);

  unless ($name) {
    die "Dancer::Plugin::Adapter::service() requires a name argumenet";
  }

  $conf ||= plugin_setting();

  # return cached object if already created
  return $objects{$name} if defined $objects{$name};

  # otherwise, instantiate the object from config settings
  my $object_conf = $conf->{$name}
    or die "No configuration for Adapter '$name'";

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

  return $objects{$name} = $object;
};

register_plugin for_versions => [ 1, 2 ];

1;

=for Pod::Coverage method_names_here

=head1 SYNOPSIS

  # in config.yml

  plugins:
    Adapter:
      ua:
        class: HTTP::Tiny
        options:
          max_redirect: 3

  # in your app

  use Dancer::Plugin::Adapter;

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

The problem: you want to use some perl class in your Dancer app, but there's
no plugin for it.

The solution: as long as the class needs only static data to construct an
object, then C<Dancer::Plugin::Adaptor> can do the wrapping for you.  Think
of it as a "just-in-time" plugin (or maybe a poor-man's L<Bread::Board>).

Here's another example: you want to send emails via
L<Postmark|http://postmarkapp.com> using L<WWW::Postmark>.

In your config.yml, you put this:

  plugins:
    Adapter:
      postmark:
        class: WWW::Postmark
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

C<Dancer::Plugin::Adapter> takes care of constructing and caching the
L<WWW::Postmark> object based on the configuration data, and lets you access
the object with the C<service()> function.

=head1 CONFIGURATION

One or more objects are defined by C<< NAME => HASHREF >> pairs.  The hash
reference for each NAME must contain a 'class' key, whose value is the class
to wrap.

If the hash reference contains an 'options' key, its value will be dereferenced
(if it is a hash or array reference) and passed to C<new()> when the object is
created.  Note that if the class requires a reference for the constructor,
you have to wrap it in an extra array.  E.g.

  # config.yml:
  plugins:
    Adapter:
      foo:
        class: Foo::Bar
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

=head1 USAGE

=head2 service

  service($name);

This function returns the object corresponding to the name defined in
the configuration file.  The object is created on demand and cached
for future use.

=head1 SEE ALSO

=for :list
* L<Dancer>
* L<Dancer::Plugin>

=cut

# vim: ts=2 sts=2 sw=2 et:
