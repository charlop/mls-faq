#!/usr/bin/perl

# Usage:
# 	[script_name] "[query terms]"
#		--stop "[stop-list exceptions]"
#		--req "[mandatory terms]"
# This script takes 1-3 arguments as input, as described above.
# First, [stop-list exceptions] are stemmed and these terms are removed from
#  the stop-list
# [query_terms] are then stemmed and removed if they belong to the stop-list
#  then, they are inserted into QUERY_WL and processed by the database
# [mandatory terms] are added to the final WHERE clause where the results are
#  selected from (e.g. WHERE QUERY_TERM = [mandatory terms[0]] AND ...)
# The final results are retrieved from the GET_COSINE view and
#  printed to STDOUT, to be processed by PHP

use Text::English;		# Used for stemming
use DBD::mysql;
use Digest::MD5 qw(md5_hex);	# Used to generate doc_id's
use Math::Complex;		# Defines the power() function to square values
use Getopt::Long qw(GetOptions);# Used to get command-line arguments
use strict;
use warnings;

# Enabling this causes additional output to be logged to perlLog.log
# Useful for demo
my $DEBUG = 1;

# CONSTANTS
my $DB_NAME = "FAQ415";
my $QA_TABLE = "QUESTION_ANSWER_MASTER";
my $WORD_TABLE = "WORD_LIST";
my $STOP_WORD_FILE = "stopwords.txt";
my $LOG_FILE = "perlLog.log";

# GLOBAL VARIABLES
my @input_array;
my @stemmed_input;
my @stop_list_exceptions;
my @stemmed_stop_list_exceptions;
my $exceptions;	
my $req_words_str;
my @required_words;
my @stemmed_required_words;
my $final_term;
my $excep_check = 0;
my $req_check = 0;
my $LOG_FH;

if($DEBUG eq 1) {
	open($LOG_FH, '>>', $LOG_FILE);
	print $LOG_FH "\n\n-----------------------\n" . localtime() . "\n";
}

if(scalar @ARGV > 1) {
	# User is re-submitting their query with re-weightings
	# Parse the actual query first
	my $term = $ARGV[0];	
	$term =~ s/[^a-zA-Z0-9 ]//g;
	push @input_array, split(/ /, $term);
		
	GetOptions(
		'stop=s' => \$exceptions,
		'req=s' => \$req_words_str,
	);

	# Check if stop-list exceptions were specified
	if($exceptions) {
		$exceptions =~ s/[^a-zA-Z0-9 ]//g;
		push @stop_list_exceptions, split(/ /, $exceptions);
		$excep_check = 1;
		@stemmed_stop_list_exceptions = Text::English::stem(@stop_list_exceptions);
	}
	
	# Check if required (mandatory) terms are specified
	if($req_words_str) {
		$req_words_str =~ s/[^a-zA-Z0-9 ]//g;
		push @required_words, split(/ /, $req_words_str);
		$req_check = 1;
		@stemmed_required_words = Text::English::stem(@required_words);
	}
} elsif(scalar @ARGV eq 1) {
	# Only the user query was specified
	my $term = $ARGV[0];
	$term =~ s/[^a-zA-Z0-9 ]//g;
	push @input_array, split(/ /, $term);
} else {
	# No command-line arguments, return -1
	print "-1";
	exit;
}

# Stem the user's input query
@stemmed_input = Text::English::stem(@input_array);

# Read in the stop words from a file, stem them and store them in an array
my @STOP_WORD_ARRAY;
open(my $FH, '<', $STOP_WORD_FILE);
while (my $line = <$FH>) {
	$line =~ s/^\s+|\s+$//g; 
	push @STOP_WORD_ARRAY, $line;
	@STOP_WORD_ARRAY = Text::English::stem(@STOP_WORD_ARRAY);
}
close($FH);
# Map array to hash, since it's easier to search by key
my %STOP_HASH = map { $_ => 1 } @STOP_WORD_ARRAY;

my $hash_size = scalar keys %STOP_HASH;
if($DEBUG eq 1) {print $LOG_FH "\nPreparing stop-word list. Initial size: " . $hash_size . "\n";}

# Remove stop-word exceptions from stop-word list
if($excep_check eq 1) {
	foreach my $eterm (@stemmed_stop_list_exceptions) { 
		if(exists $STOP_HASH{$eterm}) {
			if($DEBUG eq 1) { print $LOG_FH "Removing: " . $eterm . "\n"; }
			delete ($STOP_HASH{$eterm});
		}
	}
}

$hash_size = scalar keys %STOP_HASH;
if($DEBUG eq 1) { print $LOG_FH "Stop word list modified size: ". $hash_size . "\n\n"; }

my @output;
my $query_insert_string = "INSERT INTO QUERY_WL VALUES ";

# Insert each term into a new row in QUERY_WL (initially empty table)
foreach my $term (@stemmed_input)
{
	if(exists $STOP_HASH{$term})
	{
		next;
	}
	$output[++$#output] = $term;
	$query_insert_string .= "('" . $term . "'),";
}

# User's terms were all in the stop list...
if($#output eq -1) {
	exit;
}

if($DEBUG eq 1) {
	# Writes values to logfile as they will be used in the query
	# Print user's query terms
	print $LOG_FH "Query Terms (stemmed)[stop-words removed]: ";
	foreach my $dterm (@input_array) { print $LOG_FH $dterm . " "; }
	print $LOG_FH "\n  (";
	foreach my $dterm (@stemmed_input) { print $LOG_FH $dterm . " "; }
	print $LOG_FH ")\n  [";
	foreach my $dterm (@output) { print $LOG_FH $dterm . " "; }
	print $LOG_FH "]";

	# Print exceptions to the stop-list
	if($exceptions) {
		print $LOG_FH "\nStop-list exceptions (stemmed): ";
		foreach my $dterm (@stop_list_exceptions) { print $LOG_FH $dterm . " ";}
		print $LOG_FH "\n  (";
		foreach my $dterm (@stemmed_stop_list_exceptions) { print $LOG_FH $dterm . " "; }
		print $LOG_FH ")";
	}
	# Print required/mandatory words
	if($req_words_str) {
		print $LOG_FH "\nRequired words (stemmed): ";
		foreach my $dterm (@required_words) { print $LOG_FH $dterm . " "; }
		print $LOG_FH "\n (";
		foreach my $dterm (@stemmed_required_words) { print $LOG_FH $dterm . " "; }
		print $LOG_FH ")";
	}
}


chop($query_insert_string); # Remove last character

# Connect to the DB and re-initialize the query table
my $dbh = DBI->connect("DBI:mysql:database=" . $DB_NAME . ";host=localhost", "root", "415faq", { 'RaiseError' => 1});
$dbh->do("USE " . $DB_NAME);
$dbh->do("DELETE FROM QUERY_WL");
$dbh->do($query_insert_string);

my $get_cosine_sql = "SELECT DOC_ID, COSINE, QUESTION_TEXT, ANSWER_TEXT FROM GET_COSINE";

# If additional requirements are specified, the query string is modified
if($req_check eq 1) {
	$get_cosine_sql .= " WHERE DOC_ID IN (SELECT DISTINCT DOC_ID FROM " 
		. $QA_TABLE . " WHERE ";
	foreach my $rterm (@stemmed_required_words) {
		$get_cosine_sql .= "lower(QUESTION_TEXT) like lower('%" . $rterm . "%') AND ";
	}
	$get_cosine_sql = substr($get_cosine_sql, 0, -5);
	$get_cosine_sql .= ")";	
}
my $sth = $dbh->prepare($get_cosine_sql);
$sth->execute();

print $LOG_FH "\n\n";
# The doc_id's are printed in sorted order to STDOUT, and processed in PHP
while (my @row = $sth->fetchrow_array) {
	print $row[0] . ",";

	# Useful info about what happened in the back-end
	if($DEBUG eq 1) {
		print $LOG_FH $row[0] . "\t" . $row[1] . "\nQ: " . 
			$row[2] . "\nA: " . $row[3] . "\n\n";
	}
}
print $LOG_FH "-------------------\n\n";
close($LOG_FH);
