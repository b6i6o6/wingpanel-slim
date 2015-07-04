// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011-2012 Wingpanel Developers
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

public class Wingpanel.Widgets.IndicatorButton : Gtk.MenuItem {
    public enum WidgetSlot {
        LABEL,
        IMAGE
    }

    private Gtk.Widget the_label;
    private Gtk.Widget the_image;
    private Gtk.Box box;

    public IndicatorButton () {
        box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        box.set_homogeneous (false);
        box.spacing = 2;

        add (box);
        box.show ();

        get_style_context ().add_class (StyleClass.COMPOSITED_INDICATOR);

        // Enable scrolling events
        add_events (Gdk.EventMask.SCROLL_MASK);
    }

    public void set_widget (WidgetSlot slot, Gtk.Widget widget) {
        Gtk.Widget old_widget;

        if (slot == WidgetSlot.LABEL)
            old_widget = the_label;
        else if (slot == WidgetSlot.IMAGE)
            old_widget = the_image;
        else
            assert_not_reached ();

        if (old_widget != null) {
            box.remove (old_widget);
            old_widget.get_style_context ().remove_class (StyleClass.COMPOSITED_INDICATOR);
        }

        widget.get_style_context ().add_class (StyleClass.COMPOSITED_INDICATOR);

        if (slot == WidgetSlot.LABEL) {
            the_label = widget;
            box.pack_end (the_label, false, false, 0);
        } else if (slot == WidgetSlot.IMAGE) {
            the_image = widget;
            box.pack_start (the_image, false, false, 0);
        } else {
            assert_not_reached ();
        }
    }
}
