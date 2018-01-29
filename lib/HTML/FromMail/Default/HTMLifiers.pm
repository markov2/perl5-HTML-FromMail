# This code is part of distribution HTML-FromMail.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package HTML::FromMail::Default::HTMLifiers;

use strict;
use warnings;

use HTML::FromText;
use Carp;

=chapter NAME

Html::FromMail::Default::HTMLifiers - convert data type to HTML

=chapter SYNOPSIS

=chapter DESCRIPTION

=chapter FUNCTIONS

=cut

our @htmlifiers =
 ( 'text/plain' => \&htmlifyText
#, 'text/html'  => \&htmlifyHtml
 );

=function htmlifyText PAGE, MESSAGE, PART, ARGS
Convert plain text into HTML using M<HTML::FromText>.  Configuration
can be supplied as show in the example.  The defaults are set to mode C<pre>
with C<urls>, C<email>, C<bold>, and C<underline>.

=example configuring text conversion
  my $f = M<HTML::FromMail>->new
  ( settings =>
      { message        => { disposition => \&my_disposer }
      , HTML::FromText => { block_code  => 0 }
      }
  );

=cut

sub htmlifyText($$$$)
{   my ($page, $message, $part, $args) = @_;
    my $main     = $args->{main} or confess;
    my $settings = $main->settings('HTML::FromText')
     || { pre => 1, urls => 1, email => 1, bold => 1, underline => 1};

    my $f = HTML::FromText->new($settings)
       or croak "Cannot create an HTML::FromText object";

    { image => ''            # this is not an image
    , html  => { text => $f->parse($part->decoded->string)
               }
    }
}

=function htmlifyHtml PAGE, MESSAGE, PART, ARGS
THIS FUNCTION IS NOT PRESENT, for the following reason.  What should
happen here?  The message part/multipart contains an html message, but
that interferes with the HTML of the template.

One solution could be to strip the header, and the html and body tags.
However, what about style sheet info?  That may very well interfere
with the template's style sheet.  And consider erroneous HTML?

So, until some nice solution is presented, HTML will not be inlined.
As alternative, your production software may differentiate between
html messages and non-html messages.  Produce the page according to
the template, and then simply link to the produced HTML for the user.
However, I don't know whether that is smart....
=cut

1;
