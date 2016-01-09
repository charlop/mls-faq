# Overview
The purpose of this project is to implement a simple search engine where users can ask questions and receive a list of result ordered by relevance. Using various information retrieval techniques, a collection of documents is loaded into the library and each term in the documents is stemmed, indexed, and relevant weighting values are calculated. Motivated by portability, all calculations are handled through database views and UDFs. Consequently, many calculations must be done every time a user submits their query so performance is correlated to the size of the document library. Based on our results using a VM running Debian with 1GB of RAM, query response time starts to exceed 500ms when there are approximately 100 documents.

After a user receives their results, they can modify their query by selecting terms that *must* be included in the result.


# Requirements
In order to run this application, a server needs only two applications: an SQL database, Perl, and PHP. Although the code was written for Linux, it can be ported to Windows possibly without any modification of code. The SQL statements have only been tested on a MySQL database but we tried to stick to strict DDL and DML syntax so any SQL database will suffice.

If MySQL is *not* used as the database, the DB connect strings in the Perl scripts will need to be modified accordingly.

# Setup
The DDL is stored in the **create_tables_and_views.sql** script. You must first create your database before executing the script. Note that the script assumes the database name is **FAQ415**, so if the current database has a different name, it should be updated in the script. PHP and Perl need to be installed as well.

See **docs/sql.md** for a more through explanation of the database operations.
See **docs/process_insert.md** and **docs/tf_calc.md** for details on the Perl scripts.