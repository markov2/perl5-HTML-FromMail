#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package HTML::FromMail::Head;
use base 'HTML::FromMail::Page';

use strict;
use warnings;

use HTML::FromMail::Field  ();

#--------------------
=chapter NAME

HTML::FromMail::Head - output a message header as HTML

=chapter SYNOPSIS

=chapter DESCRIPTION

=chapter METHODS

=section Constructors

=c_method new %options
=default topic C<'head'>
=cut

sub init($)
{	my ($self, $args) = @_;
	$args->{topic} ||= 'head';
	$self->SUPER::init($args);
}

#-----------
=section Attributes
=cut

#-----------
=section Other methods
=cut

=ci_method fields $message, %options
Collect information about the header fields.

=option  select $patterns
=default select ''
Select only the fields which match the $patterns.  Multiple patterns can
be specified separated by vertical bars (I<pipes>).  The fields returned
are ordered as specified.

See M<Mail::Message::Head::Complete::grepNames()>.

=option  ignore $exclude
=default ignore undef
The reverse of P<select>: patterns listing which fields not to take.

=option  remove_list_group BOOLEAN
=default remove_list_group true
Do not select the headers which are added by mailing list software.
See Mail::Message::Head::ListGroup.

=option  remove_spam_groups BOOLEAN
=default remove_spam_groups true
Do not select headers which were added by spam fighting software.  See
Mail::Message::Head::SpamGroup.

=option  remove_resent_groups BOOLEAN
=default remove_resent_groups true
Remove all the lines which are related to transport of the message, for
instance the C<Received> and C<Return-Path>, and all lines which start
with C<Resent->.  See Mail::Message::Head::ResentGroup.

=cut

sub fields($$)
{	my ($thing, $realhead, $args) = @_;
	my $head = $realhead->clone;   # we are probably going to remove lines

	my $lg = $args->{remove_list_group};
	$head->removeListGroup    if $lg || !defined $lg;

	my $sg = $args->{remove_spam_groups};
	$head->removeSpamGroups   if $sg || !defined $sg;

	my $rg = $args->{remove_resent_groups};
	$head->removeResentGroups if $rg || !defined $rg;

	my @fields;
	if(my $select = $args->{select})
	{	my @select = split /\|/, $select;
		@fields    = map $head->grepNames($_), @select;
	}
	elsif(my $ignore = $args->{ignore})
	{	my @ignore = split /\|/, $ignore;
		local $"   = ")|(?:";
		my $skip   = qr/^(?:@ignore)/i;
		@fields    = grep $_->name !~ $skip, $head->orderedFields;
	}
	else
	{	@fields    = $head->orderedFields;
	}

	map $_->study, @fields;
}

1;
