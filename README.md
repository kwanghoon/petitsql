# Petit Sql
- A little model for showing the absence of SQL injections, namely SQL
  injection-free

- The SQL injection-free property 

  - For all SQL expressions sql, when a string v is substitued for a
    variable x in sql, the structure of the SQL expression (sql) is
    preserved in the substituted SQL expression (injection x v sql).
  
  - The property can be written in Haskell QuickCheck as follows. 
  
```
         injFree (norm sql) . norm . sqlFrom . parseSQL . (printSQL . injection x v) $ sql
```

  - Note that this property depends on how to build a query string that contains an SQL expression. 
  
- Petit Sql models it by two ways.

  - a tree structure based query representation in a programming language and 
  
  - a quote-aware stringfication (i.e., a query with a predicate x=v
    where v is "' or 1=1" is translated into " ... ''' or 1=1 ... " by
    replacing a single quote in the string value into triples of a
    single quote.)
    

- Every (database) programming language supporting the tree structure query representation and the quote-aware stringfication has the SQL injection-free property. 

- QuickCheck has successfully verified the injection-free property on the Petit Sql model. 


## How to install and run
- [Install the Haskell tool, stack ](https://docs.haskellstack.org/en/stable/install_and_upgrade/)
- Run it:
```
   $ git clone https://github.com/kwanghoon/petitsql
   $ cd petitsql
   $ stack test

   $ stack test
   petitsql> test (suite: petitsql-test)


   SQL injection free?
     For all sql, x, and v, sql is injection-free from injection x v sql
    +++ OK, passed 100 tests.

   Finished in 0.0216 seconds
   1 example, 0 failures

   petitsql> Test suite petitsql-test passed
```
