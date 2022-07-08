-- Comments out here indicate Genero syntax
IMPORT FGL fglsvgcanvas -- Import another 4gl module

CONSTANT WORD_LENGTH = 5 -- Constant
CONSTANT GUESS_LIMIT = 6
CONSTANT WORDLE_GUESS_STATE_NEVERGUESSED = -1
CONSTANT WORDLE_GUESS_STATE_INCORRECT = 0
CONSTANT WORDLE_GUESS_STATE_CLOSE = 1
CONSTANT WORDLE_GUESS_STATE_CORRECT = 2

DEFINE m_solution_word_count, m_candidate_word_count INTEGER

TYPE wordle_guess_state_type ARRAY[WORD_LENGTH] OF INTEGER -- TYPE
TYPE wordle_word_type CHAR(WORD_LENGTH)
TYPE wordle_keyboard_state_type ARRAY[26] OF INTEGER

TYPE wordle_game_state_type RECORD
    word wordle_word_type, -- this is the word we are looking for
    round INTEGER, -- what round are we in 1
    cursor INTEGER, -- what letter is currently being entered by the virtual keyboard
    guess ARRAY[GUESS_LIMIT] OF RECORD
        word wordle_word_type, -- what word did user enter on this guess
        result wordle_guess_state_type -- what was the result of this guess
    END RECORD,
    keyboard wordle_keyboard_state_type
END RECORD





MAIN

    DEFER INTERRUPT
    DEFER QUIT
    OPTIONS FIELD ORDER FORM -- Tab order based on order in form not INPUT statement.  TODO Check if that was in 4gl
    OPTIONS INPUT WRAP

    CALL ui.Interface.loadStyles("wordle.4st") -- Load Styles

    OPEN FORM f FROM "wordle_grid"
    DISPLAY FORM f

    CONNECT TO ":memory:+driver='dbmsqt'" -- Connect to different database, in this case an inmemory SQLite database
    CALL db_init()
    CALL db_populate()

    CALL play()
END MAIN

FUNCTION play()

    DEFINE wordle wordle_game_state_type

    INITIALIZE wordle.* TO NULL
    LET wordle.word = todays_word()
    LET wordle.round = 1
    LET wordle.cursor = 1
    VAR letter_ord INTEGER -- Temporary variabe
    FOR letter_ord = 1 TO 26
        LET wordle.keyboard[letter_ord] = WORDLE_GUESS_STATE_NEVERGUESSED
    END FOR

    WHILE wordle.round <= GUESS_LIMIT
        CALL turn(wordle)
        CALL test_guess(wordle)
        CALL display_guess(wordle)
        CALL update_keyboard(wordle)

        IF wordle.word = wordle.guess[wordle.round].word THEN
            EXIT WHILE
        END IF

        LET wordle.round += 1
        LET wordle.cursor = 1

    END WHILE
    IF wordle.round <= GUESS_LIMIT THEN
        CALL game_success(wordle.round)
    ELSE
        CALL game_fail(wordle.word)
    END IF
    #TODO Display Statistics
END FUNCTION

FUNCTION todays_word()
    DEFINE todays_word CHAR(5)
    DEFINE todays_word_idx INTEGER

    -- I think this is how wordle chooses its word
    -- It has a 2309 element list of words and it just selects the next one each day
    -- It is not actually random ...
    LET todays_word_idx = ((TODAY - MDY(6, 19, 2021)) MOD 2309) + 1
    SELECT word INTO todays_word FROM word_list WHERE idx = todays_word_idx

    RETURN todays_word
END FUNCTION

FUNCTION turn(wordle wordle_game_state_type INOUT) -- INOUT variable

DEFINE id STRING


    MENU ""
        &define guess(p1) ON ACTION press_ ## p1 ATTRIBUTES(ACCELERATOR = #p1 ) CALL enter_letter(upshift(#p1) , wordle)            -- Preprocessor
        guess(a)
        guess(b)
        guess(c)
        guess(d)
        guess(e)
        guess(f)
        guess(g)
        guess(h)
        guess(i)
        guess(j)
        guess(k)
        guess(l)
        guess(m)
        guess(n)
        guess(o)
        guess(p)
        guess(q)
        guess(r)
        guess(s)
        guess(t)
        guess(u)
        guess(v)
        guess(w)
        guess(x)
        guess(y)
        guess(z)

        ON ACTION press_enter ATTRIBUTES(ACCELERATOR = "Return") -- ON ACTION, ATTRIBUTES
            IF wordle.cursor <= WORD_LENGTH THEN
                CALL FGL_WINMESSAGE("Error", "Not enough letters", "stop") -- Build it dialog
                CONTINUE MENU
            END IF
            -- Check if valid word
            IF in_dictionary(wordle.guess[wordle.round].word) THEN
                EXIT MENU
            ELSE
                CALL FGL_WINMESSAGE("Error", "Not in word list", "stop")
                CONTINUE MENU
            END IF

        ON ACTION press_back ATTRIBUTES(ACCELERATOR = "Backspace")
            IF wordle.cursor > 1 THEN
                -- remove display of letter
                LET wordle.cursor = wordle.cursor - 1
                VAR field_name = SFMT("guess%1%2", wordle.round, wordle.cursor) -- VAR, temporary variable
                LET wordle.guess[wordle.round].word[wordle.cursor] = " "
                CALL ui.Form.displayTo(" ", field_name, NULL, NULL) -- generic display, passing fieldname

            ELSE
                -- Do nothing
            END IF

        ON ACTION close
            EXIT PROGRAM
    END MENU
END FUNCTION

FUNCTION test_guess(wordle wordle_game_state_type INOUT)
    DEFINE letter_idx INTEGER

    FOR letter_idx = 1 TO WORD_LENGTH
        CASE
            WHEN wordle.word[letter_idx] = wordle.guess[wordle.round].word[letter_idx]
                LET wordle.guess[wordle.round].result[letter_idx] = WORDLE_GUESS_STATE_CORRECT
            WHEN wordle.word MATCHES ("*" || wordle.guess[wordle.round].word[letter_idx] || "*")
                LET wordle.guess[wordle.round].result[letter_idx] = WORDLE_GUESS_STATE_CLOSE
            OTHERWISE
                LET wordle.guess[wordle.round].result[letter_idx] = WORDLE_GUESS_STATE_INCORRECT
        END CASE
    END FOR
END FUNCTION

FUNCTION display_guess(wordle wordle_game_state_type)
    DEFINE letter_idx INTEGER
    DEFINE field_name STRING
    DEFINE style STRING


    FOR letter_idx = 1 TO WORD_LENGTH
        LET field_name = SFMT("formonly.guess%1%2", wordle.round USING "<", letter_idx USING "<") -- SFMT
        CASE wordle.guess[wordle.round].result[letter_idx]
            WHEN WORDLE_GUESS_STATE_CORRECT
                LET style = "correct"
            WHEN WORDLE_GUESS_STATE_CLOSE
                LET style = "close"
            OTHERWISE
                LET style = "incorrect"
        END CASE
        CALL ui.Window.getCurrent().getForm().setFieldStyle(field_name, style) -- . notation
    END FOR -- changing style
END FUNCTION

FUNCTION update_keyboard(wordle wordle_game_state_type)
    DEFINE letter_idx INTEGER

    DEFINE letter CHAR(1)
    DEFINE field_name STRING
    DEFINE style STRING
    DEFINE letter_ord INTEGER

    FOR letter_idx = 1 TO WORD_LENGTH
        LET letter = wordle.guess[wordle.round].word[letter_idx]
        LET letter_ord = ORD(letter) - 64

        IF wordle.guess[wordle.round].result[letter_idx] > wordle.keyboard[letter_ord] THEN
            LET wordle.keyboard[letter_ord] = wordle.guess[wordle.round].result[letter_idx]

            LET field_name = "press_", downshift(letter)

            CASE wordle.keyboard[letter_ord]
                WHEN WORDLE_GUESS_STATE_CORRECT
                    LET style = "correct"
                WHEN WORDLE_GUESS_STATE_CLOSE
                    LET style = "close"
                OTHERWISE
                    LET style = "incorrect"
            END CASE

            CALL ui.Window.getCurrent().getForm().setElementStyle(field_name, style)
             
        END IF
    END FOR
END FUNCTION



FUNCTION in_dictionary(word wordle_word_type) RETURNS BOOLEAN

    SELECT 'X' FROM word_list WHERE @word = $word                                                                                   -- Syntax to distinguish variable and database column

    IF status = NOTFOUND THEN
        RETURN FALSE
    ELSE
        RETURN TRUE
    END IF
END FUNCTION

FUNCTION enter_letter(letter CHAR(1), wordle wordle_game_state_type INOUT)

    IF wordle.cursor > WORD_LENGTH THEN
        -- Ignore keypress
        RETURN
    END IF

    LET wordle.guess[wordle.round].word[wordle.cursor] = letter
    CALL ui.Form.displayTo(letter, SFMT("guess%1%2", wordle.round, wordle.cursor), NULL, NULL) -- SFMT, string formatter

    LET wordle.cursor += 1
END FUNCTION

FUNCTION game_success(guesses INTEGER)
    DEFINE success_message ARRAY[GUESS_LIMIT] OF STRING =
        ["Genius", "Magnificent", "Impressive", "Splendid", "Great", "Phew"] -- Assignment as part of definition

    CALL FGL_WINMESSAGE("Info", success_message[guesses], "info")
END FUNCTION

FUNCTION game_fail(word STRING)
    CALL FGL_WINMESSAGE("Info", word, "stop")
END FUNCTION

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
    LET m_solution_word_count = l_index

    -- Parse the list of solution words
    LET tok = base.StringTokenizer.create(l_candidate_list, ",")
    WHILE tok.hasMoreTokens()
        LET l_quoted_word = tok.nextToken()
        LET l_word = upshift(l_quoted_word.subString(2, 6))

        LET l_index = l_index + 1
        INSERT INTO word_list VALUES(l_index, l_word, FALSE)
    END WHILE
    LET m_candidate_word_count = l_index - m_solution_word_count
END FUNCTION









--FUNCTION get_letter(row INTEGER, col INTEGER) RETURNS CHAR(1)
--TODO figure out syntax to initialise multidimensional array
--    DEFINE row1 ARRAY[10] OF CHAR(1) = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
--    DEFINE row2 ARRAY[9] OF CHAR(1) = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
--    DEFINE row3 ARRAY[7] OF CHAR(1) = ["Z", "X", "C", "V", "B", "N", "M"]
--
--    CASE row
--        WHEN 1
--            RETURN row1[col]
--        WHEN 2
--            RETURN row2[col]
--        WHEN 3
--            RETURN row3[col]
--    END CASE
--    RETURN ""
--END FUNCTION
