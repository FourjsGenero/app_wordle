IMPORT util

FUNCTION todays_wordle() ATTRIBUTES (WSGet, WSPath="/today") RETURNS CHAR(5)
    DEFINE todays_word CHAR(5)
    DEFINE todays_word_idx INTEGER

    -- I think this is how wordle chooses its word
    -- It has a 2309 element list of words and it just selects the next one each day
    -- It is not actually random ...
    LET todays_word_idx = ((TODAY - MDY(6, 19, 2021)) MOD 2309) + 1
    SELECT word INTO todays_word FROM word_list WHERE idx = todays_word_idx

    RETURN todays_word
END FUNCTION

FUNCTION random_random() ATTRIBUTES (WSGet, WSPath="/random") RETURNS CHAR(5)
    DEFINE todays_word CHAR(5)
    DEFINE todays_word_idx INTEGER

    -- I think this is how wordle chooses its word
    -- It has a 2309 element list of words and it just selects the next one each day
    -- It is not actually random ...
    LET todays_word_idx = util.Math.rand(2309)+1
    SELECT word INTO todays_word FROM word_list WHERE idx = todays_word_idx

    RETURN todays_word
END FUNCTION