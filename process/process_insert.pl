#!/usr/bin/perl

use Text::English;
use DBD::mysql;
use Digest::MD5 qw(md5_hex);
use Getopt::Long qw(GetOptions);
use strict;
use warnings;
my $DEBUG = 0;


# Parses a CSV file in the format [question]|[answer]|[category]
# Input is sanitized, words in the [question] are stemmed, and inserted
#  into the database
# Instead of using INT DOC_ID, I decided to use an md5 hash since it made it easier to
# insert into multiple 2 tables individually while using the same DOC_ID.
# This script ignores stop-words, since they are already removed from the user's query
#  and can be re-added for term reweighting


# Default input file and column delimiter, global variables
my $INPUT_FILE = "input.csv";
my $COL_DELIMITER = '|';
my $DB_NAME = "FAQ415";
my $QA_TABLE = "QUESTION_ANSWER_MASTER";
my $WORD_TABLE = "WORD_LIST";

# Connect to the DB and clear existing table data
my $dbh = DBI->connect("DBI:mysql:database=" . $DB_NAME . ";host=localhost", "root", "415faq", { 'RaiseError' => 1});
$dbh->do("USE " . $DB_NAME);

# Delta or full load of questions
if(scalar @ARGV eq 1) {
	my $delta;
	my $full;
	GetOptions(
		'delta' => \$delta,
		'full' => \$full
	);
	if($full) {
		$dbh->do("DELETE FROM " . $WORD_TABLE);
		$dbh->do("DELETE FROM " . $QA_TABLE);
	}
}

open(my $FH, '<', $INPUT_FILE) or die "ERROR Unable to open file\n";

# If testing something out, don't delete the production tables!
if($DEBUG eq 1) { $QA_TABLE = "QUESTION_ANSWER_MASTER_DEBUG"; }
if($DEBUG eq 1) { $WORD_TABLE = "WORD_LIST_DEBUG"; }

# Process input file one line at a time
while (my $line = <$FH>) {
	chomp $line;
	# Make sure the line is valid
	if (length $line < 10) { next; }

	my @cols = split('\|', $line);

	# Delimit quotes for SQL insert
	my $question_text = $cols[0];
	$question_text =~ s/\'/\'\'/g;
	my $answer_text = $cols[1];
	$answer_text =~ s/\'/\'\'/g;
	# Generate doc_id value
	my $digest = md5_hex($question_text);
	my $sql_cmd = "INSERT INTO " . $QA_TABLE . " (DOC_ID, QUESTION_TEXT, ANSWER_TEXT, CATEGORY) VALUES('" . $digest . "','" . $question_text . "','" . $answer_text . "','" . $cols[2] . "')";
	if ($DEBUG eq 1) {
		print "\n\n**** DEBUG1: " . $sql_cmd . "\n";
	}
	$dbh->do($sql_cmd);

	# Remove non-alphanumeric characters
	$question_text =~ s/[^a-zA-Z0-9 ]//g;
	# Stem each word in the question
	my @question_stemmed = Text::English::stem(split /\s+/, $question_text);
	my %question_hash;

	# Calculate TF
	foreach my $str (@question_stemmed) {
		$question_hash{$str}++;
	}

	# Insert each term into WORD_LIST table
	foreach my $term (sort keys %question_hash) {
		my $sql_insert_term = "INSERT INTO " . $WORD_TABLE . " (DOC_ID, QUERY_TERM, TERM_FREQUENCY) VALUES('" . $digest . "','" . $term . "','" . $question_hash{$term} . "')";
		
		if($DEBUG eq 1) {
			print "\n\n**** DEBUG2: " . $sql_insert_term . "\n";
		}
		$dbh->do($sql_insert_term);
	}
}

$dbh->disconnect();
