package POE::Filter::SAXBuilder::Builder::Node;
use strict;
use warnings;

use base 'XML::LibXML::Element';
use Class::InsideOut qw(public);

public special => my %special;
public level => my %level;

sub DEMOLISH {
   my $self = shift;

   $self->SUPER::DESTROY;
}

package POE::Filter::SAXBuilder::Builder;
use strict;
use warnings;

use base qw(XML::LibXML::SAX::Builder);
use Class::InsideOut qw(register);

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
   $self->{'finished'} = [];
   return $self;
}

#FIXME: see if we can only do this when there's an xml declaration?
sub start_document {
   my $self = shift;

   $self->SUPER::start_document(@_);
   push (@{$self->{'finished'}}, $self->{'DOM'});
}

sub _register {
      my ($noderef, $depth, $special) = @_;
      register ($$noderef, 'POE::Filter::SAXBuilder::Builder::Node');
      $$noderef->level($depth);
      $$noderef->special($special) if (defined $special);
}

sub characters {
   my $self = shift;
   my $detached;

   if ($self->{detach} and $self->{depth} == $self->{godepth} - 1) {
      $detached = $self->{Parent};
      my $node = $self->{Parent} = XML::LibXML::DocumentFragment->new;
      _register (\$node, $self->{'depth'} + 1);
   }

   $self->SUPER::characters(@_);

   if ($detached) {
      push (@{$self->{finished}}, $self->{Parent});
      $self->{Parent} = $detached;
   }
}

sub start_element {
   my $self = shift;

   $self->{'depth'}++;

   if ($self->{'detach'} and $self->{'depth'} == $self->{'godepth'}) {
      $self->{'detached'} = $self->{Parent};
      my $frag = $self->{Parent} = XML::LibXML::DocumentFragment->new();
      _register (\$frag, $self->{'depth'});
   }

   $self->SUPER::start_element(@_);
   my $node = $self->{Parent};

   # Announce elements with a lower depth than we're interested
   # in, even if they're not done yet.
   # FIXME: do we really want this?
   if ($self->{'depth'} < $self->{'godepth'}) {	    
      if ($self->{detach}) {
	 _register (\$node, $self->{'depth'}, 'Start');
      }
      push(@{$self->{'finished'}}, $node);
   }
}

sub end_element {
   my $self = shift;

   my $node = $self->{Parent};

   $self->SUPER::end_element(@_);

   if($self->{'depth'} == $self->{'godepth'}) {
      if ($self->{detached}) {
	 $node = $self->{Parent};
	 _register (\$node, $self->{'depth'}, 'End');
	 $self->{Parent} = delete $self->{detached};
      }
      push(@{$self->{'finished'}}, $node);
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
   return shift(@{$self->{'finished'}});
}

sub finished_nodes()
{
   my $self = shift;
   return scalar @{$self->{'finished'}};
}

sub reset {
   my $self = shift;

   $self->done;
   $self->{depth} = -1;
}

1;
