IMPORT com
IMPORT FGL wordle_webservice
IMPORT FGL wordle_db

MAIN
DEFINE result INTEGER

    CONNECT TO ":memory:+driver='dbmsqt'" -- Connect to different database, in this case an inmemory SQLite database
    CALL wordle_db.db_init()
    CALL wordle_db.db_populate()

    CALL com.WebServiceEngine.RegisterRestService("wordle_webservice","Wordle")
    CALL com.WebServiceEngine.Start()
    WHILE TRUE
        LET result = com.WebServiceEngine.ProcessServices(-1)
    END WHILE
END MAIN

# use this to test

#http://localhost:8091/Wordle/random/
#http://localhost:8091/Wordle/today/