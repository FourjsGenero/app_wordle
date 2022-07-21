FUNCTION do_statistics()

DEFINE next_wordle  INTERVAL HOUR TO SECOND

    OPEN WINDOW stats WITH FORM "wordle_statistics" ATTRIBUTES(STYLE="dialog")

        #TODO Calculate
    DISPLAY 0 TO played
    DISPLAY 100 TO winperc
    DISPLAY 1 TO streak
    DISPLAY 1 TO max
    
    LET next_wordle = "23:59:59" - (CURRENT HOUR TO SECOND) + "00:00:01"
    DISPLAY BY NAME next_wordle
    
    MENU ""
        ON ACTION gotofourjs
            CALL ui.Interface.frontCall("standard","launchUrl","https://4js.com/",[])
        ON ACTION share
            CALL FGL_WINMESSAGE("Info","Not Yet Implemented", "stop")
        ON ACTION close
            EXIT MENU
    END MENU
    CLOSE WINDOW stats
END FUNCTION