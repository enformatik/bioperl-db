# $Id$
#
# BioPerl module for Bio::DB::BioSQL::BaseAdaptor
#
#
# Copyright Open Bio Foundation
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

Bio::DB::BioSQL::BaseAdaptor - Base Adaptor for DB::SQL::adaptors

=head1 SYNOPSIS

    # base adaptor provides
    
    # SQL prepare function
    $adaptor->prepare("sql statement");

    # get of root db object
    $adaptor->db();

    # delete memory cycles
    $adaptor->deleteObj();


=head1 DESCRIPTION

This is a true base class for Adaptors in the Bio::DB::BioSQL
system. Original idea from Arne Stabenau (stabenau@ebi.ac.uk)

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::DB::Map::BaseAdaptor;

use vars qw(@ISA);
use strict;
use Bio::Root::Root;
use Bio::DB::Query::BioQuery;

@ISA = qw(Bio::Root::Root);

sub new {
    my ($class,$dbobj) = @_;

    my $self = bless {}, ref($class) || $class;

    if( !defined $dbobj || !ref $dbobj ) {
	$self->throw("Don't have a db [$dbobj] for new adaptor");
    }

    $self->db($dbobj);

    return $self;
}

=head2 create

 Title   : create
 Usage   : $objectstoreadp->create($obj, @params)
 Function: Creates the object as a persistent object in the datastore. This
           is equivalent to an insert.
 Example :
 Returns : The newly assigned primary key.
 Args    : The object to be inserted, and optionally additional (named) 
           parameters.


=cut

sub create{
    my ($self,@args) = @_;
   
    $self->throw_not_implemented();
}

=head2 store

 Title   : store
 Usage   : $objectstoreadp->store($persistent_obj,@params)
 Function: Updates the given persistent object in the datastore.
 Example :
 Returns : TRUE on success and FALSE otherwise
 Args    : The object to be updated, and optionally additional (named) 
           parameters.


=cut

sub store{
    my ($self,@args) = @_;

    $self->throw_not_implemented();
}

=head2 remove

 Title   : remove
 Usage   : $objectstoreadp->remove($persistent_obj, @params)
 Function: Removes the persistent object from the datastore.
 Example :
 Returns : TRUE on success and FALSE otherwise
 Args    : The object to be removed, and optionally additional (named) 
           parameters.


=cut

sub remove{
    my ($self,@args) = @_;

    $self->throw_not_implemented();
}

=head2 find_by_primary_key

 Title   : find_by_primary_key
 Usage   : $objectstoreadp->find_by_primary_key($pk)
 Function: Locates the entry associated with the given primary key and
           initializes a persistent object with that entry.
 Example :
 Returns : An instance of the class this adaptor adapts, represented by an
           object implementing Bio::DB::PersistentObjectI.
 Args    : The primary key


=cut

sub find_by_primary_key{
    my ($self,@args) = @_;

    $self->throw_not_implemented();
}

=head2 prepare

 Title   : prepare
 Usage   : $sth = $adaptor->prepare("select yadda from blabla")
 Function: provides a DBI statement handle from the adaptor. A convenience
           function so you do not have to write $adaptor->db->prepare all the
           time
 Example :
 Returns : 
 Args    :


=cut

sub prepare{
   my ($self,$string) = @_;
   if ($ENV{SQL_TRACE}) {
       print STDERR "SQL:$string\n";
   }
   return $self->db->prepare($string);
}

=head2 execute

 Title   : execute
 Usage   : $sth = $adaptor->execute("select yadda from blabla")
 Function: provides a DBI statement handle from the adaptor. A convenience
           function so you do not have to prepare and execute all the
           time
 Example :
 Returns : sth
 Args    :


=cut

sub execute {
    my $self = shift;
    my $string = shift;
    if ($ENV{SQL_TRACE}) {
        if (@_) {
            printf STDERR "VALS:%s\n", join(", ", @_);
        }
    }
    my $sth = $self->prepare($string);
    $sth->execute(@_);
    return $sth;
}

=head2 quote

 Title   : quote
 Usage   : $sql_string = $adaptor->quote($string)
 Function: A convenience function so you do not have to write 
           $adaptor->db->_db_handle->quote all the  time
 Example :
 Returns : 
 Args    :

=cut

sub quote {
   my ($self,$string) = @_;

   if( !defined $self->db ) {
      $self->throw("Database object has lost its database handle! getting otta here!");
   }
   return $self->db->_db_handle->quote($string);
}

=head2 select_colval

 Title   : select_colval
 Usage   : $val = $adaptor->select_colval($table, {$colname=>$val}, $selectcol)
 Function: A convenience function for getting a single value via an sql query
 Example :
 Returns :
 Args    :

=cut

sub select_colval {
    my ($self, $table, $constr, $col) = @_;
    my $sql = $self->make_sql($table, $constr, $col);
    my $sth = $self->execute($sql);
    my $rowhash = $sth->fetchrow_hashref;
    return $rowhash->{$col};
}

=head2 select_colvals

 Title   : select_colvals
 Usage   : @vals = $adaptor->select_colvals($table, {$colname=>$val}, $selectcol)
 Function: A convenience function for getting a single col via an sql query
 Example :
 Returns :
 Args    :

=cut

sub select_colvals {
    my ($self, $table, $constr, $col) = @_;
    my $sql = $self->make_sql($table, $constr, $col);
    my $sth = $self->execute($sql);
    my @v = ();
    while( my $href = $sth->fetchrow_hashref ) {
        push(@v,  $href->{$col});
    }
    return @v;
}

=head2 selectall

 Title   : selectall
 Usage   : @rows = $adaptor->selectall($table, {$colname=>$val}, $selectcols)
 Function: A convenience function for getting all results of a query
 Example :
 Returns :
 Args    :

=cut

sub selectall {
    my ($self, $table, $constr, $col) = @_;
    my $sql = $self->make_sql($table, $constr, $col);
    my $sth = $self->execute($sql);
    my @cols = ();
    while( my $href = $sth->fetchrow_hashref ) {
        push(@cols, $href);
    }
    return @cols;
}

sub make_sql {
    my ($self, $tables, $constr, $cols) = @_;
    my $where = "";
    if ($constr) {
        my @w = ($constr);
        if (ref($constr)) {
            if (ref($constr) eq "HASH") {
                @w = map {"$_ = ".$self->quote($constr->{$_})} keys %$constr;
            }
            if (ref($constr) eq "ARRAY") {
                @w = @$constr;
            }
        }
        $where =
          sprintf(" WHERE %s",
                  join(" AND ", @w));
    }
    my @cols = ("*");
    if ($cols) {
        if (ref($cols)) {
            @cols = @$cols
        }
        else {
            @cols = ($cols);
        }
    }
    $tables or $self->throw("must supply tables");
    my @tables = ref($tables) ? @$tables : ($tables);
    if ($cols) {
        if (ref($cols)) {
            @cols = @$cols
        }
        else {
            @cols = ($cols);
        }
    }
    my $sql = 
      sprintf("SELECT %s\nFROM %s$where",
              join(", ", @cols),
              join(", ", @tables),
             );
    return $sql;
}

=head2 insert

 Title   : insert
 Usage   : $ad->insert("mytable", {col1=>$x, col2=>$y});
 Function:
 Returns :
 Args    : table [string], hashref


=cut

sub insert {
    my ($self, $table, $valh) = @_;
    my @cols = keys %$valh;
    my $sql =
      sprintf("INSERT INTO %s (%s) VALUES (%s)",
              $table,
              join(", ", @cols),
#              join(", ", map {'?'} @cols),
              join(", ",
                   map {
                       defined($_) ? $self->quote($valh->{$_}) : 'NULL'
                   } @cols),
             );
#    my $sth = $self->execute($sql, map {$valh->{$_}} @cols);
    my $sth = $self->execute($sql);
    my $id;
    eval {
        $id = $self->get_last_id($table);
    };
    return $id;
}

=head2 deleterows

 Title   : deleterows
 Usage   : $ad->deleterows("mytable", {col1=>$x, col2=>$y});
 Function:
 Returns :
 Args    : table [string], hashref


=cut

sub deleterows {
    my ($self, $table, $valh) = @_;
    my @cols = keys %$valh;
    my $sql =
      sprintf("DELETE FROM %s WHERE %s",
              $table,
              join(" AND ",
                   map {
                       defined($_) ? 
                         "$_ = ".$self->quote($valh->{$_}) : "$_ is NULL"
                   } @cols),
             );
    my $sth = $self->execute($sql);
    return $sth;
}

=head2 db

 Title   : db
 Usage   : $obj->db($newval)
 Function: 
 Returns : value of db
 Args    : newvalue (optional)


=cut

sub db{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'db'} = $value;
    }
    return $obj->{'db'};

}


=head2 get_last_id

 Title   : get_last_id
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_last_id{
   my ($self, $table) = @_;

   return $self->db()->dbcontext()->dbi()->last_id_value($table);
}

# turns a query string into a bioquery object
# todo; define rules for converting between querylang and
# query object
# query lang should allow passthru to sql
# BUT keep it practical
sub _get_bioquery {
    my ($self, $q) = @_;
    if (ref($q)) {
	if (ref($q) eq "HASH") {
	    $q = Bio::DB::Query::BioQuery->new(-where=>$q->{"constraints"});
	}
	return $q;
    }
    $self->throw("query parser not implemented yet; use a hash for now");
}

sub resolve_query {
    my ($self, $query, $sqlq, @extra_where) = @_;
    
    my $qc = $query->where;
    my @wh = $self->resolve_constraint($query, $qc, $sqlq);
    if (@wh && @extra_where) {
	if (@wh > 1) {
	    warn("not what i expected.... @wh");
	}
	$sqlq->where( [(@wh, @extra_where)] );
    }
}

=head2 resolve_constraint

 Title   : resolve_constraint
 Usage   :
 Function:
 Example :
 Returns : 
 Args    : 

recursively resolves constraints; turns BioQuery constraints into
SqlQuery constraints

=cut

sub resolve_constraint {
    my ($self, $query, $qc, $sqlq) = @_;

    my @curwhere = ();    # where clause for this 

#    my $sqlqc = Bio::DB::Query::QueryConstraint->new;

    # a query constraint can either be a leaf node
    # (eg species=Human), or it can be composite
    # eg ( c1 AND c2 AND c3 )
    # composites can only be one operand (and/or)
    # not mixed.
    if ($qc->is_composite) {

	# composite node; recursively solve for
	# the components then combine with operand;
	# (this is the 'local' part of the where clause;
	#  there is also a global part which applies to
	#  the entire query)

	my $op = $qc->operand;   # and/or
	my @subqcs = @{$qc->value};
	my @whs = ();
	foreach my $subqc (@subqcs) {
	    my @wh = $self->resolve_constraint($query, $subqc, $sqlq);
	    push(@whs, "(" . join(" And ", @wh) . ")");
	}

#	$sqlqc->operand($op);
#	$sqlqc->neg($qc->neg);
#	$sqlqc->value([@whs]);
#	$sqlqc->is_composite(1);

	if (@whs) {
	    # hmmm.... should we retain the structure in
	    # the SqlQuery object and flatten later??
	    @curwhere = ( "(" . join( " $op ", @whs) .")" );
	    if ($qc->neg) {
		@curwhere = ( "(NOT ($curwhere[0]))" );
	    }
	}
    }
    else {

	# leaf node; use the name of the constraint
	# to determine the method used to resolve it

	my $resolverh = $self->constraint_resolver;
	my $method = $resolverh->{$qc->name};
	if ($method) {

	    my @wh = &$method($self, $sqlq, $qc->value);

#	    if (scalar(@wh == 1)) {
##		$sqlqc->set($wh[0]);
##	    }
#	    else {
#		$sqlqc->operand("and");
#		$sqlqc->neg($qc->neg);
#		$sqlqc->value([@wh]);
#		$sqlqc->is_composite(1);
#	    }

	    @curwhere = @wh;
	    if ($qc->neg) {
		@curwhere = ( "(NOT (" . join( " And ", @wh) . ")" );
	    }
	}
	else {
	    $self->throw("Can't resolve constraint: '".$qc->name."'");
	}
    }

#    return $sqlqc;

    # return local part of subquery
    return @curwhere;

}


sub constraint_resolver {
    my $self = shift;
    return {};
}

sub do_query {
    my ($self, $sqlq) = @_;    
    
    my $dbh = $self->db->_db_handle;
    
    my $sql = $sqlq->getsql;
    print "SQL:$sql\n";
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    return $sth;
}

1;