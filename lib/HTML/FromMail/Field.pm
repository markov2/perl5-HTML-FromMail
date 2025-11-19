#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package HTML::FromMail::Field;
use base 'HTML::FromMail::Page';

use strict;
use warnings;

use Mail::Message::Field::Full;

#--------------------
=chapter NAME

HTML::FromMail::Field - output a header field as HTML

=chapter SYNOPSIS

=chapter DESCRIPTION

=chapter METHODS

=c_method new %options
=default topic C<'field'>
=cut

sub init($)
{	my ($self, $args) = @_;
	$args->{topic} ||= 'field';

	$self->SUPER::init($args) or return;
	$self;
}

=method fromHead $head, $name, \%args
Returns the fields from the header with $name.  Some fields appear
more than once, some may not be present.
=cut

sub fromHead($$@)
{	my ($self, $head, $name, $args) = @_;
	$head->study($name);
}

=method htmlName \%options
Returns the name of the header field.

=option  capitals 'UNCHANGED'|'WELLFORMED'
=default capitals 'UNCHANGED'
Overrules the default from M<new(settings)> C<names>.
See L</names HOW>.

=cut

sub htmlName($$$)
{	my ($self, $field, $args) = @_;
	defined $field or return;

	my $reform = $args->{capitals} || $self->settings->{names} || 'UNCHANGED';
	$self->plain2html($reform ? $field->wellformedName : $field->Name);
}

=method htmlBody \%options
Produce the body of the field: everything after the first colon on the
header line.

=option  content 'FOLDED'|'REFOLD'|'UNFOLDED'|'DECODED'
=default content <depends>
How to included the body of the field.  If a P<wrap> is defined, then
REFOLD is taken as default, otherwise DECODED is the default. See
L</content HOW>

=option  wrap INTEGER
=default wrap C<78>
In combination with C<content REFOLD>, it specifies the maximum number
of characters requested per line.  See L</wrap INTEGER>.

=option  address ADDRESS|PHRASE|PLAIN|MAILTO|LINK
=default address C<'MAILTO'>
See L</address HOW>
=cut

sub htmlBody($$$)
{	my ($self, $field, $args) = @_;

	my $settings = $self->settings;

	my $wrap    = $args->{wrap} || $settings->{wrap};
	my $content = $args->{content} || $settings->{content} || (defined $wrap && 'REFOLD') || 'DECODED';

	if($field->isa('Mail::Message::Field::Addresses'))
	{	my $how = $args->{address} || $settings->{address} || 'MAILTO';
		$how eq 'PLAIN' or return $self->addressField($field, $how, $args)
	}

	return $self->plain2html($field->unfoldedBody)
		if $content eq 'UNFOLDED';

	$field->setWrapLength($wrap || 78)
		if $content eq 'REFOLD';

	$self->plain2html($field->foldedBody);
}

=method addressField $field, $how, ARGS
Produce text for a header $field containing addresses.  On $how this
is done is defining the result.  Possible values are C<'ADDRESS'>,
C<'PHRASE'>, C<'PLAIN'>, C<'MAILTO'>, or C<'LINK'>.  See L</address HOW>
for details.
=cut

sub addressField($$$)
{	my ($self, $field, $how, $args) = @_;
	return $self->plain2html($field->foldedBody) if $how eq 'PLAIN';

	return join ",<br />", map $_->address, $field->addresses
		if $how eq 'ADDRESS';

	return join ",<br />", map {$_->phrase || $_->address} $field->addresses
		if $how eq 'PHRASE';

	if($how eq 'MAILTO')
	{	my @links;
		foreach my $address ($field->addresses)
		{	my $addr   = $address->address;
			my $phrase = $address->phrase || $addr;
			push @links, qq[<a href="mailto:$addr">$phrase</a>];
		}
		return join ",<br />", @links;
	}

	if($how eq 'LINK')
	{	my @links;
		foreach my $address ($field->addresses)
		{	my $addr   = $address->address;
			my $phrase = $address->phrase || '';
			push @links, qq[$phrase &lt;<a href="mailto:$addr">$addr</a>&gt;];
		}
		return join ",<br />", @links;
	}

	$self->log(ERROR => "Don't know address field formatting '$how'");
	'';
}

=method htmlAddresses $field, \%options
Returns an array with address info.
=cut

sub htmlAddresses($$)
{	my ($self, $field, $args) = @_;
	$field->can('addresses') or return undef;

	my @addrs;
	foreach my $address ($field->addresses)
	{	my %addr = (
			email   => $address->address,
			address => $self->plain2html($address->string),
		);

		if(defined(my $phrase = $address->phrase))
		{	$addr{phrase} = $self->plain2html($phrase);
		}

		push @addrs, \%addr;
	}

	\@addrs;
}

#--------------------
=chapter DETAILS

=section Settings

You can specify the following settings in M<HTML::FromMail::new(settings)>
for topic C<field>:

=subsection address HOW

Some fields are pre-defined to contain e-mail addresses.  In many web-based
clients, you see that these addresses are bluntly linked to, but you here
have a choice.  As example, the header field contains the address
  "My Name" E<lt>me@example.comE<gt>
  you@example.com

The possible settings for this parameter are
=over 4
=item * C<'PLAIN'>
Show the address as was specified in the message header, without smart
processing.
  "My Name" E<lt>me@example.com E<gt>
  you@example.com

=item * C<'PHRASE'>
According to the standards, the phrase is ment to represent the user
in an understandable way.  Usually this is the full name of the user.
No link is made.
  My Name
  you@example.com

=item * C<'ADDRESS'>
Only show the address of the users.
  my@example.com
  you@example.com

=item * C<'MAILTO'>
Create a link behind the phrase.  In case there is no phrase, the
address itself is displayed.  This is the most convenient link, if
you decide to create a link.
  <a href="mailto:me@example.com">My Name </a>
  <a href="mailto:you@example.com">you@example.com </a>

=item * C<'LINK'>
Often seen, but more for simplicity of implementation is the link
under the address.  The C<'MAILTO'> is probably easier to understand.
  "My Name" <a href="mailto:me@example.com">me@example.com</a>
  <a href="mailto:you@example.com">you@example.com</a>

=back

=subsection content HOW

Defined HOW field bodies are handled, by default UNFOLDED.
Valid values are
=over 4
=item  C<'FOLDED'>
Included the content FOLDED as found in the source message.  This is the
fastest choice, and usually in a preformatted html block, otherwise the
folding will be lost again.
=item C<'REFOLD'>
Do not accept the folding as found in the message headers, but force it
into the wrap which is defined by C<wrap>.
=item C<'UNFOLDED'>
All line folding is removed from the field.  This useful when the field body
is displayed in a proportional font.
=item C<'DECODED'>
Fields may be character-set encoded.  Decoding these fields is nicest,
but consumes considerable time.
=back

=subsection names HOW

Defines HOW field names are displayed: either C<'WELLFORMED'> or
C<'UNCHANGED'>.  Field names have a certain capitization (as
defined by the message), but this may be different from the preferred use
of capitals.  The correct use of capitals is implemented by
M<Mail::Message::Field::wellformedName()> and will be used when WELLFORMED
is selected.  By default, the names are displayed UNCHANGED.

=example using HTML::FromMail::Format::Magic
  <!--{name capitals => WELLFORMED}-->

=subsection wrap INTEGER
Used in combination with C<content REFOLD>, to specify how many characters
are requested per line.

=cut

1;
