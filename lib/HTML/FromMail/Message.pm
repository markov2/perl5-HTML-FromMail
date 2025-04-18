# This code is part of distribution HTML-FromMail.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package HTML::FromMail::Message;
use base 'HTML::FromMail::Page';

use strict;
use warnings;

use HTML::FromMail::Head;
use HTML::FromMail::Field;
use HTML::FromMail::Default::Previewers;
use HTML::FromMail::Default::HTMLifiers;

use Carp;
use File::Basename 'basename';

=chapter NAME

HTML::FromMail::Message - output a message as HTML

=chapter SYNOPSIS

=chapter DESCRIPTION

THIS MODULE IS UNDER CONSTRUCTION.  However, a lot of things already
work.  Best take a look at the examples directory.

=chapter METHODS

=c_method new OPTIONS

=default topic C<'message'>

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{topic} ||= 'message';

    $self->SUPER::init($args) or return;

    $self->{HFM_dispose}  = $args->{disposition};
    my $settings = $self->settings;

    # Collect previewers
    my @prevs = @HTML::FromMail::Default::Previewers::previewers;
    if(my $prevs = $settings->{previewers})
    {   unshift @prevs, @$prevs;
    }
    $self->{HFM_previewers} = \@prevs;
 
    # Collect htmlifiers
    my @html = @HTML::FromMail::Default::HTMLifiers::htmlifiers;
    if(my $html = $settings->{htmlifiers})
    {   unshift @html, @$html;
    }
    $self->{HFM_htmlifiers} = \@html;

    # We will use header and field formatters
    $self->{HFM_field} = HTML::FromMail::Field->new(settings => $settings);
    $self->{HFM_head}  = HTML::FromMail::Head ->new(settings => $settings);

    $self;
}

=method createAttachment MESSAGE, PART, ARGS
Create an attachment file, and return a hash with information about
that file.  Returns C<undef> if creation fails.

This method is used by M<htmlAttach()> and M<htmlPreview()> to create
an actual attachment file.  It defines C<url>, C<size> and C<type>
tags for the template.

=requires outdir DIRECTORY
The name of the directory where the external file will be produced
must be part of the ARGS hash.

=cut

my $attach_id = 0;

sub createAttachment($$$)
{   my ($self, $message, $part, $args) = @_;
    my $outdir   = $args->{outdir} or confess;
    my $decoded  = $part->decoded;

    my $filename = $part->label('filename');
    unless(defined $filename)
    {   $filename = $decoded->dispositionFilename($outdir);
        $part->label(filename => $filename);
    }

    $decoded->write(filename => $filename)
       or return ();

    ( url      => basename($filename)
    , size     => (-s $filename)
    , type     => $decoded->type->body

    , filename => $filename    # absolute
    , decoded  => $decoded
    );
}

=method fields
Returns the field text producing object.
=cut

sub fields() { shift->{HFM_field} }

=method header
Returns the header text producting object.
=cut

sub header() { shift->{HFM_head} }

=method htmlField MESSAGE, ARGS
Returns the field definition for the currently active message part. When
the formatter sees this is a final token, then only the body of the
field is returned (and the options of M<HTML::FromMail::Field::htmlBody()>
are accepted as well).  Otherwise, the information about the field is
captured to be used later.

=requires name STRING

=option  decode BOOLEAN
=default decode <true> if possible

=option  from PART|PARENT|MESSAGE
=default from PART
The source of this field: the currently active PART (which may be the
main message), the PARENT of the active part (defaults to the message),
or the main MESSAGE itself.

=examples using M<HTML::FromMail::Format::Magic>
  <!--{field name => To, content => REFOLD, wrap => 20}-->

  <!--{field name => To}-->
     <!--{name capitals => WELLFORMED}-->
     <!--{body wrap => 30}-->
  <!--{/field}-->

=error No field name specified in $template
=cut

sub htmlField($$)
{   my ($self, $message, $args) = @_;

    my $name  = $args->{name};
    unless(defined $name)
    {   $self->log(ERROR => "No field name specified in $args->{input}.");
        $name = "NONE";
    }

    my $current = $self->lookup('part_object', $args);

    my $head;
    for($args->{from} || 'PART')
    {   my $source = ( $_ eq 'PART'   ? $current
                     : $_ eq 'PARENT' ? $current->container
                     : undef
                     ) || $message;
        $head      = $source->head;
    }

    my @fields  = $self->fields->fromHead($head, $name, $args);

    return [ map { +{ field_object => $_ } } @fields ]
        unless $args->{formatter}->onFinalToken($args);

    my $f       = $self->fields;
    join "<br />\n", map { $f->htmlBody($_, $args) } @fields;
}

=method htmlSubject MESSAGE, ARGS
Get the subject field from the message's header, just a short-cut
for specifying M<htmlField(name)> with C<subject>.

=example using M<HTML::FromMail::Format::Magic>
  <!--{subject}-->                # message subject
  <!--{field name => subject}-->  # part's subject
  <!--{field name => subject, from => MESSAGE}-->  # message subject

=cut

sub htmlSubject($$)
{   my ($self, $message, $args) = @_;
    my %args = (%$args, name => 'subject', from => 'NESSAGE');
    $self->htmlField($message, \%args);
}

=method htmlName MESSAGE, ARGS
Produce the name of a field.  This tag can only be used inside a field
container. See M<HTML::FromMail::Field::htmlName()> for the use and
options.

=error use of 'name' outside field container
=cut

sub htmlName($$)
{   my ($self, $message, $args) = @_;

    my $field = $self->lookup('field_object', $args)
       or die "ERROR use of 'name' outside field container\n";

    $self->fields->htmlName($field, $args);
}

=method htmlBody MESSAGE, ARGS
Produce the body of a field.  This tag can only be used inside a field
container. See M<HTML::FromMail::Field::htmlBody()> for the use and
options.

=error use of 'body' outside field container
=cut

sub htmlBody($$)
{   my ($self, $message, $args) = @_;

    my $field = $self->lookup('field_object', $args)
       or die "ERROR use of 'body' outside field container\n";

    $self->fields->htmlBody($field, $args);
}

=method htmlAddresses MESSAGE, ARGS
Produce data about addresses which are in the field.  This method uses
M<HTML::FromMail::Field::htmlAddresses()> for that.

=error use of 'addresses' outside field container
=cut

sub htmlAddresses($$)
{   my ($self, $message, $args) = @_;

    my $field = $self->lookup('field_object', $args)
       or die "ERROR use of 'body' outside field container\n";

    $self->fields->htmlAddresses($field, $args);
}

=method htmlHead MESSAGE, ARGS
Defines the fields of a header.  The options are provided by
M<HTML::FromMail::Head::fields()>.

=example using M<HTML::FromMail::Format::Magic>
 # simple
 <pre><!--{head}--></pre>

 # complex
 <table>
 <!--{head remove_spam_groups => 0}-->
   <tr><td><!--{name}--></td>
       <td><!--{body}--></td></tr>
 <!--{/head}-->
 </table>

=cut

sub htmlHead($$)
{   my ($self, $message, $args) = @_;

    my $current = $self->lookup('part_object', $args) || $message;
    my $head    = $current->head or return;
    my @fields  = $self->header->fields($head, $args);

    return [ map { +{ field_object => $_ } } @fields ]
        unless $args->{formatter}->onFinalToken($args);

    local $" = '';
    "<pre>@{ [ map { $_->string } @fields ] }</pre>\n";
}

=method htmlMessage MESSAGE, ARGS
Encapsulated code which is producing the message, which may
be a multipart.  You have to defined the message block when
you use the part (see M<htmlPart()>) tag.  If you do not use
that, you do not need this.

=example using M<HTML::FromMail::Format::Magic>
  <!--{message}-->
    <!--{inline}-->This is an inlined singlepart<!--{/inline}-->
    <!--{attach}-->This is an attachment<!--{/attach}-->
    <!--{preview}-->An attachment with preview<!--{/preview}-->
    <!--{multipart}-->This is a multipart<!--{/multipart}-->
    <!--{nested}-->message/rfc822 encapsulated<!--{/nested}-->
  <!--{/message}-->

=cut

sub htmlMessage($$)
{  my ($self, $message, $args) = @_;
   { message_text => $args->{formatter}->containerText($args) };
}

=method htmlMultipart MESSAGE, ARGS
Encapsulates text to be produced when the message(-part) is a
multipart.
=cut

sub htmlMultipart($$)
{  my ($self, $message, $args) = @_;
   my $current = $self->lookup('part_object', $args) || $message;
   return '' unless $current->isMultipart;

   my $body = $current->body;    # un-decoded info is more useful
   +{  type => $body->mimeType->type
    ,  size => $body->size
    };
}

=method htmlNested MESSAGE, ARGS
Contains text to be produced when the message(-part) is a
nested message; encapsulated in a message/rfc822.
=cut

sub htmlNested($$)
{  my ($self, $message, $args) = @_;
   my $current = $self->lookup('part_object', $args) || $message;
   return '' unless $current->isNested;

   my $partnr  = $self->lookup('part_number', $args);
   $partnr    .= '.' if length $partnr;

   [ +{ part_number => $partnr . '1' 
      , part_object => $current->body->nested
      }
   ];
}

=method htmlifier MIME-TYPE
Returns the code reference for a routine which can create html
for the objects of the specified MIME-TYPE.  The TYPE may be a (smartly
overloaded) L<MIME::Type> object. The behaviour can be changed with
the C<htmlifiers> setting.

=cut

sub htmlifier($)
{   my ($self, $type) = @_;
    my $pairs = $self->{HFM_htmlifiers};
    for(my $i=0; $i < @$pairs; $i+=2)
    {   return $pairs->[$i+1] if $type eq $pairs->[0];
    }
    undef;
}

=method previewer MIME-TYPE
Returns the code reference for a routine which can create a preview
for the objects of the specified MIME-TYPE.  The TYPE may be a (smartly
overloaded) L<MIME::Type> object.  The behaviour can be changed with
the C<previewers> setting.

=cut

sub previewer($)
{   my ($self, $type) = @_;
    my $pairs = $self->{HFM_previewers};
    for(my $i=0; $i < @$pairs; $i+=2)
    {    return $pairs->[$i+1] if $type eq $pairs->[$i]
                               || $type->mediaType eq $pairs->[$i];
    }
    undef;
}

=method disposition MESSAGE, PART, ARGS
Returns a string, which is either C<inline>, C<attach>, or C<preview>,
which indicates how the part of the message should be formatted.
This can be changed with setting C<disposition>.

=cut

sub disposition($$$)
{   my ($self, $message, $part, $args) = @_;
    return '' if $part->isMultipart || $part->isNested;

    my $cd   = $part->head->get('Content-Disposition');

    my $sugg = defined $cd ? lc($cd->body) : '';
    $sugg    = 'attach' if $sugg =~ m/^\s*attach/;

    my $body = $part->body;
    my $type = $body->mimeType;

    if($sugg eq 'inline')
    {   $sugg = $self->htmlifier($type) ? 'inline'
              : $self->previewer($type) ? 'preview'
              :                           'attach';
    }
    elsif($sugg eq 'attach')
    {   $sugg = 'preview' if $self->previewer($type);
    }
    elsif($self->htmlifier($type)) { $sugg = 'inline' }
    elsif($self->previewer($type)) { $sugg = 'preview' }
    else                           { $sugg = 'attach'  }

    # User may have a different opinion.
    my $disp = $self->settings->{disposition} or return $sugg;
    $disp->($message, $part, $sugg, $args)
}

=method htmlInline
=option  type MIME-TYPE
=default type ''
Selects the MIME types which are handled by this singlepart block.  You can
specify the types as defined by M<MIME::Type::equals()>.

=examples using M<HTML::FromMail::Format::Magic>
 <!--{message}-->
    <!--{inline type => text/html}-->
       <!--{html}-->
    <!--{/inline}-->
 <!--{/message}-->

=cut

sub htmlInline($$)
{  my ($self, $message, $args) = @_;

   my $current = $self->lookup('part_object', $args) || $message;
   my $dispose = $self->disposition($message, $current, $args);
   return '' unless $dispose eq 'inline';

   my @attach  = $self->createAttachment($message, $current, $args);
   return "Could not create attachment" unless @attach;

   my $inliner = $self->htmlifier($current->body->mimeType);
   my $inline  = $inliner->($self, $message, $current, $args);

   +{ %$inline, @attach };
}

=method htmlAttach

The C<attach> container defines C<url>, C<size> and C<type>
tags for the template.

=examples using M<HTML::FromMail::Format::Magic>
  <!--{message}-->
    <!--{attach}-->
    <!--{/attach}-->
  <!--{/message}-->

=cut

sub htmlAttach($$)
{  my ($self, $message, $args) = @_;

   my $current = $self->lookup('part_object', $args) || $message;
   my $dispose = $self->disposition($message, $current, $args);
   return '' unless $dispose eq 'attach';

   my %attach  = $self->createAttachment($message, $current, $args);
   return "Could not create attachment" unless keys %attach;

   \%attach;
}

=method htmlPreview

=option  type MIME-TYPE
=default type ''
Selects the MIME types which are handled by this singlepart block.  You can
specify the types as defined by M<MIME::Type::equals()>.

The C<preview> container defines C<url>, C<size> and C<type>
tags for the template, which describe the attachment file.  Besides,
it preview defines a tag which tells whether the preview is made as
C<html> or as C<image>.  Within an C<html> block, you will get an
extra C<text> which includes the actual html preview text.

The C<image> container provides more tags: C<smallurl>,
C<smallwidth>, C<smallheight>, C<width>, and C<height>.

=examples using M<HTML::FromMail::Format::Magic>
  <!--{message}-->
    <!--{preview}-->
       <!--{html}-->
          <!--{text}-->
       <!--{/html}-->
       <!--{image}-->
          <img src="<!--{smallurl}-->"
           width="<!--{smallwidth}-->"
           height="<!--{smallheight}-->"><br />
           (real is <!--{width}--> x <!--{height}-->)
       <!--{/image}-->
       <a href="<!--{url}-->">Attachment of
        <!--{type}--> (<!--{size}--> bytes)</a>
    <!--{/preview}-->
  <!--{/message}-->

=cut

sub htmlPreview($$)
{  my ($self, $message, $args) = @_;

   my $current = $self->lookup('part_object', $args) || $message;
   my $dispose = $self->disposition($message, $current, $args);
   return '' unless $dispose eq 'preview';

   my %attach  = $self->createAttachment($message, $current, $args);
   return "Could not create attachment" unless keys %attach;

   my $previewer = $self->previewer($current->body->mimeType);
   $previewer->($self, $message, $current, \%attach, $args);
}

=method htmlForeachPart MESSAGE, ARGS
Produces html for the parts of a multipart mesasge body.  Each part
may be a multipart too.  For each part, the C<message> container
code is applied recursively.

This container defines a C<part_number>, and enables the use of the
C<part> tag.

=example using M<HTML::FromMail::Format::Magic>
  <!--{message}-->
    <!--{multipart}-->
      <ul>
      <!--{foreachPart}-->
      <li>This is part <!--{part_number}-->
          <!--{part}-->
      </li>
      <!--{/foreachPart}-->
      </ul>
    <!--{/multipart}-->
  <!--{message}-->

=error foreachPart not used within part
=error foreachPart outside multipart

=cut

sub htmlForeachPart($$)
{  my ($self, $message, $args) = @_;

   my $part     = $self->lookup('part_object', $args) || $message;
 
   die "ERROR: foreachPart not used within part" unless $part;
   die "ERROR: foreachPart outside multipart"    unless $part->isMultipart;

   my $parentnr = $self->lookup('part_number',$args) || '';
   $parentnr   .= '.' if length $parentnr;

   my @parts   = $part->parts;
   my @part_data;

   for(my $partnr = 0; $partnr < @parts; $partnr++)
   {   push @part_data,
          { part_number => $parentnr . ($partnr+1)
          , part_object => $parts[$partnr]
          };
   }

   \@part_data;
}

=method htmlRawText MESSAGE, ARGS
Returns the plain text of the body.
=cut

sub htmlRawText($$)
{  my ($self, $message, $args) = @_;
   my $part     = $self->lookup('part_object', $args) || $message;
   $self->plain2html($part->decoded->string);
}

=method htmlPart MESSAGE, ARGS
Apply the C<message> container of the current part on its data.  See example
in M<htmlForeachPart()>.

=cut

sub htmlPart($$)
{  my ($self, $message, $args) = @_;
   my $format  = $args->{formatter};
   my $msg     = $format->lookup('message_text', $args);

   warn("Part outside a 'message' block"), return ''
      unless defined $msg;

   $format->processText($msg, $args);
}

=chapter DETAILS

=section Settings

You can specify the following settings in M<HTML::FromMail::new(settings)>
for topic C<message>:

=subsection disposition CODE
Message parts have to be displayed.  There are a few ways to do that: by
C<inline>, C<attach>, and C<preview>.  In the first case, the text of the
part is inserted in the main page, in the other two as link to an external
file.  The latter is creating a small preview of the attachement.

The message may provide an indication of the way the part should be
displayed in the C<Content-Disposition> field. For many reasons, an
exception will be made... for instance, binary messages will never be
inlined.  You can create your own code reference to change the behavior
of the default algorithm.

=example of own disposition rules
 my $f = M<HTML::FromMail>->new
  ( settings =>
      { message => { disposition => \&my_disposer }
      }
  );

 sub my_disposer($$$$$)
 {   my ($obj, $message, $part, $suggestion, $args) = @_;

     return 'attach'
        if $suggestion eq 'inline' && $part->size > 10_000;
     $suggestion;
 }

=subsection previewers ARRAY-OF-PAIRS

For some kinds of message parts, previews can be produced.  This ordered
list of PAIRS contains mime type with code reference combinations, each
describing such a production.  The specified items are added before the
default list of preview generators.  An C<undef> as code reference will
cause the default preview producer to be disabled.

Method M<previewer()> is called when a previewer for a certain content
type has to be looked-up.  The default previewers are defined (and
implemented) in M<HTML::FromMail::Default::Previewers>.

=subsection htmlifiers ARRAY-OF-PAIRS
Some kinds of information can be translated into HTML.  When a data
type defines such a translation, it may be inlined (see M<htmlInline()>),
where in other cases it will get attached.  The usage is the same as
for the C<previewers> option.

Method M<htmlifier()> is called when a htmlifier for a certain content
type has to be looked-up.  The default htmlifiers are defined (and
implemented) in M<HTML::FromMail::Default::HTMLifiers>.

=example use own converters
 my @prevs = ( 'text/postscript' => \&prepost
             , 'image'           => \&imagemagick
             );
 my @html  = ( 'text/html'       => \&strip_html
             , 'text/plain'      => \&plain2html
             );

 my $f = M<HTML::FromMail>->new
  ( settings =>
      { message => { previewers  => \@prevs
                   , htmlifiers  => \@html
                   , disposition => \&my_disposer
                   }
      }
  );

 sub prepost($$$$$)
 {   my ($page, $message, $part, $attach, $args) = @_;
     # args contains extra info from template
     # returns a hash of info which is used in a
     # preview block (see M<htmlPreview()>)
 }

=cut

1;
