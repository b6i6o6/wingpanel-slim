// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2013 Wingpanel Developers
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

public class Wingpanel.Widgets.IndicatorMenubar : MenuBar {
    private Gee.List<IndicatorWidget> sorted_items;
    private Services.IndicatorSorter sorter = new Services.IndicatorSorter ();

    public IndicatorMenubar () {
        sorted_items = new Gee.ArrayList<IndicatorWidget> ();
    }

    public void insert_sorted (IndicatorWidget item) {
        if (item in sorted_items)
            return; // item already added

        sorted_items.add (item);
        sorted_items.sort (sorter.compare_func);
        apply_new_order ();
    }

    public override void remove (Gtk.Widget widget) {
        var indicator_widget = widget as IndicatorWidget;
        if (indicator_widget != null)
            sorted_items.remove (indicator_widget);

        base.remove (widget);
    }

    private void apply_new_order () {
        clear ();
        append_all_items ();
    }

    private void clear () {
        var children = get_children ();

        foreach (var child in children)
            base.remove (child);
    }

    private void append_all_items () {
        foreach (var widget in sorted_items)
            append (widget);
    }
}
