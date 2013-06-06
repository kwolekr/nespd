nespd 0.5

=============

This is an overhead shooter game for the Nintendo Entertainment System with the theme of Rareware's hit Nintendo 64 game, Perfect Dark.
Currently, it is in an early pre-alpha stage and not very fun.
Also included is a small, simple GTK level editor to produce maps that can be played.  Map files can be loaded, modified, and saved in a raw format.  The tiles used in the palette are 8x8 sized arranged in a grid in a Windows BMP format named tiles.bmp.

-------------

To create the game, assemble with nesasm with the following command:
	nesasm nespd.asm

To create the level editor, compile with the following (depends on GTK+ 2.0):
	gcc leveleditor.c `pkg-config --cflags --libs gtk+-2.0` -o leveleditor

Enjoy!