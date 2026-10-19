3- future problems:
    
prevent empty msg
handle timestamps consistently using UTC
index to improve data-based queries

4- What would happen with 100,000 records, or with two users writing at the same time.

I think for postgreSQL 100,000 records is not a problem, if the DB has the right config, for ex Index=TRUE, for two user writing at the same time, if the DB have a big autofield for the id, that will not be a problem, but if they ID is add manualy will be a problem, they may be will get duplicated ID.

5- Would be better mongoDB or redis for this problem?

For this case, redis is usefull for performance and speed, however postgre is the best option for main database, because is structured, have persistent data with containers and transactions. MongoDB is unnecessary unless flexible document storage is required. Redis can complement PostgreSQL by caching frequently accessed data, rather than replacing it. 