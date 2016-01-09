## Summary of process_insert.pl
This script loads the documents into the library.

Note that the database, tables, and views must be created before running this script since its primary function is to parse and insert rows into the various tables.

Input is processed from a delimited text file (e.g. csv) in the following structure:
QUESTION_TEXT [delim] ANSWER_TEXT [delim] CATEGORY

In order to perform term stemming, we used the Text::English module which will probably need to be installed via CPAN first.

The script generates an MD5 hash to be used for each document's DOC_ID and inserts the values into QUESTION_ANSWER_MASTER. After, each term is stemmed, frequency is counted, and they are inserted into WORD_LIST using the same DOC_ID.

### **-full** flag
This is an optional flag that can be specified at runtime to indicate that a full document collection is being loaded.

Therefore, if this flag is set, all existing data in the tables is deleted.

### Local Variables
It is likely that some of the variables will need to be modified for the script to run in a different environment:
* **DEBUG** - If set to 1, the production tables will not be used, using instead QUESTION_ANSWER_MASTER_DEBUG and WORD_LIST_DEBUG.
* **INPUT_FILE** - default is *input.csv*.
* **COL_DELIMITER** - default is *|*, this is what delimits each column in the input file.
* **DB_NAME** - default is *FAQ415*.

Note that the DB Connect information will also need to be updated with valid credentials.