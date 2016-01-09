## Summary of tf_calc.pl
This script is called when a user submits a query to make the relevant back-end database calls.

The script performs a few tasks:
1. Remove stop-words, unless they are in the *stop-list exceptions* list.
2. Stem each term from the user's input to get the base word.
3. Sanitize input so it can be inserted in the database, and perform the INSERT into **QUERY_WL**
4. Run a SELECT statement on the **GET_COSINE** view to retrieve results, and return them as a comma-separated list to PHP.

### Command-line Arguments
Execute a query using the following synax:
[script_name] "[query terms]" --stop "[stop-list exceptions]" --req "[mandatory terms]"
* *[query terms]* is the verbatim sanitized input provided by the user.
* *[stop-list exceptions]* (**optional**) words that should be included even if they are very common terms (stop-words such as *most*, *best*, *which*).
* *[mandatory terms]* (**optional**) words that *must* be included in the result.

### Local Variables
It is likely that some of the variables will need to be modified for the script to run in a different environment:
* **DEBUG** - If set to 1, extensive logging is done, so that each step of the calculation can be seen.
* **DB_NAME** - default is *FAQ415*.
* **STOP_WORD_FILE** - the name of the file containing words for the stop-list (default is *stopwords.txt*).
* **LOG_FILE** - only necessary if DEBUG mode is on, this is where the debug output is logged to.

Note that the DB Connect information will also need to be updated with valid credentials.