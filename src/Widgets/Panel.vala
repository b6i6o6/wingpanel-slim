// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2014 Wingpanel Developers
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

namespace Wingpanel.Widgets {

    public class Panel : BasePanel {
        private IndicatorLoader indicator_loader;
        private IndicatorMenubar right_menubar;
        private MenuBar left_menubar;
        private MenuBar center_menubar;
        private Gtk.Box container;

        public Panel (Gtk.Application app, Services.Settings settings, IndicatorLoader indicator_loader) {
            base (settings);

            this.indicator_loader = indicator_loader;
            set_application (app);

            container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            container.set_homogeneous (false);

            add (container);

            var style_context = get_style_context ();
            style_context.add_class (StyleClass.PANEL);
            style_context.add_class (Gtk.STYLE_CLASS_MENUBAR);

            // Add default widgets
            add_defaults (settings);

            load_indicators ();
        }

        protected override Gtk.StyleContext get_draw_style_context () {
            return get_style_context ();
        }

        private void load_indicators () {
            var indicators = indicator_loader.get_indicators ();

            foreach (var indicator in indicators)
                load_indicator (indicator);
        }

        private void load_indicator (IndicatorIface indicator) {
            var entries = indicator.get_entries ();

            foreach (var entry in entries)
                create_entry (entry);

            indicator.entry_added.connect (create_entry);
            indicator.entry_removed.connect (delete_entry);
        }

        private void create_entry (IndicatorWidget entry) {
            string entry_name = entry.get_indicator ().get_name ();

            if (entry_name == "libdatetime.so" || entry_name == "com.canonical.indicator.datetime")
                center_menubar.prepend (entry);
            else
                right_menubar.insert_sorted (entry);
        }

        private void delete_entry (IndicatorWidget entry) {
            var parent = entry.parent;
            
            if (parent != null)
                parent.remove (entry);
            else
                critical ("Indicator entry '%s' has no parent. Not removing from panel.", entry.get_entry_name ());
        }

        private void add_defaults (Services.Settings settings) {
            left_menubar = new MenuBar ();
            center_menubar = new MenuBar ();
            right_menubar = new IndicatorMenubar ();

            right_menubar.halign = Gtk.Align.END;

            left_menubar.append (new Widgets.AppsButton (settings));

            container.pack_start (left_menubar);
            container.pack_end (right_menubar);
            container.set_center_widget (center_menubar);
        }
    }
}
