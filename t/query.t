# -*-Perl-*-
# $Id$

use lib 't';

BEGIN {
    # to handle systems with no installed Test module
    # we include the t dir (where a copy of Test.pm is located)
    # as a fallback
    eval { require Test; };
    use Test;    
    plan tests => 17;
}

use Bio::DB::Query::SqlQuery;
use Bio::DB::Query::SqlGenerator;
use Bio::DB::Query::BioQuery;
use Bio::DB::Query::QueryConstraint;
use Bio::DB::BioSQL::mysql::BasePersistenceAdaptorDriver;

my $query = Bio::DB::Query::SqlQuery->new(-tables => ["table1"]);
my $sqlgen = Bio::DB::Query::SqlGenerator->new(-query => $query);

my $sql = $sqlgen->generate_sql();
ok ($sql, "SELECT * FROM table1");

$query->add_datacollection("table1", "table2");
$sql = $sqlgen->generate_sql();
ok ($sql, "SELECT * FROM table1, table2");

$query->selectelts("col1", "col2", "col3");
$sql = $sqlgen->generate_sql();
ok ($sql, "SELECT col1, col2, col3 FROM table1, table2");

$query->groupelts("col1", "col3");
$sql = $sqlgen->generate_sql();
ok ($sql, "SELECT col1, col2, col3 FROM table1, table2 GROUP BY col1, col3");

$query->groupelts([]);
$query->orderelts("col2","col3");
$sql = $sqlgen->generate_sql();
ok ($sql, "SELECT col1, col2, col3 FROM table1, table2 ORDER BY col2, col3");

$query->where(["col4 = ?", "col5 = 'somevalue'"]);
$sql = $sqlgen->generate_sql();
ok ($sql, "SELECT col1, col2, col3 FROM table1, table2 WHERE col4 = ? AND col5 = 'somevalue' ORDER BY col2, col3");

$query->where(["and",
	       ["or", "col4 = ?", "col5 = 'somevalue'"],
	       ["col2 = col4", "col6 not like 'abcd*'"]]);
$sql = $sqlgen->generate_sql();
ok ($sql, "SELECT col1, col2, col3 FROM table1, table2 WHERE (col4 = ? OR col5 = 'somevalue') AND (col2 = col4 AND col6 NOT LIKE 'abcd\%') ORDER BY col2, col3");

$query = Bio::DB::Query::BioQuery->new();
$mapper = Bio::DB::BioSQL::mysql::BasePersistenceAdaptorDriver->new();

$query->selectelts(["accession_number","version"]);
$query->datacollections(["Bio::PrimarySeqI"]);
$tquery = $query->translate_query($mapper);
$sql = $sqlgen->generate_sql($tquery);
ok ($sql, "SELECT bioentry.accession, bioentry.entry_version FROM bioentry");

$query->selectelts([]);
$query->datacollections(["Bio::Species=>Bio::PrimarySeqI"]);
$tquery = $query->translate_query($mapper);
$sql = $sqlgen->generate_sql($tquery);
ok ($sql, "SELECT * FROM bioentry, taxon WHERE bioentry.taxon_id = taxon.taxon_id");

$query->datacollections(["Bio::PrimarySeqI e",
			 "Bio::Species=>Bio::PrimarySeqI sp"]);
$tquery = $query->translate_query($mapper);
$sql = $sqlgen->generate_sql($tquery);
ok ($sql, "SELECT * FROM bioentry e, taxon sp WHERE e.taxon_id = sp.taxon_id");

$query->datacollections(["Bio::PrimarySeqI e",
			 "Bio::Species=>Bio::PrimarySeqI sp",
			 "BioNamespace=>Bio::PrimarySeqI db"]);
$query->where(["sp.binomial like 'Mus *'",
	       "e.desc like '*receptor*'",
	       "db.namespace = 'ensembl'"]);
$tquery = $query->translate_query($mapper);
$sql = $sqlgen->generate_sql($tquery);
ok ($sql,
    "SELECT * ".
    "FROM bioentry e, taxon sp, biodatabase db ".
    "WHERE e.taxon_id = sp.taxon_id AND e.biodatabase_id = db.biodatabase_id ".
    "AND (sp.binomial LIKE 'Mus \%' AND e.description LIKE '\%receptor\%' ".
    "AND db.name = 'ensembl')");

$query->selectelts(["e.accession_number","e.version"]);
$query->datacollections(["Bio::PrimarySeqI e",
			 "Bio::Species=>Bio::PrimarySeqI sp",
			 "BioNamespace=>Bio::PrimarySeqI db",
			 "Bio::Annotation::DBLink xref",
			 "Bio::PrimarySeqI<=>Bio::Annotation::DBLink"]);
$query->where(["sp.binomial like 'Mus *'",
	       "e.desc like '*receptor*'",
	       "db.namespace = 'ensembl'",
	       "xref.database = 'SWISS'"]);
#$query->flag();
$tquery = $query->translate_query($mapper);
$sql = $sqlgen->generate_sql($tquery);
ok ($sql,
    "SELECT e.accession, e.entry_version ".
    "FROM bioentry e, taxon sp, biodatabase db, dbxref xref, bioentry_dblink ".
    "WHERE e.taxon_id = sp.taxon_id AND e.biodatabase_id = db.biodatabase_id ".
    "AND e.bioentry_id = bioentry_dblink.bioentry_id ".
    "AND xref.dbxref_id = bioentry_dblink.dbxref_id ".
    "AND (sp.binomial LIKE 'Mus \%' AND e.description LIKE '\%receptor\%' ".
    "AND db.name = 'ensembl' AND xref.dbname = 'SWISS')");

$query = Bio::DB::Query::BioQuery->new();
$query->datacollections(["Bio::PrimarySeqI<=>Bio::Annotation::SimpleValue"]);
$query->where(["Bio::PrimarySeqI::primary_key = 10",
	       "Bio::Annotation::SimpleValue::category = 3"]);
$tquery = $query->translate_query($mapper);
$sql = $sqlgen->generate_sql($tquery);
ok ($sql,
    "SELECT * ".
    "FROM bioentry, ontology_term, bioentry_qualifier_value ".
    "WHERE bioentry.bioentry_id = bioentry_qualifier_value.bioentry_id ".
    "AND ontology_term.ontology_term_id = bioentry_qualifier_value.ontology_term_id ".
    "AND (bioentry.bioentry_id = 10 AND ontology_term.category_id = 3)");

$query->datacollections(
		  ["Bio::PrimarySeqI e",
		   "Bio::Annotation::SimpleValue sv",
		   "Bio::PrimarySeqI<=>Bio::Annotation::SimpleValue esva"]);
$query->where(["Bio::PrimarySeqI::primary_key = 10",
	       "Bio::Annotation::SimpleValue::category = 3"]);
$tquery = $query->translate_query($mapper);
$sql = $sqlgen->generate_sql($tquery);
ok ($sql,
    "SELECT * ".
    "FROM bioentry e, ontology_term sv, bioentry_qualifier_value esva ".
    "WHERE e.bioentry_id = esva.bioentry_id ".
    "AND sv.ontology_term_id = esva.ontology_term_id ".
    "AND (e.bioentry_id = 10 AND sv.category_id = 3)");

$query->datacollections(
		  ["Bio::DB::BioSQL::PrimarySeqAdaptor",
		   "Bio::DB::BioSQL::SimpleValueAdaptor sv",
		   "Bio::DB::BioSQL::PrimarySeqAdaptor<=>Bio::DB::BioSQL::SimpleValueAdaptor"]);
$query->where(["Bio::PrimarySeqI::primary_key = 10",
	       "Bio::Annotation::SimpleValue::category = 3"]);
$tquery = $query->translate_query($mapper);
$sql = $sqlgen->generate_sql($tquery);
ok ($sql,
    "SELECT * ".
    "FROM bioentry, ontology_term sv, bioentry_qualifier_value ".
    "WHERE bioentry.bioentry_id = bioentry_qualifier_value.bioentry_id ".
    "AND sv.ontology_term_id = bioentry_qualifier_value.ontology_term_id ".
    "AND (bioentry.bioentry_id = 10 AND sv.category_id = 3)");

$query->datacollections(
		  ["Bio::PrimarySeqI c::child",
		   "Bio::PrimarySeqI p::parent",
		   "Bio::PrimarySeqI<=>Bio::PrimarySeqI<=>Bio::Ontology::TermI"]);
$query->where(["p.accession_number = 'Hs.2'",
	       "Bio::Ontology::TermI::name = 'cluster member'"]);
$tquery = $query->translate_query($mapper);
$sql = $sqlgen->generate_sql($tquery);
ok ($sql,
    "SELECT * ".
    "FROM bioentry c, bioentry p, ontology_term, bioentry_relationship ".
    "WHERE c.bioentry_id = bioentry_relationship.child_bioentry_id ".
    "AND p.bioentry_id = bioentry_relationship.parent_bioentry_id ".
    "AND ontology_term.ontology_term_id = bioentry_relationship.ontology_term_id ".
    "AND (p.accession = 'Hs.2' AND ontology_term.term_name = 'cluster member')");

# this must also work with different objects in the association that map
# to the same tables though
$query->datacollections(
		  ["Bio::PrimarySeqI c::child",
		   "Bio::PrimarySeqI p::parent",
		   "Bio::PrimarySeqI<=>Bio::ClusterI<=>Bio::Ontology::TermI"]);
$query->where(["p.accession_number = 'Hs.2'",
	       "Bio::Ontology::TermI::name = 'cluster member'"]);
$tquery = $query->translate_query($mapper);
$sql = $sqlgen->generate_sql($tquery);
ok ($sql,
    "SELECT * ".
    "FROM bioentry c, bioentry p, ontology_term, bioentry_relationship ".
    "WHERE c.bioentry_id = bioentry_relationship.child_bioentry_id ".
    "AND p.bioentry_id = bioentry_relationship.parent_bioentry_id ".
    "AND ontology_term.ontology_term_id = bioentry_relationship.ontology_term_id ".
    "AND (p.accession = 'Hs.2' AND ontology_term.term_name = 'cluster member')");