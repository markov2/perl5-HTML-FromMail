
use strict;
use warnings;

package HTML::FromMail::Format;
use base 'Mail::Reporter';

=chapter NAME

HTML::FromMail::Format - base-class for message formatters

=chapter SYNOPSIS

 my $fmt  = HTML::FromMail::Format::Magic->new(...);

 my $make = HTML::FromMail->new
  ( templates => ...
  , formatter => 'Magic'
 #, formatter => 'HTML::FromMail::Format::Magic'
 #, formatter => $fmt
  );


=chapter DESCRIPTION

The formatter is implementing the template system: it formats the output.
This base class defines the methods which must be provided by any extension.

At the moment, the following template systems are available:

=over 4
=item * M<HTML::FromMail::Format::OODoc>
Based on L<OODoc::Template>, a simplified version of Template::Magic. It
has all the basic needs of a template system, but may get slow for large
template files.

=item * M<HTML::FromMail::Format::Magic>
Based on L<Template::Magic>, created by Domizio Demichelis.
You will have to install Bundle::MagicTemplate before you can use this
formatter.  The default system is compatible with the previous formatter,
so you can easily upgrade.

The formatter has nice simplifications for the user, especially
when a lot own data must be included in the templates: so data with or
without relation to messages which is not provided by this distribution
(yet).

=back

=chapter METHODS

=c_method new OPTIONS

=cut

sub init($)
{   my ($self, $args) = @_;

    $self->SUPER::init($args) or return;

    $self;
}

=method containerText ARGS
Produces the text encapsulated between begin and end tag of this
template block.  If the tag is "stand alone", not a container, the
value of C<undef> is returned.  When the container is "empty", an
(optionally empty) string with white-spaces is returned.

=cut

sub containerText($) { shift->notImplemented }

=method processText TEXT, ARGS
New TEXT is supplied, which can be seen as part of the currently active
container.

=cut

sub processText($$) { shift->notImplemented }

=method lookup TAG, ARGS
Lookup the value for a certain TAG.  This TAG may, but also may not,
be derived from the template.  The value is lookup is the data produced
by the various producer methods, implemented in M<HTML::FromMail::Page>
extensions.  The values are administered by the various formatters,
because there meaning (and for instance their scoping) is formatter
dependent.  Values which are looked-up are often not simple strings.

=cut

sub lookup($$) { shift->notImplemented }

=method onFinalToken ARGS
Returns whether the parser has more data in this particular part of
the template.
=cut

sub onFinalToken($) { 0 }

1;
