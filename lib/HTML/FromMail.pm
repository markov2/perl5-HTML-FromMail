#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package HTML::FromMail;
use base 'Mail::Reporter';

use strict;
use warnings;

use Log::Report 'html-frommail';

use File::Spec::Functions qw/catfile catdir file_name_is_absolute/;
use File::Basename        qw/basename dirname/;

my %default_producers = ( # classes will be compiled automatically when used
	'Mail::Message'        => 'HTML::FromMail::Message',
	'Mail::Message::Head'  => 'HTML::FromMail::Head',
	'Mail::Message::Field' => 'HTML::FromMail::Field',
);

#--------------------
=chapter NAME

HTML::FromMail - base-class for the HTML producers

=chapter SYNOPSIS

  use Mail::Message  ();
  use HTML::FromMail ();

  my $msg    = Mail::Message->read(\*STDIN);
  my $fmt    = HTML::FromMail->new(templates => 'templ');
  my $output = $fmt->export($msg, output => $tempdir);

  # See full example in examples/msg2html.pl

=chapter DESCRIPTION

This module is designed to put e-mail related data
on web-pages.  This could be used to create web-mail clients.

=section Status
=over 4
=item *
You can already produce pages for messages in a powerfull and
configurable way. Supported are: selection of header fields to be
included, inline display of the message's data, attachments, previews
for attachments, multiparts and rfc822 encapsulated messages. See
the example script, F<examples/msg2html.pl>

=item *
Pluggable data inliners, for instance a converter for plain text to html
to be inlined in the display of a page.  The same for HTML.

=item *
Pluggable preview generator: the first view lines (or a small version
of the image) can be included on the main display of the message.

=item *
The documentation is not sufficient in amount and organization.  But
there is some.

=item *
Email addresses in the header are not yet formatted as links.
=back

=section Plans

There are many extensions planned; but I have no time to implement
them.

=over 4
=item *
Fields should be treated smartly: links for addresses found in the header,
character encodings, etc.

=item *
Generation of pages showing folders with or without threads.

=item *
More documentation and examples, intergrated with the Mail::Box
documentation.

=item *
Production of previews must be made "lazy".  More default previewers, like
MSWord and PDF.

=item *
Support for other template systems.  The producer of message display data
is disconnected from the template system used, so this may not be too
hard.

=back

=chapter METHODS

=section Constructors

=c_method new %options

=option  formatter CLASS|$formatter|HASH
=default formatter HTML::FromMail::Format::OODoc
The formatter which is used to process the template files which produce
the output.

You can specify a CLASS, a $formatter object, or a HASH with options for
a HTML::FromMail::Format::OODoc object which will be created for you.

=option  producers \%map
=default producers <some basic items>
The producer list describes which set of formatting commands are
applicable to certain objects when producing HTML.  The %map
links external class names (usually implemented in M<Mail::Box>) to
sub-classes of this object.  You may modify the default list
using M<producer()>.  Read more in L</Producers>.

=option  settings \%map
=default settings +{}
Each producer has defaults for formatting flexability.  For instance,
sometimes alternatives are available for creating certain pieces
of HTML.  This option adds/modifies the settings for a certain group
of producers, but influences the formatters their behavior as well.
Read more in L</Settings>.

=option  templates  $directory
=default templates  '.'
The location where the template files can be found.  It is used as
base for relative names.

=error Formatter $class can not be used: $@
=error Formatter $class could not be instantiated
=cut

sub init($)
{	my ($self, $args) = @_;

	$self->SUPER::init($args) or return;

	# Defining the formatter to be used
	my $form = $args->{formatter} || {};
	if(!ref $form)
	{	eval "require $form";
		die "ERROR: Formatter $form can not be used:\n$@" if $@;
		$form = $form->new;
	}
	elsif(ref $form eq 'HASH')
	{	require HTML::FromMail::Format::OODoc;
		$form = HTML::FromMail::Format::OODoc->new(%$form);
	}

	die "ERROR: Formatter $form could not be instantiated\n"
		unless defined $form;

	$self->{HF_formatter} = $form;

	# Defining the producers
	my %prod = %default_producers;   # copy
	my $prod = $args->{producers} || {};
	@prod{ keys %$prod } = values %$prod;
	while( my($class, $impl) = each %prod)
	{	$self->producer($class, $impl);
	}

	# Collect the settings
	my $settings = $args->{settings} || {};
	while( my ($topic, $defaults) = each %$settings)
	{	$self->settings($topic, $defaults);
	}

	$self->{HF_templates} = $args->{templates} || '.';
	$self;
}

#--------------------
=section Attributes

=method formatter
Returns the selected formatter object.
=cut

sub formatter() { $_[0]->{HF_formatter} }

#-----------
=section Other methods
=cut

=method producer (CLASS|$object), [$producer]
The CLASS object, for instance a Mail::Message, is handled by the HTML
$producer class.  When an $object is specified, the CLASS of that object
will be used.  The producer returned is the best fit with respect of
the inheritance relations.  undef is returned when no producer was found.

Without producer as parameter, the actual producer for the CLASS is
returned.  In this case, the producer class will be compiled for you,
if that hasn't be done before.

=examples
  use HTML::FromMail;
  my $converter = HTML::FromMail->new;
  print $converter->producer("Mail::Message");

  print $converter->producer($msg);

=error Cannot use $producer for $class: $@
The specified producer (see M<new(producers)>) does not exist or produces
compilation errors.  The problem is displayed.

=cut

sub producer($;$)
{	my ($self, $thing) = (shift, shift);
	my $class = ref $thing || $thing;

	return ($self->{HF_producer}{$class} = shift) if @_;
	if(my $prod = $self->{HF_producer}{$class})
	{	eval "require $prod";
		$@ and $self->log(ERROR => "Cannot use $prod for $class:\n$@"), return undef;

		return $prod->new;
	}

	# Look for producer in the inheritance structure
	no strict 'refs';
	foreach ( @{"$class\::ISA"} )
	{	my $prod = $self->producer($_);
		return $prod if defined $prod;
	}

	undef;
}

=method templates [$producer|$topic]
Returns the location of the templates.  When a $topic is specified,
that is added to the templates path.  With a $producer, that is object is used
to get the topic.

=error Cannot find template file or directory $topic in $directory.
The templates directory (see M<new(templates)>) does not contain a template
for the specified topic (see M<HTML::FromMail::Object::new(topic)>).

=cut

sub templates(;$)
{	my $self = shift;
	return $self->{HF_templates} unless @_;

	my $topic    = blessed $_[0] ? shift->topic : shift;
	my $templates= $self->{HF_templates};

	my $filename = catfile $templates, $topic;
	return $filename if -f $filename;

	my $dirname  = catdir $templates, $topic;
	return $dirname if -d $dirname;

	$self->log(ERROR => "Cannot find template file or directory '$topic' in '$templates'.\n");
	undef;
}

=method settings ($producer|$topic), [HASH|LIST]
Returns a HASH which contains the differences from the default for
producers of a certain $topic, or the topic of the specified $producer.
With HASH, all settings will be replaced by that value as new set.

It may be easier to use M<new(settings)> or add the information to
the content of your templates.

=cut

sub settings($;@)
{	my $self  = shift;
	my $topic = blessed $_[0] ? shift->topic : shift;
	@_ or return $self->{HF_settings}{$topic};

	$self->{HF_settings}{$topic} = @_ == 1 ? shift : +{ @_ };
}

=method export $object, %options
Produce the HTML output of the $object.

=option  use \@files
=default use undef
Directory C<new(templates)> defines the location of all template @files.  In
that directory, you have sub-directories for each kind of object which
can be formatted sorted on C<topic>.

for instance, C<templates> contains C</home/me/templates> and the object
is a L<Mail::Message> which is handled by HTML::FromMail::Message
which has topic C<message>.  This directory plus the topic result in
the directory path C</home/me/templates/message/>.  By default, all
the files found in there get formatted.  However, when the P<use>
option is provided, only the specified files are taken.  If that filename
is related, it is relative to the C<templates> direcory.  If the filename
is absolute (starts with a slash), that name is used.

=requires output $directory|$filename
The $directory where the processed templates for the object are written
to.  It is only permitted to supply a single $filename when the template
specifies a single filename as well.

=error   No producer for $class objects.
=error   No output directory or file specified.
=warning No templates for $topic objects.
=warning No templates found in $templates directory

=cut

sub export($@)
{	my ($self, $object, %args) = @_;

	my $producer  = $self->producer($object)
		or $self->log(ERROR => "No producer for ",ref($object), " objects."), return;

	my $output    = $args{output}
		or $self->log(ERROR => "No output directory or file specified."), return;

# this cannot be right when $output isa filename?
#   $self->log(ERROR => "Cannot create output directory $output: $!"), return
#      unless -d $output || mkdir $output;

	my $topic     = $producer->topic;
	my @files;
	if(my $input = $args{use})
	{	# some template files are explicitly named
		my $templates = $self->templates;

		foreach my $in (ref $input ? @$input : $input)
		{	my $fn = file_name_is_absolute($in) ? $in : catfile($templates, $in);

			-f $fn or $self->log(WARNING => "No template file $fn"), next;

			push @files, $fn;
		}
	}
	else
	{	my $templates = $self->templates($topic)
			or $self->log(WARNING => "No templates for $topic objects."), return;

		@files = $self->expandFiles($templates);
		@files or $self->log(WARNING => "No templates found in $templates directory.");
	}

	my $formatter = $self->formatter(settings => $self->{HF_settings});
	my @outfiles;

	foreach my $infile (@files)
	{	my $basename = basename $infile;
		my $outfile  = catfile $output, $basename;
		push @outfiles, $outfile;

		$formatter->export(
			%args,
			object   => $object,   input     => $infile,
			producer => $producer, formatter => $formatter,
			output   => $outfile,  outdir    => $output,
			main     => $self,
		);
	}

	$outfiles[0];
}

=method expandFiles $directory|$file|\@files
Returns a LIST with all filenames which are included in the $directory
specified or the ARRAY.  If only one $file is specified, then that
will be returned.

=warning Cannot find $dir/file
=error   Cannot read from directory $thing: $!
=warning Skipping $full, which is neither file or directory.
=cut

sub expandFiles($)
{	my ($self, $thing) = @_;
	return @$thing if ref $thing eq 'ARRAY';
	return $thing  if -f $thing;

	-d $thing
		or $self->log(WARNING => "Cannot find $thing"), return ();

	opendir DIR, $thing
		or $self->log(ERROR => "Cannot read from directory $thing: $!"), return ();

	my @files;
	while(my $item = readdir DIR)
	{	next if $item eq '.' || $item eq '..';

		my $full = catfile $thing, $item;
		if(-f $full)
		{	push @files, $full;
			next;
		}

		$full    = catdir $thing, $item;
		if(-d $full)
		{	push @files, $self->expandFiles($full);
			next;
		}

		$self->log(WARNING => "Skipping $full, which is neither file or directory.");
	}

	closedir DIR;
	@files;
}

#--------------------
=chapter DETAILS

=section Producers
Producers are sets of methods which can be used to produce HTML for
a specific object.  For instance, the HTML::FromMail::Message produces
output for Mail::Message objects.  You can add and overrule producers via
M<new(producers)> and M<producer()>.

On the moment, the following producers are defined.  When marked with
a C<(*)>, the implementation is not yet finished.

  M<Mail::Message>            HTML::FromMail::Message
  M<Mail::Message::Head>      HTML::FromMail::Head
  M<Mail::Message::Field>     HTML::FromMail::Field
  M<Mail::Message::Body>      HTML::FromMail::Body      *
  M<Mail::Box>                HTML::FromMail::Box       *
  M<Mail::Box::Thread::Node>  HTML::FromMail::Thread    *

=section Settings

Each producer has one single topic, but there may be multiple alternatives
for one topic.  The topic is configurable with
M<HTML::FromMail::Object::new(topic)>.

For each item which is converted to HTML, one of the producers for that
item is created.  The topic of the producer is used to select a group of
settings to be used as changes on the defaults.  These values are used
for the formatter as well as the producer when formatting that topic.

An example should clarify things a little:

  my $fmt = HTML::FromMail->new(
     settings => {
        message => {
           previewers  => \@my_prevs,
           disposition => sub { 'attach' },
        },
        field   => { },
     },
  );
  print $fmt->export($msg, output => '/tmp/x');

For settings available for messages, see L<HTML::FromMail::Message/Settings>.

=cut

1;
