
use strict;
use warnings;

package HTML::FromMail::Page;
use base 'HTML::FromMail::Object';

=chapter NAME

HTML::FromMail::Page - base class for outputting pages

=chapter SYNOPSIS

=chapter DESCRIPTION

=chapter METHODS

=c_method new OPTIONS

=cut

=method lookup LABEL, ARGS
Look-up, in a formatter dependent way, what the value related to a certain
LABEL is.  The location which is being produced on the moment that this
method is called is stored somewhere in the OPTIONS.  The formatter
(which is also in the OPTIONS) is called to get the value based on that
location information.

=requires formatter OBJECT
=cut

sub lookup($$)
{   my ($self, $label, $args) = @_;
    $args->{formatter}->lookup($label, $args);
}

1;
