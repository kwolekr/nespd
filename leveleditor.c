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

/*
 * leveleditor.c -
 *    Simple GTK+ level editor for NesPD
 */

#include "leveleditor.h"

GTKMENU file_menu[] = {
	{"New",     MenuHandleNew,    NULL},
	{"Open",    MenuHandleOpen,   NULL},
	{"Save",    MenuHandleSave,   NULL},
	{"Save as", MenuHandleSaveAs, NULL},
	{"Exit",    MenuHandleExit,   NULL},
	{NULL, NULL}
};

GTKMENU help_menu[] = {
	{"Help",  MenuHandleHelp,  NULL},
	{"About", MenuHandleAbout, NULL},
	{NULL, NULL}
};

GTKMENU main_menu[] = {
	{"File", NULL, file_menu},
	{"Edit", NULL, NULL},
	{"View", NULL, NULL},
	{"Help", NULL, help_menu},
	{NULL, NULL}
};

GtkWidget *window, *drawarea, *paldarea;
GdkPixbuf *srcpixbuf;
GdkPixbuf *frame, *oldframe, *palframe;
int bg_cx, bg_cy;

GdkPixbuf **tiles;
int ntiles_x, ntiles_y, ntiles;
int curtile[3];

int palarea_cx, palarea_cy;
int window_cx, window_cy;
int linemode;
int dragging;
int state;
int modified;
int start_x, start_y;

unsigned char map[30][32];
char currentfile[256];


///////////////////////////////////////////////////////////////////////////////


int main(int argc, char *argv[]) {
	GtkWidget *menubar, *box;
	GtkWidget *hbox;
	GError *error;

	error = NULL;
	gtk_init(&argc, &argv);

	LoadTiles();

	curtile[0] = 0x05;
	curtile[1] = 0x06;
	curtile[2] = 0x07;

	palarea_cx =  (4 * TILE_CX)  + 2 * 5 + 2 * 2;
	window_cx  = (32 * TILE_CX)  + palarea_cx;
	window_cy  = (30 * TILE_CY);
	palarea_cy = window_cy;

	window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
	gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
	gtk_window_set_default_size(GTK_WINDOW(window), window_cx, window_cy);
	gtk_window_set_title(GTK_WINDOW(window), "Level editor");
	gtk_window_set_icon_name(GTK_WINDOW(window), "gtk-save");

	box = gtk_vbox_new(FALSE, 0);
	gtk_container_add(GTK_CONTAINER(window), box);
	hbox = gtk_hbox_new(FALSE, 0);
	drawarea = gtk_drawing_area_new();
	paldarea = gtk_drawing_area_new();
	menubar  = gtk_menu_bar_new();
	gtk_box_pack_start(GTK_BOX(box), menubar, FALSE, TRUE, 0);
	gtk_box_pack_start(GTK_BOX(box), hbox, TRUE, TRUE, 0);

	gtk_box_pack_start(GTK_BOX(hbox), paldarea, FALSE, FALSE, 0);
	gtk_widget_set_size_request(paldarea, palarea_cx, palarea_cy);
	gtk_box_pack_start(GTK_BOX(hbox), drawarea, TRUE, TRUE, 0);
	CreateGtkMenus(menubar, main_menu);

	g_signal_connect(window, "delete-event", G_CALLBACK(ApplicationQuit), NULL);
	g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

	g_signal_connect(drawarea, "expose-event", G_CALLBACK(DrawArea_Expose), NULL);
	g_signal_connect(drawarea, "size-allocate", G_CALLBACK(DrawArea_SizeAlloc), NULL);
	g_signal_connect(drawarea, "key-press-event", G_CALLBACK(DrawArea_KeyPress), NULL);
	g_signal_connect(drawarea, "scroll-event", G_CALLBACK(DrawArea_Scroll), NULL);
	g_signal_connect(drawarea, "button-press-event", G_CALLBACK(DrawArea_ButtonPress), NULL);
	g_signal_connect(drawarea, "button-release-event", G_CALLBACK(DrawArea_ButtonRelease), NULL);
	g_signal_connect(drawarea, "motion-notify-event", G_CALLBACK(DrawArea_MotionNotify), NULL);

	g_signal_connect(paldarea, "expose-event", G_CALLBACK(PalDArea_Expose), NULL);
	g_signal_connect(paldarea, "size-allocate", G_CALLBACK(PalDArea_SizeAlloc), NULL);
	g_signal_connect(paldarea, "button-press-event", G_CALLBACK(PalDArea_ButtonPress), NULL);
	g_signal_connect(paldarea, "button-release-event", G_CALLBACK(PalDArea_ButtonRelease), NULL);

	frame    = gdk_pixbuf_new(GDK_COLORSPACE_RGB, FALSE, 8, 32 * TILE_CX, 30 * TILE_CY);
	palframe = gdk_pixbuf_new(GDK_COLORSPACE_RGB, FALSE, 8, palarea_cx, palarea_cy);
	gdk_pixbuf_fill(frame, 0);
	gdk_pixbuf_fill(palframe, 0x20202000);

	gtk_widget_show_all(window);
	gtk_widget_set_can_focus(drawarea, TRUE);
	gtk_widget_set_can_focus(paldarea, TRUE);
	gtk_widget_add_events(drawarea, GDK_ALL_EVENTS_MASK);
	gtk_widget_add_events(paldarea, GDK_ALL_EVENTS_MASK);
	PalDrawAreaInit(paldarea);
	gtk_main();

	return 0;
}


int CheckSaveModified() {
	GtkWidget *dialog;

	if (modified) {
		dialog = gtk_message_dialog_new(GTK_WINDOW(window), GTK_DIALOG_MODAL, GTK_MESSAGE_QUESTION,
			GTK_BUTTONS_YES_NO, "Would you like to save?");
		switch (gtk_dialog_run(GTK_DIALOG(dialog))) {
			case GTK_RESPONSE_YES:
				MenuHandleSave(NULL, 0);
			case GTK_RESPONSE_NO:
				gtk_widget_destroy(dialog);
				return 1;
		}
		gtk_widget_destroy(dialog);
		return 0;
	}
	return 1;
}


void ReloadFrame() {
	int x, y;

	for (y = 0; y != 30; y++) {
		for (x = 0; x != 32; x++) {
			gdk_pixbuf_copy_area(tiles[map[y][x]], 0, 0,
				TILE_CX, TILE_CY, frame, x * TILE_CX, y * TILE_CY);
		}
	}
	gtk_widget_queue_draw(drawarea);
}


void NewTileFile() {
	*currentfile = 0;
	memset(map, 0, sizeof(map));
	ReloadFrame();
	modified = 0;
}


void LoadTileFile(const char *filename) {
	FILE *file;

	printf("Opening %s\n", filename);

	file = fopen(filename, "rb");
	if (!file) {
		printf("Failed to open %s for reading, errno: %d\n", filename, errno);
		return;
	}

	fread(map, 32, 30, file);
	fclose(file);

	ReloadFrame();
	strncpy(currentfile, filename, sizeof(currentfile));
	currentfile[sizeof(currentfile) - 1] = 0;
	modified = 0;
}


void SaveTileFile(const char *filename) {
	FILE *file;

	printf("Saving %s\n", filename);

	file = fopen(filename, "wb");
	if (!file) {
		printf("Failed to open %s for writing, errno: %d\n", filename, errno);
		return;
	}

	fwrite(map, 32, 30, file);
	fclose(file);
	modified = 0;
}


void LoadTiles() {
	GdkPixbuf *subpixbuf;
	GError *error;
	int i, j, k, width, height;

	error = NULL;
	srcpixbuf = gdk_pixbuf_new_from_file("tiles.bmp", &error);
	if (!srcpixbuf) {
		printf("couldn't load image\n");
		exit(1);
	}

	bg_cx = width  = gdk_pixbuf_get_width(srcpixbuf);
	bg_cy = height = gdk_pixbuf_get_height(srcpixbuf);

	ntiles_x = width / TILE_WIDTH;
	ntiles_y = height / TILE_HEIGHT;

	tiles = malloc(ntiles_x * ntiles_y * sizeof(GdkPixbuf *));

	k = 0;
	for (i = 0; i != ntiles_y; i++) {
		for (j = 0; j != ntiles_x; j++) {
			subpixbuf = gdk_pixbuf_new_subpixbuf(srcpixbuf, j * TILE_WIDTH, i * TILE_HEIGHT, TILE_WIDTH, TILE_HEIGHT);
			subpixbuf = gdk_pixbuf_scale_simple(subpixbuf, TILE_CX, TILE_CY, GDK_INTERP_TILES);
			tiles[k] = subpixbuf;
			k++;
		}
	}
	printf("loaded %d tiles.\n", k);
	ntiles = k;
}


void PlaceTile(GtkWidget *widget, unsigned int x, unsigned int y, unsigned int button) {
	int tileno;
	GdkRectangle rect;

	if (x >= 32 || y >= 30)
		return;


	tileno = curtile[button];

	printf("tile #%d placed at x: %d, y: %d\n", tileno, x, y);
	map[y][x] = tileno;
	gdk_pixbuf_copy_area(tiles[tileno], 0, 0, TILE_CX, TILE_CY, frame, x * TILE_CX, y * TILE_CY);


	rect.width  = TILE_CX;
	rect.height = TILE_CY;
	rect.x      = x * TILE_CX;
	rect.y      = y * TILE_CY;

	gdk_window_invalidate_rect(widget->window, &rect, FALSE);

	modified = 1;
}

///////////////////////////////////////////////////////////////////////////////


void PalDrawAreaInit(GtkWidget *widget) {
	int i, x, y;
	GdkPixbuf *pixbuf;

	for (i = 0; i != ARRAYLEN(curtile); i++) {
		pixbuf = gdk_pixbuf_scale_simple(tiles[curtile[i]], TILE_WIDTH * 4, TILE_HEIGHT * 4, GDK_INTERP_TILES);
		gdk_pixbuf_copy_area(pixbuf, 0, 0, TILE_WIDTH * 4, TILE_HEIGHT * 4,
			palframe, (TILE_WIDTH * 4 * i) + (i + 1) * 4, 16);
		g_object_unref(pixbuf);
	}

	for (i = 0; i != ntiles; i++) {
		x = i & 3;
		y = i >> 2;
		gdk_pixbuf_copy_area(tiles[i], 0, 0, TILE_CX, TILE_CY,
			palframe, x * TILE_CX + (x << 1) + 3, y * TILE_CY + (y << 1) + 80);
	}
}


void PalDArea_SizeAlloc(GtkWidget *widget, GdkRectangle *allocation, gpointer user_data) {
	printf("paldarea new cx: %d, new cy: %d\n", allocation->width, allocation->height);
}



static gint PalDArea_Expose(GtkWidget *widget, GdkEventExpose *event, gpointer data) {
	cairo_t *cr;

	cr = gdk_cairo_create(event->window);

	gdk_cairo_set_source_pixbuf(cr, palframe, 0, 0);
	gdk_cairo_rectangle(cr, &event->area);

	cairo_fill(cr);

	cairo_set_line_width(cr, 1);
	cairo_set_source_rgba(cr, 1, 0, 0, 1);
	cairo_move_to(cr, palarea_cx - 1, 0);
	cairo_line_to(cr, palarea_cx - 1, palarea_cy);
	cairo_stroke(cr);

	cairo_destroy(cr);
	return TRUE;
}


gboolean PalDArea_ButtonPress(GtkWidget *widget, GdkEventButton *event, gpointer data) {
	int tileno;
	int x, y, x_to_draw;
	unsigned int button;
	GdkPixbuf *pixbuf;
	GdkRectangle rect;

	button = event->button - 1;
	if (button > ARRAYLEN(curtile) - 1)
		return FALSE;

	x = ((int)event->x - 3) / (TILE_CX + 2);
	y = ((int)event->y - 80) / (TILE_CY + 2);
	tileno = (y << 2) + x;

	if (tileno < 0 || tileno >= ntiles)
		return FALSE;

	curtile[button] = tileno;

	x_to_draw = (TILE_WIDTH * 4 * button) + (button + 1) * 4;

	pixbuf = gdk_pixbuf_scale_simple(tiles[tileno], TILE_WIDTH * 4, TILE_HEIGHT * 4, GDK_INTERP_TILES);
	gdk_pixbuf_copy_area(pixbuf, 0, 0, TILE_WIDTH * 4, TILE_HEIGHT * 4,
		palframe, x_to_draw, 16);
	g_object_unref(pixbuf);

	rect.width  = TILE_WIDTH * 4;
	rect.height = TILE_HEIGHT * 4;
	rect.x      = x_to_draw;
	rect.y      = 16;

	gdk_window_invalidate_rect(widget->window, &rect, FALSE);

	printf("Selected tile #%d for button %d\n", tileno, button);

	return TRUE;
}


gboolean PalDArea_ButtonRelease(GtkWidget *widget, GdkEventButton *event, gpointer data) {
	return FALSE;
}


///////////////////////////////////////////////////////////////////////////////


void DrawArea_SizeAlloc(GtkWidget *widget, GdkRectangle *allocation, gpointer user_data) {
	printf("new cx: %d, new cy: %d\n", allocation->width, allocation->height);

	//frame = gdk_pixbuf_scale_simple(frame, allocation->width, allocation->height, GDK_INTERP_TILES);
}


gboolean DrawArea_Expose(GtkWidget *widget, GdkEventExpose *event, gpointer data) {
	cairo_t *cr;

	cr = gdk_cairo_create(event->window);

	gdk_cairo_set_source_pixbuf(cr, frame, 0, 0);
	gdk_cairo_rectangle(cr, &event->area);
	cairo_fill(cr);

	cairo_destroy(cr);
	return TRUE;
}


gboolean DrawArea_Scroll(GtkWidget *widget, GdkEventScroll *event, gpointer user_data) {
	if (event->direction == GDK_SCROLL_UP) {
		printf("zoom in\n");
	} else if (event->direction == GDK_SCROLL_DOWN) {
		printf("zoom out\n");
	}
	return FALSE;
}


gboolean DrawArea_KeyPress(GtkWidget *widget, GdkEventKey *event, gpointer user_data) {
	printf("keypress: %d\n", event->keyval);
	return FALSE;
}


gboolean DrawArea_MotionNotify(GtkWidget *widget, GdkEventMotion *event, gpointer data) {
	int x, y, tileno, i, j, etile, etile_x, etile_y;
	int xdiff, ydiff;
	int vals[] = {10, 26, 9, 25};
	unsigned int button;
	GdkModifierType state;

	if (frame == NULL)
		return FALSE;

	gdk_window_get_pointer(event->window, &x, &y, &state);
	if (linemode) {
		if (state & GDK_BUTTON1_MASK) {
			x = x / TILE_CX;
			y = y / TILE_CY;

			g_object_unref(frame);
			frame = gdk_pixbuf_copy(oldframe);

			xdiff = abs(x - start_x);
			ydiff = abs(y - start_y);

			etile = (xdiff >= ydiff) ? start_y : y;
			i = x - start_x;
			j = (i < 0) ? 1 : -1;
			while (i) {
				i += j;
				gdk_pixbuf_copy_area(tiles[21], 0, 0, TILE_CX, TILE_CY,
					frame, (start_x + i) * TILE_CX, etile * TILE_CY);
			}

			etile = (xdiff >= ydiff) ? x : start_x;
			i = y - start_y;
			j = (i < 0) ? 1 : -1;
			while (i) {
				i += j;
				gdk_pixbuf_copy_area(tiles[18], 0, 0, TILE_CX, TILE_CY,
					frame, etile * TILE_CX, (start_y + i) * TILE_CY);
			}

			if ((x > start_x) && (y > start_y))
				j = 0;
			else if ((x > start_x) && (y < start_y))
				j = 1;
			else if ((x < start_x) && (y > start_y))
				j = 2;
			else if ((x < start_x) && (y < start_y))
				j = 3;
			if (xdiff >= ydiff) {
				tileno = vals[j];
				etile_x = x;
				etile_y = start_y;
			} else {
				tileno = vals[3 - j];
				etile_x = start_x;
				etile_y = y;
			}

			if ((x != start_x) && (y != start_y)) {
				gdk_pixbuf_copy_area(tiles[tileno], 0, 0, TILE_CX, TILE_CY,
					frame, etile_x * TILE_CX, etile_y * TILE_CY);
			}
			gtk_widget_queue_draw(widget);
		}
	} else {
		button = 0;
		if (state & GDK_BUTTON3_MASK)
			button = 3;
		if (state & GDK_BUTTON2_MASK)
			button = 2;
		if (state & GDK_BUTTON1_MASK)
			button = 1;

		if (button)
			PlaceTile(widget, x / TILE_CX, y / TILE_CY, button - 1);
	}

	return TRUE;
}


gboolean DrawArea_ButtonPress(GtkWidget *widget, GdkEventButton *event, gpointer data) {
	unsigned int button;

	if (linemode) {
		if (event->button == 1) {
			oldframe = gdk_pixbuf_copy(frame);
			start_x  = (int)event->x / TILE_CX;
			start_y  = (int)event->y / TILE_CY;
			dragging = 1;
			gtk_widget_queue_draw(widget);
		} else {
			return FALSE;
		}
	} else {
		button = event->button - 1;
		if (button > 2)
			return FALSE;

		PlaceTile(widget, (int)event->x / TILE_CX, (int)event->y / TILE_CY, button);
	}
	return TRUE;
}


gboolean DrawArea_ButtonRelease(GtkWidget *widget, GdkEventButton *event, gpointer data) {
	if (linemode) {
		if (event->button == 1) {
			g_object_unref(oldframe);
			oldframe = frame;
			dragging = 0;
			gtk_widget_queue_draw(widget);
			modified = 1;
			//gotta commit changes!
		}
	}

	return TRUE;
}


/////////////////////////////////////// Menu //////////////////////////////////


void CreateGtkMenus(GtkWidget *menubar, LPGTKMENU menudesc) {
	GtkWidget *mitem, *smitem, *submenu;
	LPGTKMENU smdesc;
	int i, j;

	for (i = 0; menudesc[i].text; i++) {
		mitem = gtk_menu_item_new_with_label(menudesc[i].text);
		if (menudesc[i].callback)
			g_signal_connect(mitem, "activate", G_CALLBACK(menudesc[i].callback), NULL);
		gtk_menu_shell_append(GTK_MENU_SHELL(menubar), mitem);
		smdesc = menudesc[i].submenu;
		if (smdesc) {
			submenu = gtk_menu_new();
			for (j = 0; smdesc[j].text; j++) {
				smitem = gtk_menu_item_new_with_label(smdesc[j].text);
				if (smdesc[j].callback)
					g_signal_connect(smitem, "activate", G_CALLBACK(smdesc[j].callback), NULL);
				gtk_menu_shell_append(GTK_MENU_SHELL(submenu), smitem);
				gtk_menu_item_set_submenu(GTK_MENU_ITEM(mitem), submenu);
			}
		}
	}
}


void MenuHandleNew(GtkMenuItem *menuitem, gpointer user_data) {
	if (CheckSaveModified())
		NewTileFile();
}


void MenuHandleOpen(GtkMenuItem *menuitem, gpointer user_data) {
	GtkWidget *dialog;
	char *filename;

	dialog = gtk_file_chooser_dialog_new("Open File", GTK_WINDOW(window),
		GTK_FILE_CHOOSER_ACTION_OPEN, GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
		GTK_STOCK_OPEN, GTK_RESPONSE_ACCEPT, NULL);

	if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
		filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
		LoadTileFile(filename);
		g_free(filename);
	}

	gtk_widget_destroy(dialog);
}


void MenuHandleSave(GtkMenuItem *menuitem, gpointer user_data) {
	if (!*currentfile) {
		strcpy(currentfile, "newfile.map");
		MenuHandleSaveAs(menuitem, user_data);
	} else {
		SaveTileFile(currentfile);
	}
}


void MenuHandleSaveAs(GtkMenuItem *menuitem, gpointer user_data) {
	GtkWidget *dialog;
	char *filename;

	dialog = gtk_file_chooser_dialog_new("Save File As", GTK_WINDOW(window),
		GTK_FILE_CHOOSER_ACTION_SAVE, GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
		GTK_STOCK_SAVE, GTK_RESPONSE_ACCEPT, NULL);

	gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(dialog), TRUE);
	gtk_file_chooser_set_filename(GTK_FILE_CHOOSER(dialog), currentfile);

	if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
		filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
		strncpy(currentfile, filename, sizeof(currentfile));
		currentfile[sizeof(currentfile) - 1] = 0;
		SaveTileFile(filename);
		g_free(filename);
	}

	gtk_widget_destroy(dialog);
}


void MenuHandleExit(GtkMenuItem *menuitem, gpointer user_data) {
	if (CheckSaveModified())
		exit(1);
}


void MenuHandleHelp(GtkMenuItem *menuitem, gpointer user_data) {
	GtkWidget *dialog;

	dialog = gtk_message_dialog_new(GTK_WINDOW(window), GTK_DIALOG_MODAL,
		GTK_MESSAGE_INFO, GTK_BUTTONS_OK, "No help for you lol");
	gtk_dialog_run(GTK_DIALOG(dialog));
	gtk_widget_destroy(dialog);
}


void MenuHandleAbout(GtkMenuItem *menuitem, gpointer user_data) {
	GtkWidget *dialog;

	dialog = gtk_message_dialog_new(GTK_WINDOW(window), GTK_DIALOG_MODAL,
		GTK_MESSAGE_INFO, GTK_BUTTONS_OK, "NES Map editor v1.0");
	gtk_dialog_run(GTK_DIALOG(dialog));
	gtk_widget_destroy(dialog);
}


gboolean ApplicationQuit(GtkWidget *widget, GdkEvent  *event, gpointer user_data) {
	return !CheckSaveModified();
}
