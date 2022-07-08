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

DEFINE gameboard_canvas_id, keyboard_canvas_id SMALLINT
DEFINE root_gameboard_svg, root_keyboard_svg om.DomNode



MAIN

    DEFER INTERRUPT
    DEFER QUIT
    OPTIONS FIELD ORDER FORM -- Tab order based on order in form not INPUT statement.  TODO Check if that was in 4gl
    OPTIONS INPUT WRAP

    CALL ui.Interface.loadStyles("wordle.4st") -- Load Styles

    OPEN FORM f FROM "wordle_canvas"
    DISPLAY FORM f
    CALL draw_svg_gameboard()
    CALL draw_svg_keyboard()

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
DEFINE keyboard STRING
DEFINE id STRING
DEFINE nl om.NodeList

    INPUT BY NAME keyboard ATTRIBUTES(ACCEPT=FALSE, CANCEL=FALSE)
       
        ON ACTION keyboard_click ATTRIBUTES(DEFAULTVIEW=NO, CONTEXTMENU=NO)
            LET id = fglsvgcanvas.getItemId(keyboard_canvas_id)
            CASE
                WHEN id = "ENTER"
                    IF wordle.cursor <= WORD_LENGTH THEN
                        CALL FGL_WINMESSAGE("Error", "Not enough letters", "stop") -- Build it dialog
                        CONTINUE INPUT
                    END IF
                    -- Check if valid word
                    IF in_dictionary(wordle.guess[wordle.round].word) THEN
                        EXIT INPUT
                    ELSE
                        CALL FGL_WINMESSAGE("Error", "Not in word list", "stop")
                        CONTINUE INPUT
                    END IF
                    
                WHEN id = "BACK"
                    IF wordle.cursor > 1 THEN
                        -- remove display of letter
                        LET wordle.cursor = wordle.cursor - 1
                        LET wordle.guess[wordle.round].word[wordle.cursor] = " "

                        CALL fglsvgcanvas.setCurrent(gameboard_canvas_id)
                        -- remove text node 
                        LET nl =  root_gameboard_svg.selectByPath(SFMT("//text[@id=\"txt_%1\"]", gameboard_svg_id(wordle.round, wordle.cursor)))
                        IF nl.getLength() = 1 THEN
                            VAR text_node = nl.item(1)
                            CALL root_gameboard_svg.removeChild(text_node)
                        END IF     
                        CALL fglsvgcanvas.display(gameboard_canvas_id)
                    ELSE
                        -- Do nothing
                    END IF
                    
                WHEN id MATCHES "[A-Z]"
                    CALL enter_letter(upshift(id), wordle)
            END CASE
            
        ON ACTION close
            EXIT PROGRAM
    END INPUT
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
    DEFINE style STRING

    CALL fglsvgcanvas.setCurrent(gameboard_canvas_id)
    FOR letter_idx = 1 TO WORD_LENGTH
        CASE wordle.guess[wordle.round].result[letter_idx]
            WHEN WORDLE_GUESS_STATE_CORRECT
                LET style = "correct"
            WHEN WORDLE_GUESS_STATE_CLOSE
                LET style = "close"
            OTHERWISE
                LET style = "incorrect"
        END CASE
        
        VAR nl = root_gameboard_svg.selectByPath(SFMT("//rect[@id=\"%1\"]", gameboard_svg_id(wordle.round, letter_idx)))
        IF nl.getLength() = 1 THEN
            VAR rect_node = nl.item(1)
            CALL rect_node.setAttribute(SVGATT_CLASS,style)
        END IF

        LET nl =  root_gameboard_svg.selectByPath(SFMT("//text[@id=\"txt_%1\"]", gameboard_svg_id(wordle.round, letter_idx)))
        IF nl.getLength() = 1 THEN
            VAR text_node = nl.item(1)
            CALL text_node.setAttribute(SVGATT_CLASS,"white")
        END IF
    END FOR 
    CALL fglsvgcanvas.display(gameboard_canvas_id)
END FUNCTION



FUNCTION update_keyboard(wordle wordle_game_state_type)
    DEFINE letter_idx INTEGER

    DEFINE letter CHAR(1)
    DEFINE style STRING
    DEFINE letter_ord INTEGER



    CALL fglsvgcanvas.setCurrent(keyboard_canvas_id)

    FOR letter_idx = 1 TO WORD_LENGTH
        LET letter = wordle.guess[wordle.round].word[letter_idx]
        LET letter_ord = ORD(letter) - 64

        IF wordle.guess[wordle.round].result[letter_idx] > wordle.keyboard[letter_ord] THEN
            LET wordle.keyboard[letter_ord] = wordle.guess[wordle.round].result[letter_idx]

            CASE wordle.keyboard[letter_ord]
                WHEN WORDLE_GUESS_STATE_CORRECT
                    LET style = "correct"
                WHEN WORDLE_GUESS_STATE_CLOSE
                    LET style = "close"
                OTHERWISE
                    LET style = "incorrect"
            END CASE

            VAR nl = root_keyboard_svg.selectByPath(SFMT("//rect[@id=\"%1\"]", upshift(letter)))
            IF nl.getLength() = 1 THEN
                VAR r = nl.item(1)
                CALL r.setAttribute(SVGATT_CLASS,style)
            END IF
            LET nl = root_keyboard_svg.selectByPath(SFMT("//text[@id=\"txt_%1\"]", upshift(letter)))
            IF nl.getLength() = 1 THEN
                VAR t = nl.item(1)
                CALL t.setAttribute(SVGATT_CLASS, 'white')
            END IF
             
        END IF
    END FOR
    CALL fglsvgcanvas.display(keyboard_canvas_id)
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
DEFINE text_node om.DomNode

    IF wordle.cursor > WORD_LENGTH THEN
        -- Ignore keypress
        RETURN
    END IF

    LET wordle.guess[wordle.round].word[wordle.cursor] = letter

    CALL fglsvgcanvas.setCurrent(gameboard_canvas_id)

        LET text_node = fglsvgcanvas.text(10 + ( wordle.cursor - 1) * 20, (wordle.round - 1) * 20 + 10, wordle.guess[wordle.round].word[wordle.cursor], "")

        CALL root_gameboard_svg.appendChild(text_node)
        CALL text_node.setAttribute("id",SFMT("txt_%1", gameboard_svg_id(wordle.round, wordle.cursor)))
        CALL text_node.setAttribute("alignment-baseline","central")
        CALL text_node.setAttribute("text-anchor","middle")
        CALL text_node.setAttribute("font-size","7px")
        CALL text_node.setAttribute("pointer-events","none")
        CALL text_node.setAttribute(SVGATT_CLASS, "black")

    CALL fglsvgcanvas.display(gameboard_canvas_id)
    
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

FUNCTION draw_svg_gameboard()
DEFINE row, col INTEGER
DEFINE rect_node, defs_node om.DomNode
    DEFINE attr DYNAMIC ARRAY OF om.SaxAttributes


    CALL fglsvgcanvas.initialize()
    LET gameboard_canvas_id  = fglsvgcanvas.create("formonly.gameboard")
    CALL fglsvgcanvas.setCurrent(gameboard_canvas_id)

    LET root_gameboard_svg = fglsvgcanvas.setRootSVGAttributes(NULL, NULL, NULL, SFMT("0 0 %1 %2", WORD_LENGTH*20, GUESS_LIMIT*20), "xMidYMid meet")

    CALL root_gameboard_svg.setAttribute(SVGATT_CLASS, "root_svg")

    -- Init
    LET attr[1] = om.SaxAttributes.create()
    CALL attr[1].addAttribute(SVGATT_FILL, "white")
    CALL attr[1].addAttribute(SVGATT_STROKE, "#d0d0d0")

    -- Close
    LET attr[2] = om.SaxAttributes.create()
    CALL attr[2].addAttribute(SVGATT_FILL, "#bda747")

    -- InCorrect
    LET attr[3] = om.SaxAttributes.create()
    CALL attr[3].addAttribute(SVGATT_FILL, "#65696d")

    -- Correct
    LET attr[4] = om.SaxAttributes.create()
    CALL attr[4].addAttribute(SVGATT_FILL, "#599d51")

    -- White
    LET attr[5] = om.SaxAttributes.create()
    CALL attr[5].addAttribute(SVGATT_FILL, "white")
    CALL attr[5].addAttribute(SVGATT_FONT_FAMILY, "Arial")

     -- Black
    LET attr[6] = om.SaxAttributes.create()
    CALL attr[6].addAttribute(SVGATT_FILL, "black")
    CALL attr[6].addAttribute(SVGATT_FONT_FAMILY, "Arial")


    LET defs_node = fglsvgcanvas.defs(NULL)
    CALL defs_node.appendChild(
        fglsvgcanvas.styleList(
            fglsvgcanvas.styleDefinition(".init", attr[1]) || fglsvgcanvas.styleDefinition(".close", attr[2])
                || fglsvgcanvas.styleDefinition(".incorrect", attr[3]) || fglsvgcanvas.styleDefinition(".correct", attr[4]) || fglsvgcanvas.styleDefinition(".white", attr[5]) || fglsvgcanvas.styleDefinition(".black", attr[6])))
    CALL root_gameboard_svg.appendChild(defs_node)

    FOR row = 1 TO GUESS_LIMIT
        FOR col = 1 TO WORD_LENGTH
            CALL root_gameboard_svg.appendChild(rect_node := fglsvgcanvas.rect(1 + (col - 1) * 20, (row - 1) * 20 + 1, 18, 18, 0, 0))
            CALL init_keyboard_rect_node(rect_node,gameboard_svg_id(row,col))
        END FOR
    END FOR
    CALL fglsvgcanvas.display(gameboard_canvas_id)
END FUNCTION

PRIVATE FUNCTION gameboard_svg_id(row INTEGER, col INTEGER)
    RETURN SFMT("%1x%2", row USING "<", col USING "<")
END FUNCTION

PRIVATE FUNCTION init_gameboard_rect_node(r om.DomNode, id STRING)
    CALL r.setAttribute(SVGATT_CLASS, 'init')
    CALL r.setAttribute("id", id)
END FUNCTION




FUNCTION draw_svg_keyboard()

    DEFINE  rect_node, text_node, defs_node om.DomNode
    DEFINE row, col INTEGER
    DEFINE attr DYNAMIC ARRAY OF om.SaxAttributes

    CALL fglsvgcanvas.initialize()
    LET keyboard_canvas_id  = fglsvgcanvas.create("formonly.keyboard")
    CALL fglsvgcanvas.setCurrent(keyboard_canvas_id)

    LET root_keyboard_svg = fglsvgcanvas.setRootSVGAttributes(NULL, NULL, NULL, "0 0 200 60", "xMidYMid meet")

    CALL root_keyboard_svg.setAttribute(SVGATT_CLASS, "root_svg")

    -- Init
    LET attr[1] = om.SaxAttributes.create()
    CALL attr[1].addAttribute(SVGATT_FILL, "#c9c2d2")

    -- Close
    LET attr[2] = om.SaxAttributes.create()
    CALL attr[2].addAttribute(SVGATT_FILL, "#bda747")

    -- InCorrect
    LET attr[3] = om.SaxAttributes.create()
    CALL attr[3].addAttribute(SVGATT_FILL, "#65696d")

    -- Correct
    LET attr[4] = om.SaxAttributes.create()
    CALL attr[4].addAttribute(SVGATT_FILL, "#599d51")

    -- White
    LET attr[5] = om.SaxAttributes.create()
    CALL attr[5].addAttribute(SVGATT_FILL, "white")
    CALL attr[5].addAttribute(SVGATT_FONT_FAMILY, "Arial")

     -- Black
    LET attr[6] = om.SaxAttributes.create()
    CALL attr[6].addAttribute(SVGATT_FILL, "black")
    CALL attr[6].addAttribute(SVGATT_FONT_FAMILY, "Arial")


    LET defs_node = fglsvgcanvas.defs(NULL)
    CALL defs_node.appendChild(
        fglsvgcanvas.styleList(
            fglsvgcanvas.styleDefinition(".init", attr[1]) || fglsvgcanvas.styleDefinition(".close", attr[2])
                || fglsvgcanvas.styleDefinition(".incorrect", attr[3]) || fglsvgcanvas.styleDefinition(".correct", attr[4]) || fglsvgcanvas.styleDefinition(".white", attr[5]) || fglsvgcanvas.styleDefinition(".black", attr[6])))
    CALL root_keyboard_svg.appendChild(defs_node)

    LET row = 1
    FOR col = 1 TO 10
        CALL root_keyboard_svg.appendChild(rect_node := fglsvgcanvas.rect(1 + (col - 1) * 20, (row - 1) * 20 + 1, 18, 18, 2, 2))
        VAR letter = get_letter(row, col)
        CALL init_keyboard_rect_node(rect_node, letter)
        
        CALL root_keyboard_svg.appendChild(text_node := fglsvgcanvas.text(10 + (col - 1) * 20, (row - 1) * 20 + 10, letter, "black"))
        CALL init_keyboard_text_node(text_node, letter)
    END FOR
    LET row = 2
    FOR col = 1 TO 9
        CALL root_keyboard_svg.appendChild(rect_node := fglsvgcanvas.rect(11 + (col - 1) * 20, (row - 1) * 20 + 1, 18, 18, 2, 2))
        VAR letter = get_letter(row, col)
        CALL init_keyboard_rect_node(rect_node, letter)
        
        CALL root_keyboard_svg.appendChild(text_node := fglsvgcanvas.text(20 + (col - 1) * 20, (row - 1) * 20 + 10, letter, "black"))
        CALL init_keyboard_text_node(text_node, letter)
        
    END FOR
    LET row = 3
    FOR col = 1 TO 7
        CALL root_keyboard_svg.appendChild(rect_node := fglsvgcanvas.rect(31 + (col - 1) * 20, (row - 1) * 20 + 1, 18, 18, 2, 2))
        VAR letter = get_letter(row, col)
        CALL init_keyboard_rect_node(rect_node, letter)
        
        CALL root_keyboard_svg.appendChild(text_node := fglsvgcanvas.text(40 + (col - 1) * 20, (row - 1) * 20 + 10, letter, "black"))
        CALL init_keyboard_text_node(text_node, letter)
        
    END FOR
    CALL root_keyboard_svg.appendChild(rect_node := fglsvgcanvas.rect(1, (row - 1) * 20 + 1, 28, 18, 2, 2))
    CALL init_keyboard_rect_node(rect_node, "ENTER")
    
    CALL root_keyboard_svg.appendChild(text_node := fglsvgcanvas.text(15, 50, "ENTER", "black"))
    CALL init_keyboard_text_node(text_node, "ENTER")

    CALL root_keyboard_svg.appendChild(rect_node := fglsvgcanvas.rect(171, (row - 1) * 20 + 1, 28, 18, 2, 2))
    CALL init_keyboard_rect_node(rect_node, "BACK")    
    CALL root_keyboard_svg.appendChild(text_node := fglsvgcanvas.text(185, 50, "BACK", "black"))
    CALL init_keyboard_text_node(text_node, "BACK")
    
    CALL fglsvgcanvas.display(keyboard_canvas_id)

END FUNCTION



PRIVATE FUNCTION init_keyboard_rect_node(r om.DomNode, id STRING)
    CALL r.setAttribute(SVGATT_CLASS, 'init')
    CALL r.setAttribute("id", id)
    CALL r.setAttribute(SVGATT_ONCLICK, SVGVAL_ELEM_CLICKED)
END FUNCTION

PRIVATE FUNCTION init_keyboard_text_node(t om.DomNode, id STRING)
    CALL t.setAttribute("id", SFMT("txt_%1",id))
    CALL t.setAttribute("alignment-baseline","central")
    CALL t.setAttribute("text-anchor","middle")
    CALL t.setAttribute("font-size","7px")
    CALL t.setAttribute("pointer-events","none")
    CALL t.setAttribute(SVGATT_CLASS, 'black')
END FUNCTION


FUNCTION get_letter(row INTEGER, col INTEGER) RETURNS CHAR(1)
#TODO figure out syntax to initialise multidimensional array
    DEFINE row1 ARRAY[10] OF CHAR(1) = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    DEFINE row2 ARRAY[9] OF CHAR(1) = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    DEFINE row3 ARRAY[7] OF CHAR(1) = ["Z", "X", "C", "V", "B", "N", "M"]

    CASE row
        WHEN 1
            RETURN row1[col]
        WHEN 2
            RETURN row2[col]
        WHEN 3
            RETURN row3[col]
    END CASE
    RETURN ""
END FUNCTION
