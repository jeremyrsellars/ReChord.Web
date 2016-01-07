ReChord
=======

A lead sheet transposer/formatter in ClojureScript.

Web implementation - [squared.azurewebsites.net](http://squared.azurewebsites.net) in ClojureScript, coffee-script, express.

Transposes lead sheets in the form of text like this


    Birthday Song
    
    G            C        D
    This is your birthday song
    G        C    D      G
    It isn't very long,  Hay!!

For example, the above song is in the key of G, when fed into ReChord is translated to an html form, with chords transposed to the Key of E below:

    Birthday Song (Capo + 3)
    
    
    E            A        B
    This is your birthday song
    E        A    B      E
    It isn't very long,  Hay!!