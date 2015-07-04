// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Wingpanel Developers
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

namespace Wingpanel.Backend {

    public class IndicatorObjectEntry: Widgets.IndicatorButton, IndicatorWidget {
        private unowned Indicator.ObjectEntry entry;
        private unowned Indicator.Object parent_object;
        private IndicatorIface indicator;
        private string entry_name_hint;

        const int MAX_ICON_SIZE = 24;

        // used for drawing
        private Gtk.Widget menu;
        private Granite.Drawing.BufferSurface buffer;
        private int w = -1;
        private int h = -1;
        private int icon_origin_x = -1;
        private int menu_origin_x = -1;
        private const int arrow_height = 10;
        private const int arrow_width = 20;
        private const double x = 10.5;
        private const double y = 10.5;
        private const int radius = 5;

        private const string MENU_STYLESHEET = """
            .menu {
                background-color:@transparent;
                border-color:@transparent;
                background-image:none;
                border-width:0;
             }
             .popover {
                background-color: @bg_color;
                border: 1px solid rgba(0,0,0,0.4);
             }
         """;

        public IndicatorObjectEntry (Indicator.ObjectEntry entry, Indicator.Object obj, IndicatorIface indicator) {
            this.entry = entry;
            this.indicator = indicator;
            parent_object = obj;

            unowned string name_hint = entry.name_hint;
            if (name_hint == null)
                warning ("NULL name hint");

            entry_name_hint = name_hint != null ? name_hint.dup () : "";

            var image = entry.image as Gtk.Image;
            if (image != null) {
                // images holding pixbufs are quite frequently way too large, so we whenever a pixbuf
                // is assigned to an image we need to check whether this pixbuf is within reasonable size
                if (image.storage_type == Gtk.ImageType.PIXBUF) {
                    image.notify["pixbuf"].connect (() => {
                        ensure_max_size (image);
                    });

                    ensure_max_size (image);
                }

                image.pixel_size = MAX_ICON_SIZE;

                set_widget (WidgetSlot.IMAGE, image);
            }

            var label = entry.label;
            if (label != null && label is Gtk.Label)
                set_widget (WidgetSlot.LABEL, label);

            show ();

            if (entry.menu == null) {
                string indicator_name = indicator.get_name ();
                string entry_name = get_entry_name ();

                critical ("Indicator: %s (%s) has no menu widget.", indicator_name, entry_name);
                return;
            }

            // Workaround for buggy indicators: this menu may still be part of
            // another panel entry which hasn't been destroyed yet. Those indicators
            // trigger entry-removed after entry-added, which means that the previous
            // parent is still in the panel when the new one is added.
            if (entry.menu.get_attach_widget () != null)
                entry.menu.detach ();

            set_submenu (entry.menu);

            setup_drawing ();

            entry.menu.get_children ().foreach (setup_margin);
            entry.menu.insert.connect (setup_margin);
        }

        public IndicatorIface get_indicator () {
            return indicator;
        }

        public string get_entry_name () {
            return entry_name_hint;
        }

        private void setup_margin (Gtk.Widget widget) {
            #if HAS_GTK314_MIN
            widget.margin_start = 11;
            widget.margin_end = 10;
            #else
            widget.margin_start = 10;
            widget.margin_end = 9;
            #endif
        }

        private void setup_drawing () {
            setup_entry_menu_parent ();

            buffer = new Granite.Drawing.BufferSurface (100, 100);

            #if HAS_GTK314_MIN
            entry.menu.margin_top = 18;
            entry.menu.margin_bottom = 8;
            #else
            entry.menu.margin_top = 28;
            entry.menu.margin_bottom = 18;
            #endif

            Granite.Widgets.Utils.set_theming (entry.menu, MENU_STYLESHEET, null,
                                               Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            menu = new Gtk.Popover (this);

            Granite.Widgets.Utils.set_theming (menu, MENU_STYLESHEET, null,
                                               Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        private void setup_entry_menu_parent () {
            var menu_parent = entry.menu.get_parent ();
            menu_parent.app_paintable = true;
            menu_parent.set_visual (Gdk.Screen.get_default ().get_rgba_visual ());

            menu_parent.draw.connect (entry_menu_parent_draw_callback);
        }

        private bool entry_menu_parent_draw_callback (Cairo.Context ctx) {
            Gtk.Allocation alloc;
            entry.menu.get_parent ().get_allocation (out alloc);

            // Get x coordinate where indicator icon starts in panel
            int icon_x;
            this.get_window ().get_origin (out icon_x, null);

            // Get x coordinate where menu starts relative to screen area
            int menu_x;
            entry.menu.get_window ().get_origin (out menu_x, null);

            if (alloc.width != w || alloc.height != h || icon_origin_x != icon_x || menu_origin_x != menu_x) {
                w = alloc.width;
                h = alloc.height;
                icon_origin_x = icon_x;
                menu_origin_x = menu_x;

                buffer = new Granite.Drawing.BufferSurface (w, h);
                cairo_popover (w, h);

                var cr = buffer.context;

                // shadow
                cr.set_source_rgba (0, 0, 0, 0.5);
                cr.fill_preserve ();
                buffer.exponential_blur (6);
                cr.clip ();

                // background
                menu.get_style_context ().render_background (cr, 0, 0, w, h);
                cr.reset_clip ();

                // border
                cairo_popover (w, h);
                cr.set_operator (Cairo.Operator.SOURCE);
                cr.set_line_width (1);
                Gdk.cairo_set_source_rgba (cr, menu.get_style_context ().get_border_color (Gtk.StateFlags.NORMAL));
                cr.stroke ();
            }

            // clear surface to transparent
            ctx.set_operator (Cairo.Operator.SOURCE);
            ctx.set_source_rgba (0, 0, 0, 0);
            ctx.paint ();

            // now paint our buffer on
            ctx.set_source_surface (buffer.surface, 0, 0);
            ctx.paint ();

            return false;
        }

        private void cairo_popover (int menu_width, int menu_height) {
            menu_width -= 20;
            menu_height -= 20;

            Gtk.Allocation panel_icon_alloc;
            get_allocation (out panel_icon_alloc);

            // Get some nice pos for the arrow
            int arrow_offset = icon_origin_x + panel_icon_alloc.x;
            arrow_offset += panel_icon_alloc.width / 4 - menu_origin_x;

            if (arrow_offset + 50 > menu_width + 20)
                arrow_offset = menu_width + 20 - 15 - arrow_width;

            if (arrow_offset < 17)
                arrow_offset = 17;

            buffer.context.arc (x + radius, y + arrow_height + radius, radius, Math.PI, Math.PI * 1.5);
            buffer.context.line_to (arrow_offset, y + arrow_height);
            buffer.context.rel_line_to (arrow_width / 2.0, -arrow_height);
            buffer.context.rel_line_to (arrow_width / 2.0, arrow_height);
            buffer.context.arc (x + menu_width - radius, y + arrow_height + radius, radius, Math.PI * 1.5, Math.PI * 2.0);

            buffer.context.arc (x + menu_width - radius, y + menu_height - radius, radius, 0, Math.PI * 0.5);
            buffer.context.arc (x + radius, y + menu_height - radius, radius, Math.PI * 0.5, Math.PI);

            buffer.context.close_path ();
        }

        public override bool scroll_event (Gdk.EventScroll event) {
            parent_object.entry_scrolled (entry, 1, (Indicator.ScrollDirection) event.direction);
            return false;
        }

        public override bool button_press_event (Gdk.EventButton event) {
            if (event.button == Gdk.BUTTON_MIDDLE) {
                parent_object.secondary_activate (entry, event.time);
                return true;
            }

            return base.button_press_event (event);
        }

        private void ensure_max_size (Gtk.Image image) {
            var pixbuf = image.pixbuf;

            if (pixbuf != null && pixbuf.get_height () > MAX_ICON_SIZE) {
                image.pixbuf = pixbuf.scale_simple ((int) ((double) MAX_ICON_SIZE / pixbuf.get_height () * pixbuf.get_width ()),
                        MAX_ICON_SIZE, Gdk.InterpType.HYPER);
            }
        }
    }
}
