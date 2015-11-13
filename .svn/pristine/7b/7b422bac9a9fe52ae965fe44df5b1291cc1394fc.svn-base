;--------------------------------------------------------------------
;
;    PURPOSE  Given a uservalue from a menu button created
;             by MenuCreate, the function returns  the index
;             of the choice within the category.  Set the
;             selected menu button  to insensitive to signify
;             selection, and set all other choices for the
;             category to sensitive.

function shielding_guiMenuChoice, $
    Eventval, $   ; IN: uservalue from seleted menu button
    MenuItems, $  ; IN: menu item array, as returned by MenuCreate
    MenuButtons   ; IN: button array as returned by MenuCreate

    ;  Get the name less the last qualifier.
    ;
    i = strpos(eventval, '|', 0)
    while (i ge 0) do begin
        j = i
        i = strpos(eventval, '|', i+1)
    endwhile

    base = strmid(eventval, 0, j+1) ;common buttons, includes last |

    ;  Get the button sharing this basename.
    ;
    buttons = where(strpos(MenuItems, base) eq 0)

    ;  Get the index of selected item.
    ;
    this = (where(eventval eq MenuItems))[0]

    ;  For each button in category, sensitize.
    ;
    for i=0, n_elements(buttons)-1 do begin
        index = buttons[i]
        widget_control, MenuButtons[buttons[i]], SENSITIVE=index ne this
    endfor

    ;  Return the Selected button's index.
    ;
    return, this - buttons[0]

end

;--------------------------------------------------------------------
;
;    PURPOSE  Create a menu from a string descriptor (MenuItems).
;             Return the parsed menu items in MenuItems (overwritten),
;             and the array of corresponding menu buttons in MenuButtons.
;
;  MenuItems = (input/output), on input the menu structure in the form of
;          a string array.  Each string is an element, encoded as follows:
;  Character 1 = integer bit flag.  Bit 0 = 1 to denote a button with
;       children.  Bit 1 = 2 to denote this is the last child of its
;       parent.  Bit 2 = 4 to show that this button should initially
;       be insensitive, to denote selection.  Any combination of bits
;       may be set.
;       On RETURN, MenuItems contains the fully qualified button names.
; Characters 2-end = Menu button text.  Text should NOT contain the character
;       |, which is used to delimit menu names.
; MenuButtons = (output) button widget id's of the created menu.
; Bar_base = (input) ID of menu base.
; Prefix = prefix for this menu's button names.  If omitted, no
;   prefix.
;
;
; Example:
;  MenuItems = ['1File', '0Save', '2Exit', $
;       '1Edit', '3Cut', $
;       '3Help']
;  Creates a menu with three top level buttons (file, edit and help).
;  File has 2 choices (save and exit), Edit has one choice, and help has none.
;  On RETURN, MenuItems contains the fully qualified menu button names
;  in a string array of the form: ['<Prefix>|File', '<Prefix>|File|Save',
;   '<Prefix>|File|Exit', '<Prefix>|Edit',..., etc. ]
;
pro shielding_guiMenuCreate, $
    MenuItems, $    ; IN/OUT: menu structure/button names
    MenuButtons, $  ; OUT: button widget identifier
    Bar_base,  $    ; IN: menu bar base identifier
    Prefix=prefix   ; IN: (opt) prefix of the menu's button names

    ;  Initialize working variables and arrays.
    ;
    level = 0
    parent = [bar_base, 0, 0, 0, 0, 0]
    names = STRARR(5)
    lflags = INTARR(5)
    MenuButtons = lonarr(n_elements(MenuItems))

    if (n_elements(prefix)) then begin
        names[0] = prefix + '|'
    endif else begin
        names[0] = '|'
    endelse

    for i = 0, n_elements(MenuItems)-1 do begin
        flag = FIX(STRMID(MenuItems[i], 0, 1))
    txt = STRMID(MenuItems[i], 1, 100)
    uv = ''

    for j = 0, level do uv = uv + names[j]

        ;  Set the fully qualified name in the menuItems array.
        ;
        MenuItems[i] = uv + txt

        ;  Create the menu bar buttons.
        ;
        MenuButtons[i] = widget_button(parent[level], $

            VALUE=txt, UVALUE=uv+txt, $
            MENU=flag and 1, HELP=txt eq 'About')

        if ((flag and 4) ne 0) then begin
            widget_control, MenuButtons[i], SENSITIVE=0
        endif

        if (flag and 1) then begin
            level = level + 1
            parent[level] = MenuButtons[i]
            names[level] = txt + '|'
            lflags[level] = (flag AND 2) ne 0
        endif else if ((flag and 2) NE 0) then begin

            ;  Pop the previous levels.
            ;
            while (lflags[level]) do level = level-1

            ;  Pop this level.
            ;
            level = level - 1
        endif
    endfor

end         ;  of shielding_guiMenuCreate