/*-
 * Copyright (c) 2011 Ryan Kwolek 
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are
 * permitted provided that the following conditions are met:
 *  1. Redistributions of source code must retain the above copyright notice, this list of
 *     conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice, this list
 *     of conditions and the following disclaimer in the documentation and/or other materials
 *     provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef LEVELEDITOR_HEADER
#define LEVELEDITOR_HEADER

#ifdef _WIN32
	#define  _CRT_SECURE_NO_WARNINGS
	#define WIN32_LEAN_AND_MEAN
	#include <windows.h>
#else
	#include <string.h>
	#include <errno.h>
#endif

#include <stdio.h>
#include <stdlib.h>

#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

#define ARRAYLEN(x) (sizeof(x) / sizeof((x)[0]))

#define TILE_WIDTH  8
#define TILE_HEIGHT 8
#define TILE_SCALE  3
#define TILE_CX (TILE_WIDTH * TILE_SCALE)
#define TILE_CY (TILE_HEIGHT * TILE_SCALE)

typedef struct _gtkmenu {
	const char *text;
	void (*callback)(GtkMenuItem *menuitem, gpointer user_data);
	struct _gtkmenu *submenu;
} GTKMENU, *LPGTKMENU;

void LoadTiles();
void CreateGtkMenus(GtkWidget *menubar, LPGTKMENU menudesc);
void PalDrawAreaInit(GtkWidget *widget);

void PalDArea_SizeAlloc(GtkWidget *widget, GdkRectangle *allocation, gpointer user_data);
static gint PalDArea_Expose(GtkWidget *widget, GdkEventExpose *event, gpointer data);
gboolean PalDArea_ButtonPress(GtkWidget *widget, GdkEventButton *event, gpointer data);
gboolean PalDArea_ButtonRelease(GtkWidget *widget, GdkEventButton *event, gpointer data);

void DrawArea_SizeAlloc(GtkWidget *widget, GdkRectangle *allocation, gpointer user_data);
gboolean DrawArea_Expose(GtkWidget *widget, GdkEventExpose *event, gpointer data);
gboolean DrawArea_Scroll(GtkWidget *widget, GdkEventScroll *event, gpointer user_data);
gboolean DrawArea_KeyPress(GtkWidget *widget, GdkEventKey *event, gpointer user_data);
gboolean DrawArea_MotionNotify(GtkWidget *widget, GdkEventMotion *event, gpointer data);
gboolean DrawArea_ButtonPress(GtkWidget *widget, GdkEventButton *event, gpointer data);
gboolean DrawArea_ButtonRelease(GtkWidget *widget, GdkEventButton *event, gpointer data);


void MenuHandleNew(GtkMenuItem *menuitem, gpointer user_data);
void MenuHandleOpen(GtkMenuItem *menuitem, gpointer user_data);
void MenuHandleSave(GtkMenuItem *menuitem, gpointer user_data);
void MenuHandleSaveAs(GtkMenuItem *menuitem, gpointer user_data);
void MenuHandleExit(GtkMenuItem *menuitem, gpointer user_data);
void MenuHandleHelp(GtkMenuItem *menuitem, gpointer user_data);
void MenuHandleAbout(GtkMenuItem *menuitem, gpointer user_data);

gboolean ApplicationQuit(GtkWidget *widget, GdkEvent  *event, gpointer user_data);

#endif //LEVELEDITOR_HEADER

