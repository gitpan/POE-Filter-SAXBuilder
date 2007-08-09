package POE::Filter::SAXBuilder::Builder;
use strict;
use warnings;

use base qw(XML::LibXML::SAX::Builder);

our $VERSION = '0.01';

=head1 METHODS

=head2 new

Creates a new object. Accepts the following parameters

=over 2

=item godepth INT

Lets you specify up to how deep in the xml tree you want to have the
elements reported. A value of 2 would report the root element, and
all of its children and grandchildren. The default value for this is 1

=item detach BOOL

Whether to detach the elements at godepth from their parent. This is
useful if you have a very large document to parse, and don't want to
keep it all in memory. For example if L<POE::Filter::SAXBuilder> is
used in a jabber application, which generates a potentially endless
stream of xml.

=back

=cut

sub new {
   my $class = shift;

   my $self = $class->SUPER::new(@_, depth => -1);
   $self->{'godepth'} = 1 unless defined ($self->{'godepth'});
   $self->{'detach'} = 0 unless defined ($self->{'detach'});
   return $self;
}

sub start_element {
   my $self = shift;

   $self->{'depth'}++;

   if ($self->{'detach'} and $self->{'depth'} == $self->{'godepth'}) {
	$self->{'detached'} = $self->{Parent};
   	$self->{Parent} = XML::LibXML::DocumentFragment->new();
   }

   $self->SUPER::start_element(@_);

   # Announce elements with a lower depth than we're interested
   # in, even if they're not done yet.
   # FIXME: do we really want this?
   if ($self->{'depth'} < $self->{'godepth'}) {	    
      push(@{$self->{'finished'}}, $self->{Parent});
      $self->{'count'}++;
   }
}

sub end_element {
   my $self = shift;

   if ($self->{detach} and $self->{depth} + 1 == $self->{godepth}) {
	$self->{Parent} = delete $self->{detached};
   }
   my $node = $self->{Parent};

   $self->SUPER::end_element(@_);

   if($self->{'depth'} == $self->{'godepth'}) {
      push(@{$self->{'finished'}}, $node);
      $self->{'count'}++;
   }
   $self->{'depth'}--;

   # flag that we've reached the end of the document
   if ($self->{'depth'} == -1) {
      $self->{'EOD'} = 1;
   }
}

sub get_node()
{
   my $self = shift;
   $self->{'count'}--;
   return shift(@{$self->{'finished'}});
}

sub finished_nodes()
{
   my $self = shift;
   return $self->{'count'};
}

sub reset {
   my $self = shift;

   $self->done;
   $self->{depth} = -1;
}

1;
