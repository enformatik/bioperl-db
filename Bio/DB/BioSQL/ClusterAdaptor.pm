# $Id$
#
# BioPerl module for Bio::DB::BioSQL::ClusterAdaptor
#
# Cared for by Ewan Birney  <birney@ebi.ac.uk>
#
# Copyright Ewan Birney 
#
# You may distribute this module under the same terms as perl itself

# 
# Completely rewritten by Hilmar Lapp, hlapp at gmx.net
#
# Version 1.14 and beyond is also
# (c) Hilmar Lapp, hlapp at gmx.net, 2002.
# (c) GNF, Genomics Institute of the Novartis Research Foundation, 2002.
#
# You may distribute this module under the same terms as perl itself.
# Refer to the Perl Artistic License (see the license accompanying this
# software package, or see http://www.perl.com/language/misc/Artistic.html)
# for the terms under which you may use, modify, and redistribute this module.
# 
# THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#

# POD documentation - main docs before the code

=head1 NAME

Bio::DB::BioSQL::ClusterAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this
and other Bioperl modules. Send your comments and suggestions preferably
 to one of the Bioperl mailing lists.
Your participation is much appreciated.

  bioperl-l@bio.perl.org

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
 the bugs and their resolution.
 Bug reports can be submitted via email or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Ewan Birney, Hilmar Lapp

Email birney@ebi.ac.uk
Email hlapp at gmx.net

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::DB::BioSQL::ClusterAdaptor;
use vars qw(@ISA);
use strict;

use Bio::DB::BioSQL::BasePersistenceAdaptor;
use Bio::DB::Persistent::BioNamespace;
use Bio::Cluster::UniGene;

@ISA = qw(Bio::DB::BioSQL::BasePersistenceAdaptor);

# new inherited from base adaptor.
#
# if we wanted caching we'd have to override new here

=head2 get_persistent_slots

 Title   : get_persistent_slots
 Usage   :
 Function: Get the slots of the object that map to attributes in its respective
           entity in the datastore.

           Slots should be methods callable without an argument.

 Example :
 Returns : an array of method names constituting the serializable slots
 Args    : the object about to be inserted or updated


=cut

sub get_persistent_slots{
    my ($self,@args) = @_;

    return ("display_id", "accession_number", "description", "version");
}

=head2 get_persistent_slot_values

 Title   : get_persistent_slot_values
 Usage   :
 Function: Obtain the values for the slots returned by get_persistent_slots(),
           in exactly that order.

 Example :
 Returns : A reference to an array of values for the persistent slots of this
           object. Individual values may be undef.
 Args    : The object about to be serialized.
           A reference to an array of foreign key objects if not retrievable 
           from the object itself.


=cut

sub get_persistent_slot_values {
    my ($self,$obj,$fkobjs) = @_;
    my @vals = ($obj->display_id(),
		$obj->display_id(),
		$obj->description(),
		$obj->isa("Bio::IdentifiableI") ? ($obj->version() || 0) : 0);
    return \@vals;
}

=head2 get_foreign_key_objects

 Title   : get_foreign_key_objects
 Usage   :
 Function: Gets the objects referenced by this object, and which therefore need
           to be referenced as foreign keys in the datastore.

           A Bio::ClusterI references a namespace with authority, and
           possibly a species.

 Example :
 Returns : an array of Bio::DB::PersistentObjectI implementing objects
 Args    : The object about to be inserted or updated, or undef if the call
           is for a SELECT query. In the latter case return class or interface
           names that are mapped to the foreign key tables.


=cut

sub get_foreign_key_objects{
    my ($self,$obj) = @_;
    my ($ns,$taxon);

    if($obj) {
	# there is no "namespace" or Bio::Identifiable object in bioperl, so
	# we need to create one here
	$ns = Bio::DB::Persistent::BioNamespace->new(-identifiable => $obj);
	$ns->adaptor($self->_bionamespace_adaptor());
	# species is optional
	$taxon = $obj->species() if $obj->can('species');
    } else {
	$ns = "Bio::DB::Persistent::BioNamespace";
    }
    $taxon = "Bio::Species" unless $taxon;
    return ($ns, $taxon);
}

=head2 attach_foreign_key_objects

 Title   : attach_foreign_key_objects
 Usage   :
 Function: Attaches foreign key objects to the given object as far as
           necessary.

           This method is called after find_by_XXX() queries, not for INSERTs
           or UPDATEs.

           ClusterIs have a BioNamespace as foreign key, and possibly
           a species.

 Example :
 Returns : TRUE on success, and FALSE otherwise.
 Args    : The object to which to attach foreign key objects.
           A reference to an array of foreign key values, in the order of
           foreign keys returned by get_foreign_key_objects().


=cut

sub attach_foreign_key_objects{
    my ($self,$obj,$fks) = @_;
    my $ok = 0;
    
    # retrieve namespace by primary key
    my $nsadp = $self->_bionamespace_adaptor();
    my $ns = $nsadp->find_by_primary_key($fks->[0]);
    if($ns) {
	$obj->namespace($ns->namespace()) if $ns->namespace();
	$obj->authority($ns->authority()) if $ns->authority();
	$ok = 1;
    }
    # there's also possibly a species
    if($fks && $fks->[1] && $obj->can('species')) {
	my $adp = $self->db()->get_object_adaptor("Bio::Species");
	my $species = $adp->find_by_primary_key($fks->[1]);
	$ok &&= $species;
	$obj->species($species);
    }
    return $ok;
}

=head2 store_children

 Title   : store_children
 Usage   :
 Function: Inserts or updates the child entities of the given object in the 
           datastore.

           Bio::ClusterI has annotations as children.

 Example :
 Returns : TRUE on success, and FALSE otherwise
 Args    : The Bio::DB::PersistentObjectI implementing object for which the
           child objects shall be made persistent.


=cut

sub store_children{
    my ($self,$obj) = @_;
    my $ok = 1;

    # cluster size becomes a qualifier/value association, which essentially
    # is a SimpleValue annotation
    my $sizeann = $self->_simple_value('cluster size',$obj->size());
    $ok = $sizeann->store() && $ok;
    $ok = $sizeann->adaptor->add_association(-objs => [$sizeann, $obj]) && $ok;
    # we need to store the annotations, and associate ourselves with them
    if($obj->can('annotation')) {
	my $ac = $obj->annotation();
	# the annotation object might just have been created on the fly, and
	# hence may not be a PersistentObjectI (if that's the case we'll
	# assume it's empty, and there's no point storing anything)
	if($ac->isa("Bio::DB::PersistentObjectI")) {
	    $ok = $ac->store(-fkobjs => [$obj]) && $ok;
	    $ok = $ac->adaptor()->add_association(-objs => [$ac, $obj]) && $ok;
	}
    }
    # done
    return $ok;
}

=head2 remove_children

 Title   : remove_children
 Usage   :
 Function: This method is to cascade deletes in maintained objects.

           We need to undefine the primary keys of all contained
           annotation objects here.

 Example :
 Returns : TRUE on success and FALSE otherwise
 Args    : The persistent object that was just removed from the database.
           Additional (named) parameter, as passed to remove().


=cut

sub remove_children{
    my $self = shift;
    my $obj = shift;

    # annotation collection
    if($obj->can('annotation')) {
	my $ac = $obj->annotation();
	if($ac->isa("Bio::DB::PersistentObjectI")) {
	    $ac->primary_key(undef);
	    $ac->adaptor()->remove_children($ac);
	}
    }
    # done
    return 1;
}

=head2 attach_children

 Title   : attach_children
 Usage   :
 Function: Possibly retrieve and attach child objects of the given object.

           This is needed when whole object trees are supposed to be built
           when a base object is queried for and returned. An example would
           be Bio::SeqI objects and all the annotation objects that hang off
           of it.

           This is called by the find_by_XXXX() methods once the base object
           has been built. 

           For Bio::ClusterIs, we need to get the annotation objects.

 Example :
 Returns : TRUE on success, and FALSE otherwise.
 Args    : The object for which to find and to which to attach the child
           objects.


=cut

sub attach_children{
    my ($self,$obj) = @_;
    my $ok = 1;

    # find the tag/value pairs corresponding to object slots
    my $slotval = $self->_simple_value('dummy');
    # The SimpleValue object in the association list must not be persistent
    # because otherwise the base adaptor thinks we want to constrain by it.
    # So we simply pass the wrapped object.
    my $qres = $slotval->adaptor->find_by_association(-objs =>[$slotval->obj,
							       $obj]);
    $ok &&= $qres;
    while($slotval = $qres->next_object()) {
	if($slotval->tagname() eq 'cluster size') {
	    $obj->size($slotval->value());
	}
    }
    # we need to associate annotation
    if($obj->can('annotation')) {
	my $annadp = $self->db()->get_object_adaptor(
					       "Bio::AnnotationCollectionI");
	$qres = $annadp->find_by_association(-objs => [$annadp,$obj]);
	$ok &&= $qres;
	my $ac = $qres->next_object();
	if($ac) {
	    $obj->annotation($ac);
	}
    }
    # done
    return $ok;
}

=head2 instantiate_from_row

 Title   : instantiate_from_row
 Usage   :
 Function: Instantiates the class this object is an adaptor for, and populates
           it with values from columns of the row.

 Example :
 Returns : An object, or undef, if the row contains no values
 Args    : A reference to an array of column values. The first column is the
           primary key, the other columns are expected to be in the order 
           returned by get_persistent_slots().
           Optionally, a Bio::Factory::ObjectFactoryI compliant object to
           be used for creating the object.


=cut

sub instantiate_from_row{
    my ($self,$row,$fact) = @_;
    my $obj;

    if($row && @$row) {
	if(! $fact) {
	    # there is no good default implementation currently
	    $fact = $self->_cluster_factory();
	}
	$obj = $fact->create_object(-display_id => $row->[1]);
	$self->populate_from_row($obj, $row);
    }
    return $obj;
}

=head2 populate_from_row

 Title   : populate_from_row
 Usage   :
 Function: Populates an object with values from columns of the row.

 Example :
 Returns : The object populated, or undef, if the row contains no values
 Args    : The object to be populated.
           A reference to an array of column values. The first column is the
           primary key, the other columns are expected to be in the order 
           returned by get_persistent_slots().


=cut

sub populate_from_row{
    my ($self,$obj,$rows) = @_;

    if(! ref($obj)) {
	$self->throw("\"$obj\" is not an object. Probably internal error.");
    }
    if($rows && @$rows) {
	my $has_lsid = $obj->isa("BioIdentifiableI");
	$obj->display_id($rows->[1]) if $rows->[1];
	$obj->object_id($rows->[2]) if $rows->[2] && $has_lsid;
	$obj->description($rows->[3]) if $rows->[3];
	$obj->version($rows->[4]) if $rows->[4] && $has_lsid;
	if($obj->isa("Bio::DB::PersistentObjectI")) {
	    $obj->primary_key($rows->[0]);
	}
	return $obj;
    }
    return undef;
}

=head2 get_unique_key_query

 Title   : get_unique_key_query
 Usage   :
 Function: Obtain the suitable unique key slots and values as determined by the
           attribute values of the given object and the additional foreign
           key objects, in case foreign keys participate in a UK. 

 Example :
 Returns : A reference to a hash with the names of the object''s slots in the
           unique key as keys and their values as values.
 Args    : The object with those attributes set that constitute the chosen
           unique key (note that the class of the object will be suitable for
           the adaptor).
           A reference to an array of foreign key objects if not retrievable 
           from the object itself.


=cut

sub get_unique_key_query{
    my ($self,$obj,$fkobjs) = @_;
    my $uk_h = {};

    # UK for ClusterI is (display ID,namespace,version),
    #
    if($obj->display_id()) {
	$uk_h->{'accession_number'} = $obj->display_id();
	$uk_h->{'version'} =
	    $obj->isa("Bio::IdentifiableI") ? ($obj->version() || 0) : 0;
	# add namespace if possible
	if($obj->namespace()) {
	    my $ns = Bio::BioEntry->new(-namespace => $obj->namespace());
	    $ns = $self->_bionamespace_adaptor()->find_by_unique_key($ns);
	    $uk_h->{'bionamespace'} = $ns->primary_key() if $ns;
	}
    }

    return $uk_h;
}

=head1 Internal methods

 These are mostly private or 'protected.' Methods which are in the
 latter class have this explicitly stated in their
 documentation. 'Protected' means you may call these from derived
 classes, but not from outside.

 Most of these methods cache certain adaptors or otherwise reduce call
 path and object creation overhead. There's no magic here.

=cut

=head2 _bionamespace_adaptor

 Title   : _bionamespace_adaptor
 Usage   : $obj->_bionamespace_adaptor($newval)
 Function: Get/set cached persistence adaptor for the bionamespace.

           In OO speak, consider the access class of this method protected.
           I.e., call from descendants, but not from outside.
 Example : 
 Returns : value of _bionamespace_adaptor (a Bio::DB::PersistenceAdaptorI
	   instance)
 Args    : new value (a Bio::DB::PersistenceAdaptorI instance, optional)


=cut

sub _bionamespace_adaptor{
    my ($self,$adp) = @_;
    if( defined $adp) {
	$self->{'_bions_adaptor'} = $adp;
    }
    if(! exists($self->{'_bions_adaptor'})) {
	$self->{'_bions_adaptor'} =
	    $self->db->get_object_adaptor("BioNamespace");
    }
    return $self->{'_bions_adaptor'};
}

=head2 _cluster_factory

 Title   : _cluster_factory
 Usage   : $obj->_cluster_factory($newval)
 Function: Get/set the Bio::Factory::ObjectFactoryI to use
 Example : 
 Returns : value of _cluster_factory (a scalar)
 Args    : on set, new value (a scalar or undef, optional)


=cut

sub _cluster_factory{
    my $self = shift;

    return $self->{'_cluster_factory'} = shift if @_;
    if(! exists($self->{'_cluster_factory'})) {
	$self->{'_cluster_factory'} = Bio::Cluster::ClusterFactory->new();
    }
    return $self->{'_cluster_factory'};
}

=head2 _simple_value

 Title   : _simple_value
 Usage   : $term = $obj->_simple_value($slot, $value);
 Function: Obtain the persistent L<Bio::Annotation::SimpleValue>
           representation of certain slots that map to ontology term
           associations (e.g. size).

           This is an internal method.

 Example : 
 Returns : A persistent L<Bio::Annotation::SimpleValue> object
 Args    : The slot for which to obtain the SimpleValue object.
           The value of the slot.


=cut

sub _simple_value{
    my ($self,$slot,$val) = @_;
    my $svann;

    if(! exists($self->{'_simple_values'})) {
	$self->{'_simple_values'} = {};
    }

    if(! exists($self->{'_simple_values'}->{$slot})) {
	my $term = Bio::Ontology::Term->new(-name     => $slot,
					    -category => 'Object Slots');
	$svann = Bio::Annotation::SimpleValue->new(-tag_term => $term);
	$self->{'_simple_values'}->{$slot} = $svann;
    } else {
	$svann = $self->{'_simple_values'}->{$slot};
    }
    # always create a new persistence wrapper for it - otherwise we run the
    # risk of messing with cached objects
    $svann->value($val);
    $svann = $self->db()->create_persistent($svann);
    return $svann;
}

1;