FUNCTION db_init()

    CREATE TABLE word_list(idx INTEGER, word CHAR(5), candidate BOOLEAN)

    CREATE UNIQUE INDEX ix_word_list_1 ON word_list(idx)
    CREATE UNIQUE INDEX ix_word_list_2 ON word_list(word)
END FUNCTION

FUNCTION db_populate()
    DEFINE l_solution_list, l_candidate_list STRING
    DEFINE l_word CHAR(5)
    DEFINE l_quoted_word STRING

    DEFINE l_index INTEGER

    VAR ch = base.Channel.create() -- base.Channel type to work with files, pipes
    CALL ch.openFile("../wordle_lib/wordle.txt", "r") -- open file for reading

    -- Read two lines of this file
    -- First line contains list of possible solutions
    -- Second line contains list of valid guesses
    LET l_solution_list = ch.readLine() -- read a line
    LET l_candidate_list = ch.readLine()
    CALL ch.close()

    LET l_index = 0
    -- Parse the list of solution words
    -- Use stringTokenizer to split by ,
    -- Remove quotes
    VAR tok = base.StringTokenizer.create(l_solution_list, ",") -- String tokenizer, to iterate through delimited string
    WHILE tok.hasMoreTokens() -- are there more tokens
        LET l_quoted_word = tok.nextToken() -- get the next token
        LET l_word = upshift(l_quoted_word.subString(2, 6)) -- methods on datatypes

        LET l_index = l_index + 1
        INSERT INTO word_list VALUES(l_index, l_word, TRUE)
    END WHILE
    #LET m_solution_word_count = l_index

    -- Parse the list of solution words
    LET tok = base.StringTokenizer.create(l_candidate_list, ",")
    WHILE tok.hasMoreTokens()
        LET l_quoted_word = tok.nextToken()
        LET l_word = upshift(l_quoted_word.subString(2, 6))

        LET l_index = l_index + 1
        INSERT INTO word_list VALUES(l_index, l_word, FALSE)
    END WHILE
    #LET m_candidate_word_count = l_index - m_solution_word_count
END FUNCTION