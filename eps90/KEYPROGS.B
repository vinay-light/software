EEL^ &reg-tab cx-tab buf-tab dired-tab bufed-tab blist-tab comp-tab menu-tab view-tab grep-tab when-loading o� 
   h "P! !"O!F  ��   NH�	viewed-text #X �H9A(  4�f&IZ #O"O_  F#O +  �7	����	  �	   #e?��"O`�"P<  *2�"P>  *2�"P�  *2&f�H"P*2�"P^  *2�"P�  *2�"PN  *2�"P�  *2�"P6  *2�"P>  *2dff�"P^  *2�fR�"P�  *2�f>AZ �"P   L*2F ���"P8  *2�fH	 �"P  �   L*2F ���f� +, f�  �!H�    L*2F �� #Pf	   ?  #PH9&P *0&
P *0&
P �"PL*1J� #&P wW "PL*1J� .&P w@ "PL*1�    9&P w"PL*1�  &P � "PL*1&P �"PL*1&P &
P Af	   ?�  ��H#y&
P w&2P a
?�Jy% &2P &P 	  &P */ &P 	  �"PL*2H&P *0"PL*1J� �&P wW "PL*1J� �&P w@ "PL*1�    �&P w"PL*1�  &P � "PL*1&P �"PL*1&P &
P �eH``�   �"P`L*2F `��   ``    `"P`L*2F `��a``z �"P`   L*2F `��0``9 �"P`   L*2F `���9"Pz  *2"PZ  *2�  ``�   `"P`L*2F `��  ``  = �`  */aa   "P`�   L*2a�  "P`L*2F `��H"P*2d(  0Hb"%(  /�  dd*  ! "% � dV"PdVL*2F d��!  cc*  bJ F b"% � �  c"P  bL*2"% � �  c"P  b+L*2�  db Hd K ��    ��   ��   ��
   "% � dcV"P  bVL*2  b�   d"PdL*1H "% d c�   "PdL*2c�   "Pc�   L*2c!   c*   �  c"Pc+L*2F bF c��"% �   "P"  *2dd� "% � d   "Pd   L*2"% � d   +"Pd   +L*2"% � d   V"Pd   VL*2"% � d   �   "Pd   �   L*2F dA��!e e*/. "% �
  e*/   "P e*/   L*2 e!e��"P�  *2
"P�  *2"%(  0�fS fK H K �Q   �X   �0   �1   H�2   ��3   ��4   ��5   ��A   ,�I   ��D   ���9 h n �s��en	display-column show-binding getkey getkey getkey get-string numtoi -prev-kbd-extended -prev-kbd-extended -prev-kbd-extended  select-keyboard �Under DOS, this program makes Epsilon compatible with those keyboard
enhancement programs that use some of the same undefined key combinations
that Epsilon uses.  The programs, and the keys in conflict, are:

1) Microsoft Windows, DOS Shell, OS/2 Dos Box: Alt-Tab, Ctrl-Esc, Alt-Esc
2) Superkey: Alt-/, Alt-\, Alt-', Alt-`, Alt-PrtScr, Alt-Esc
3) Prokey: Alt-/                  4) Ready: Ctrl-5, Shift-Ctrl-5
5) Spotlight: Alt-Shift-<letters>, Alt-Shift-Enter

By default these are bindable keys in Epsilon, but are unavailable to
the keyboard enhancement program.  Press 1, 2, 3, 4, or 5 to let the
corresponding program get the keys it uses.  These keys will then be
unavailable to Epsilon.

A) Enable entering graphics characters with Alt-<Numeric Keypad key>
   for DOS or OS/2 (by default, commands are on these keys).
I) Modify individual keys.  A translation of -2 means to ignore the key,
   and -1 means to use the untranslated value (under DOS, pass it to BIOS).
D) Remove all these changes, restoring Epsilon to its Default state.

Press Q when you're done.  All these changes will last until you exit
Epsilon, but you can use the write-state command to make them permanent.
 # Press 1-5, A, I, D, or Q to exit:   write-state 7 To remember these changes for future sessions, use %s.   < Compatible with Microsoft Windows, DOS Shell, OS/2 Dos Box.  Compatible with Superkey.  Compatible with Prokey.  Compatible with Ready.  Compatible with Spotlight. 2 You can now type key codes on the Numeric Keypad.  Wait...  Enter key to see:  	 <tobios> 	 <ignore>  bios- 4 Key %s, #%d is translated to %s, #%d - change? [n]  " New translation for %s, code %d?  	 <tobios> 	 <ignore>  bios- % Key %s, #%d is translated to %s, #%d 	 +-*	/ 	 ',./;[]`  All keys are now bindable.  Press Q to exit. 