FUNCTION do_settings()
DEFINE rec  REcORD
    hard_mode BOOLEAN,
    dark_theme BOOLEAN,
    high_contrast_mode BOOLEAN,
    random BOOLEAN,
    full_dictionary BOOLEAN
END RECORD

    OPEN WINDOW settings WITH FORM "wordle_settings" 

    INPUT BY NAME rec.* ATTRIBUTES(WITHOUT DEFAULTS=TRUE, ACCEPT=FALSE, CANCEL=FALSE)
        BEFORE INPUT
            #CALL DIALOG.setFieldActive("hard_mode", FALSE)
            #CALL DIALOG.setFieldActive("dark_theme", FALSE)
            #ALL DIALOG.setFieldActive("high_contrast_mode", FALSE)

        ON ACTION feedback
            CALL ui.Interface.frontCall("standard","launchUrl","mailto:ask-reuben@4js.com",[])

        ON ACTION community
             CALL ui.Interface.frontCall("standard","launchUrl","https://forum.4js.com/fjs_forum/",[])

        ON ACTION questions
             CALL ui.Interface.frontCall("standard","launchUrl","https://github.com/FourjsGenero/app_wordle/issues",[])
        ON ACTION close
            EXIT INPUT
        
    END INPUT
    CLOSE WINDOW settings
END FUNCTION