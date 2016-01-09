## Summary of the SQL Script
When run, this script will create:
* Four tables:
  * **CATEGORIES** - each document may be assigned to a category. This is the lookup table that constrains what categories may be used.
  * **QUESTION_ANSWER_MASTER** - this table contains the full question and answer text, as it will be displayed on the search results page. Each document also has a DOC_ID, which is a simple MD5 hash used to create a relation between subsequent tables.
  * **WORD_LIST** - stores each *stemmed* term from every document, as well as the frequency of that term in the specific document. The DOC_ID here references QUESTION_ANSWER_MASTER(DOC_ID).
  * **QUERY_WL** - when a user enters a query, each term is stemmed and inserted into this table. Further down, calculations are done in a view to determine the Cosine similarity.
* One UDF:
  * **CALC_IDF** - Function that takes a term as input and calculates its inverse document frequency (IDF). The formula used is: IDF = log( [total # of documents in the collection] / [# of documents containing the given term] ). This function is used in the **WORD_LIST_CALC** view to populate the CALC_IDF column.
* Seven views:
  * **WORD_LIST_CALC** - Identical to the WORD_LIST table, but with an extra column for the CALC_IDF value.
  * **TERM_CALC_VIEW** - Summarizes the WORD_LIST_CALC view by selecting only distinct terms. This is used when calculating the IDF values in the user's query.
  * **QUERY_WL_VIEW** - Inner join on TERM_CALC_VIEW and QUERY_WL to get the term frequency and IDF value of the user's query.
  * **QUERY_DOC_CALC** - Calculates the dividend of the Cosine similarity function by multiplying the document's and query's TF*IDF values and then summing them all together.
  * **GET_QUERY_BOTTOM** - Squares each TF*IDF value in QUERY_WL_VIEW, then sums them and calculates the square-root. This is one half of the Cosine function's divisor.
  * **GET_DOC_BOTTOM** - Same as GET_QUERY_BOTTOM but using the term frequency values from the document collection instead.
  * **GET_COSINE** - Calculates the Cosine similarity value for each DOC_ID by combining the results from the three views above, and returns an ordered list.